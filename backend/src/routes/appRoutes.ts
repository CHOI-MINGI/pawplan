import { Router } from "express";
import { Prisma } from "@prisma/client";
import fs from "node:fs";
import { promises as fsp } from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import multer from "multer";
import { AuthedRequest, requireAuth } from "../auth.js";
import {
  decorateCareSchedule,
  generateDefaultCareSchedules,
  generateDefaultCatCareSchedules,
} from "../domain/carePlan.js";
import {
  assignmentMeta,
  buildUserDirectory,
  canViewSensitiveRecord,
  collaborationMeta,
  normalizeSensitiveFlag,
  sensitiveRecordWhere,
  userSummarySelect,
  writeAuditEvent,
  type AccessRole,
  type UserDirectory,
} from "../domain/collaboration.js";
import {
  latestForecasts,
  latestCatForecasts,
  recalculateCostForecasts,
  recalculateCatCostForecasts,
} from "../domain/costForecast.js";
import { buildVisitReport, buildCatVisitReport, visitReportNotice } from "../domain/visitReport.js";
import {
  asyncHandler,
  HttpError,
  ok,
  optionalDate,
  optionalNumber,
  parseId,
  requireString,
} from "../http.js";
import { prisma } from "../prisma.js";

export const appRoutes = Router();

appRoutes.use(requireAuth);

const uploadRoot = path.resolve(
  process.env.UPLOAD_ROOT ?? path.join(process.cwd(), "uploads"),
);
const medicalVisitUploadDir = path.join(uploadRoot, "medical-visits");
const catMedicalVisitUploadDir = path.join(uploadRoot, "cat-medical-visits");
const attachmentFileTypes = new Set([
  "receipt",
  "prescription",
  "test_result",
  "image",
  "other",
]);

const attachmentUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, callback) => {
      fs.mkdirSync(medicalVisitUploadDir, { recursive: true });
      callback(null, medicalVisitUploadDir);
    },
    filename: (_req, file, callback) => {
      const extension = path.extname(file.originalname).slice(0, 20);
      callback(null, `${Date.now()}-${randomUUID()}${extension}`);
    },
  }),
  limits: { fileSize: 8 * 1024 * 1024 },
});

const catAttachmentUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, callback) => {
      fs.mkdirSync(catMedicalVisitUploadDir, { recursive: true });
      callback(null, catMedicalVisitUploadDir);
    },
    filename: (_req, file, callback) => {
      const extension = path.extname(file.originalname).slice(0, 20);
      callback(null, `${Date.now()}-${randomUUID()}${extension}`);
    },
  }),
  limits: { fileSize: 8 * 1024 * 1024 },
});

function userId(req: AuthedRequest) {
  return req.userId;
}

async function requireDogAccess(ownerId: bigint, dogId: bigint) {
  const dog = await prisma.dog.findFirst({
    where: {
      id: dogId,
      OR: [
        { primaryOwnerId: ownerId },
        { memberships: { some: { userId: ownerId, status: "active" } } },
      ],
    },
  });
  if (!dog) {
    throw new HttpError(404, "NOT_FOUND", "dog not found");
  }
  return dog;
}

async function requireDogOwnerAccess(ownerId: bigint, dogId: bigint) {
  const dog = await prisma.dog.findFirst({
    where: {
      id: dogId,
      OR: [
        { primaryOwnerId: ownerId },
        {
          memberships: {
            some: { userId: ownerId, role: "owner", status: "active" },
          },
        },
      ],
    },
  });
  if (!dog) {
    throw new HttpError(404, "NOT_FOUND", "dog not found");
  }
  return dog;
}

async function requireDogWriteAccess(userId: bigint, dogId: bigint) {
  const dog = await prisma.dog.findFirst({
    where: {
      id: dogId,
      OR: [
        { primaryOwnerId: userId },
        {
          memberships: {
            some: {
              userId,
              status: "active",
              role: { in: ["owner", "editor"] },
            },
          },
        },
      ],
    },
  });
  if (!dog) {
    throw new HttpError(404, "NOT_FOUND", "dog not found");
  }
  return dog;
}

async function dogAccessRole(userId: bigint, dog: { id: bigint; primaryOwnerId: bigint }) {
  if (dog.primaryOwnerId === userId) return "owner";
  const membership = await prisma.dogMembership.findFirst({
    where: { dogId: dog.id, userId, status: "active" },
    select: { role: true },
  });
  return (membership?.role as AccessRole | undefined) ?? null;
}

async function dogAccessContext(viewerId: bigint, dogId: bigint) {
  const dog = await requireDogAccess(viewerId, dogId);
  const role = await dogAccessRole(viewerId, dog);
  return { dog, role };
}

async function loadDogUserDirectory(dogId: bigint, extraUserIds: Array<bigint | null | undefined> = []) {
  const memberships = await prisma.dogMembership.findMany({
    where: { dogId, status: "active" },
    include: { user: { select: userSummarySelect } },
  });
  const directory = buildUserDirectory(memberships.map((membership) => membership.user));
  const missingUserIds = extraUserIds
    .filter((id): id is bigint => id !== null && id !== undefined)
    .filter((id) => !directory.has(id.toString()));
  if (missingUserIds.length > 0) {
    const users = await prisma.user.findMany({
      where: { id: { in: missingUserIds } },
      select: userSummarySelect,
    });
    for (const user of users) {
      directory.set(user.id.toString(), user);
    }
  }
  return directory;
}

async function parseAssignableUserId(
  value: unknown,
  dogId: bigint,
  label = "assignedToUserId",
) {
  if (value === undefined) return undefined;
  if (value === null || value === "") return null;
  const assignedTo = parseId(String(value), label);
  const hasAccess = await prisma.dog.findFirst({
    where: {
      id: dogId,
      OR: [
        { primaryOwnerId: assignedTo },
        { memberships: { some: { userId: assignedTo, status: "active" } } },
      ],
    },
    select: { id: true },
  });
  if (!hasAccess) {
    throw new HttpError(
      400,
      "VALIDATION_ERROR",
      "assigned user must be an active family member",
    );
  }
  return assignedTo;
}

function normalizeMembershipRole(value: unknown) {
  if (value === "owner" || value === "editor" || value === "viewer") {
    return value;
  }
  throw new HttpError(
    400,
    "VALIDATION_ERROR",
    "role must be owner, editor, or viewer",
  );
}

async function requireMembershipOwnerAccess(ownerId: bigint, membershipId: bigint) {
  const membership = await prisma.dogMembership.findUnique({
    where: { id: membershipId },
  });
  if (!membership) {
    throw new HttpError(404, "NOT_FOUND", "membership not found");
  }
  await requireDogOwnerAccess(ownerId, membership.dogId);
  return membership;
}

async function requireScheduleAccess(ownerId: bigint, scheduleId: bigint) {
  const schedule = await prisma.careSchedule.findUnique({
    where: { id: scheduleId },
  });
  if (!schedule) throw new HttpError(404, "NOT_FOUND", "schedule not found");
  await requireDogAccess(ownerId, schedule.dogId);
  return schedule;
}

async function requireScheduleWriteAccess(ownerId: bigint, scheduleId: bigint) {
  const schedule = await prisma.careSchedule.findUnique({
    where: { id: scheduleId },
  });
  if (!schedule) throw new HttpError(404, "NOT_FOUND", "schedule not found");
  await requireDogWriteAccess(ownerId, schedule.dogId);
  return schedule;
}

async function requireConditionAccess(ownerId: bigint, conditionId: bigint) {
  const condition = await prisma.dogCondition.findUnique({
    where: { id: conditionId },
  });
  if (!condition) throw new HttpError(404, "NOT_FOUND", "condition not found");
  await requireDogAccess(ownerId, condition.dogId);
  return condition;
}

async function requireConditionWriteAccess(ownerId: bigint, conditionId: bigint) {
  const condition = await prisma.dogCondition.findUnique({
    where: { id: conditionId },
  });
  if (!condition) throw new HttpError(404, "NOT_FOUND", "condition not found");
  await requireDogWriteAccess(ownerId, condition.dogId);
  return condition;
}

async function requireMedicationAccess(ownerId: bigint, medicationId: bigint) {
  const medication = await prisma.dogMedication.findUnique({
    where: { id: medicationId },
  });
  if (!medication)
    throw new HttpError(404, "NOT_FOUND", "medication not found");
  await requireDogAccess(ownerId, medication.dogId);
  return medication;
}

async function requireMedicationWriteAccess(ownerId: bigint, medicationId: bigint) {
  const medication = await prisma.dogMedication.findUnique({
    where: { id: medicationId },
  });
  if (!medication)
    throw new HttpError(404, "NOT_FOUND", "medication not found");
  await requireDogWriteAccess(ownerId, medication.dogId);
  return medication;
}

function patchOptionalDate(body: Record<string, unknown>, key: string) {
  if (!Object.prototype.hasOwnProperty.call(body, key)) return undefined;
  const value = body[key];
  if (value === null || value === "") return null;
  return optionalDate(value);
}

function addDays(base: Date, days: number) {
  return new Date(base.getTime() + days * 24 * 60 * 60 * 1000);
}

function normalizeAttachmentType(value: unknown) {
  if (typeof value !== "string" || !attachmentFileTypes.has(value)) {
    return "other";
  }
  return value;
}

function resolveUploadPath(fileUrl: string) {
  const absolute = path.resolve(uploadRoot, fileUrl);
  if (
    absolute !== uploadRoot &&
    !absolute.startsWith(`${uploadRoot}${path.sep}`)
  ) {
    throw new HttpError(400, "VALIDATION_ERROR", "invalid attachment path");
  }
  return absolute;
}

async function deleteAttachmentFile(fileUrl: string) {
  try {
    await fsp.unlink(resolveUploadPath(fileUrl));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
}

async function createNextRecurringSchedule(
  schedule: Awaited<ReturnType<typeof requireScheduleAccess>>,
  createdBy: bigint,
) {
  if (!schedule.repeatCycleDays) return null;
  return prisma.careSchedule.create({
    data: {
      dogId: schedule.dogId,
      scheduleType: schedule.scheduleType,
      title: schedule.title,
      description: schedule.description,
      dueDate: addDays(schedule.dueDate, schedule.repeatCycleDays),
      repeatCycleDays: schedule.repeatCycleDays,
      priority: schedule.priority,
      sourceType: schedule.sourceType,
      reminderEnabled: schedule.reminderEnabled,
      createdBy,
      assignedTo: schedule.assignedTo,
    },
  });
}

async function requireHealthLogAccess(ownerId: bigint, logId: bigint) {
  const log = await prisma.healthLog.findUnique({ where: { id: logId } });
  if (!log) throw new HttpError(404, "NOT_FOUND", "health log not found");
  const { role } = await dogAccessContext(ownerId, log.dogId);
  if (
    !canViewSensitiveRecord({
      accessRole: role,
      viewerId: ownerId,
      createdBy: log.createdBy,
      isSensitive: log.isSensitive,
    })
  ) {
    throw new HttpError(404, "NOT_FOUND", "health log not found");
  }
  return log;
}

async function requireHealthLogWriteAccess(ownerId: bigint, logId: bigint) {
  const log = await prisma.healthLog.findUnique({ where: { id: logId } });
  if (!log) throw new HttpError(404, "NOT_FOUND", "health log not found");
  await requireDogWriteAccess(ownerId, log.dogId);
  return log;
}

async function requireMedicalVisitAccess(ownerId: bigint, visitId: bigint) {
  const visit = await prisma.medicalVisit.findUnique({
    where: { id: visitId },
  });
  if (!visit) throw new HttpError(404, "NOT_FOUND", "medical visit not found");
  const { role } = await dogAccessContext(ownerId, visit.dogId);
  if (
    !canViewSensitiveRecord({
      accessRole: role,
      viewerId: ownerId,
      createdBy: visit.createdBy,
      isSensitive: visit.isSensitive,
    })
  ) {
    throw new HttpError(404, "NOT_FOUND", "medical visit not found");
  }
  return visit;
}

async function requireMedicalVisitWriteAccess(ownerId: bigint, visitId: bigint) {
  const visit = await prisma.medicalVisit.findUnique({
    where: { id: visitId },
  });
  if (!visit) throw new HttpError(404, "NOT_FOUND", "medical visit not found");
  await requireDogWriteAccess(ownerId, visit.dogId);
  return visit;
}

async function requireAttachmentAccess(ownerId: bigint, attachmentId: bigint) {
  const attachment = await prisma.medicalVisitAttachment.findUnique({
    where: { id: attachmentId },
    include: { medicalVisit: { select: { dogId: true } } },
  });
  if (!attachment)
    throw new HttpError(404, "NOT_FOUND", "attachment not found");
  await requireDogAccess(ownerId, attachment.medicalVisit.dogId);
  return attachment;
}

async function requireAttachmentWriteAccess(ownerId: bigint, attachmentId: bigint) {
  const attachment = await prisma.medicalVisitAttachment.findUnique({
    where: { id: attachmentId },
    include: { medicalVisit: { select: { dogId: true } } },
  });
  if (!attachment)
    throw new HttpError(404, "NOT_FOUND", "attachment not found");
  await requireDogWriteAccess(ownerId, attachment.medicalVisit.dogId);
  return attachment;
}

async function requireExpenseAccess(ownerId: bigint, expenseId: bigint) {
  const expense = await prisma.expense.findUnique({ where: { id: expenseId } });
  if (!expense) throw new HttpError(404, "NOT_FOUND", "expense not found");
  const { role } = await dogAccessContext(ownerId, expense.dogId);
  if (
    !canViewSensitiveRecord({
      accessRole: role,
      viewerId: ownerId,
      createdBy: expense.createdBy,
      isSensitive: expense.isSensitive,
    })
  ) {
    throw new HttpError(404, "NOT_FOUND", "expense not found");
  }
  return expense;
}

async function requireExpenseWriteAccess(ownerId: bigint, expenseId: bigint) {
  const expense = await prisma.expense.findUnique({ where: { id: expenseId } });
  if (!expense) throw new HttpError(404, "NOT_FOUND", "expense not found");
  await requireDogWriteAccess(ownerId, expense.dogId);
  return expense;
}

function parsePaging(req: AuthedRequest) {
  const page = Math.max(1, Number(req.query.page ?? 1));
  const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize ?? 20)));
  return { page, pageSize, skip: (page - 1) * pageSize };
}

function timelineType(value: unknown) {
  if (value === "health" || value === "health_log") return "health_log";
  if (value === "visit" || value === "medical_visit") return "medical_visit";
  if (value === "expense") return "expense";
  return "all";
}

function jsonRecord(value: Prisma.JsonValue | null | undefined) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Prisma.JsonObject;
}

function visitReportResponse(
  report: Awaited<ReturnType<typeof prisma.visitReport.findFirst>>,
) {
  if (!report) return null;
  const summary = jsonRecord(report.summaryJson);
  const sharePath = `/visit-reports/${report.id}`;
  const summaryShare = jsonRecord(summary?.share);
  return {
    ...report,
    summary,
    notice: visitReportNotice,
    share: {
      ...(summaryShare ?? {}),
      sharePath,
      pdfUrl: report.pdfUrl ?? summaryShare?.pdfUrl ?? null,
      pdfStatus: report.pdfUrl ? "ready" : (summaryShare?.pdfStatus ?? "not_generated"),
    },
  };
}

function recordResponse<T extends {
  createdBy?: bigint | null;
  createdAt?: Date | null;
  updatedAt?: Date | null;
  isSensitive?: boolean | null;
}>(
  record: T,
  viewerId: bigint,
  accessRole: AccessRole,
  users?: UserDirectory,
) {
  return {
    ...record,
    collaboration: collaborationMeta({
      record,
      viewerId,
      accessRole,
      users,
    }),
  };
}

function auditEventVisible<T extends {
  actorId: bigint | null;
  metadata: Prisma.JsonValue | null;
}>(event: T, viewerId: bigint, accessRole: AccessRole) {
  const metadata = jsonRecord(event.metadata);
  return canViewSensitiveRecord({
    accessRole,
    viewerId,
    createdBy: event.actorId,
    isSensitive: metadata?.isSensitive === true,
  });
}

function auditEventResponse<T extends {
  actorId: bigint | null;
  action: string;
  metadata: Prisma.JsonValue | null;
  actor?: { id: bigint; email: string; name: string } | null;
}>(event: T, viewerId: bigint) {
  const actorLabel = event.actorId
    ? event.actorId === viewerId
      ? "나"
      : event.actor?.name ?? "가족 구성원"
    : "시스템";
  return {
    ...event,
    actorLabel,
    metadata: jsonRecord(event.metadata),
  };
}

function careScheduleResponse<T extends {
  id: bigint;
  scheduleType: string;
  title: string;
  dueDate: Date;
  repeatCycleDays: number | null;
  priority: string;
  status: string;
  reminderEnabled: boolean;
  createdBy: bigint | null;
  assignedTo?: bigint | null;
  createdAt?: Date | null;
  updatedAt?: Date | null;
}>(
  schedule: T,
  viewerId: bigint,
  accessRole: AccessRole = null,
  users?: UserDirectory,
) {
  const decorated = decorateCareSchedule(schedule, viewerId);
  const assignment = assignmentMeta({
    assignedTo: schedule.assignedTo,
    fallbackUserId: schedule.createdBy,
    viewerId,
    users,
  });
  return {
    ...decorated,
    assignedToUserId: assignment.responsibleUserId,
    carePlan: {
      ...decorated.carePlan,
      ...assignment,
    },
    collaboration: collaborationMeta({
      record: schedule,
      viewerId,
      accessRole,
      users,
    }),
  };
}

function forecastResponse(
  row: Awaited<ReturnType<typeof latestForecasts>>["basic"],
) {
  if (!row) return null;
  const breakdown = jsonRecord(row.breakdown);
  const assumptions = jsonRecord(row.assumptions);
  const explanation =
    assumptions && "explanation" in assumptions ? assumptions.explanation : null;
  return {
    monthlyEstimate: row.monthlyEstimate,
    rangeMin: row.rangeMin,
    rangeMax: row.rangeMax,
    yearlyEstimate: row.yearlyEstimate,
    sixMonthEstimate: row.sixMonthEstimate,
    lifetimeEstimate: row.lifetimeEstimate,
    confidenceLevel: row.confidenceLevel,
    breakdown,
    assumptions,
    explanation,
  };
}

appRoutes.post(
  "/onboarding/dogs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogInput = req.body.dog ?? {};
    const baseDate = optionalDate(req.body.baseDate) ?? new Date();

    const result = await prisma.$transaction(async (tx) => {
      const dog = await tx.dog.create({
        data: {
          primaryOwnerId: ownerId,
          name: requireString(dogInput.name, "name"),
          breed: requireString(dogInput.breed, "breed"),
          birthDate: optionalDate(dogInput.birthDate),
          sex: requireString(dogInput.sex, "sex"),
          neutered: Boolean(dogInput.neutered),
          currentWeightKg: optionalNumber(dogInput.currentWeightKg),
          targetWeightKg: optionalNumber(dogInput.targetWeightKg),
          activityLevel:
            typeof dogInput.activityLevel === "string"
              ? dogInput.activityLevel
              : "medium",
          insuranceStatus:
            typeof dogInput.insuranceStatus === "string"
              ? dogInput.insuranceStatus
              : "none",
          notes:
            typeof dogInput.notes === "string" ? dogInput.notes : undefined,
        },
      });
      await tx.dogMembership.create({
        data: {
          dogId: dog.id,
          userId: ownerId,
          role: "owner",
          status: "active",
          invitedBy: ownerId,
          joinedAt: new Date(),
        },
      });

      for (const condition of Array.isArray(req.body.conditions)
        ? req.body.conditions
        : []) {
        await tx.dogCondition.create({
          data: {
            dogId: dog.id,
            conditionType: requireString(
              condition.conditionType,
              "conditionType",
            ),
            conditionName: requireString(
              condition.conditionName,
              "conditionName",
            ),
            severity:
              typeof condition.severity === "string"
                ? condition.severity
                : undefined,
            diagnosedOn: optionalDate(condition.diagnosedOn),
            status:
              typeof condition.status === "string"
                ? condition.status
                : "active",
            notes:
              typeof condition.notes === "string" ? condition.notes : undefined,
          },
        });
      }

      for (const medication of Array.isArray(req.body.medications)
        ? req.body.medications
        : []) {
        await tx.dogMedication.create({
          data: {
            dogId: dog.id,
            medicationName: requireString(
              medication.medicationName,
              "medicationName",
            ),
            dosage:
              typeof medication.dosage === "string"
                ? medication.dosage
                : undefined,
            frequencyText:
              typeof medication.frequencyText === "string"
                ? medication.frequencyText
                : undefined,
            startedOn: optionalDate(medication.startedOn),
            endedOn: optionalDate(medication.endedOn),
            prescribedBy:
              typeof medication.prescribedBy === "string"
                ? medication.prescribedBy
                : undefined,
            isActive: medication.isActive !== false,
            notes:
              typeof medication.notes === "string"
                ? medication.notes
                : undefined,
          },
        });
      }

      const generatedScheduleCount = await generateDefaultCareSchedules(
        tx,
        dog.id,
        baseDate,
        ownerId,
      );
      await recalculateCostForecasts(tx, dog.id);
      const forecasts = await latestForecasts(tx, dog.id);
      return { dog, generatedScheduleCount, forecasts };
    });

    ok(
      res,
      {
        dogId: result.dog.id,
        generatedScheduleCount: result.generatedScheduleCount,
        forecastSummary: {
          monthlyEstimate: result.forecasts.basic?.monthlyEstimate ?? null,
          yearlyEstimate: result.forecasts.basic?.yearlyEstimate ?? null,
        },
      },
      201,
    );
  }),
);

appRoutes.post(
  "/dogs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dog = await prisma.$transaction(async (tx) => {
      const created = await tx.dog.create({
        data: {
          primaryOwnerId: ownerId,
          name: requireString(req.body.name, "name"),
          breed: requireString(req.body.breed, "breed"),
          birthDate: optionalDate(req.body.birthDate),
          sex: requireString(req.body.sex, "sex"),
          neutered: Boolean(req.body.neutered),
          currentWeightKg: optionalNumber(req.body.currentWeightKg),
          targetWeightKg: optionalNumber(req.body.targetWeightKg),
          activityLevel:
            typeof req.body.activityLevel === "string"
              ? req.body.activityLevel
              : "medium",
          insuranceStatus:
            typeof req.body.insuranceStatus === "string"
              ? req.body.insuranceStatus
              : "none",
          notes:
            typeof req.body.notes === "string" ? req.body.notes : undefined,
        },
        select: { id: true, name: true },
      });
      await tx.dogMembership.create({
        data: {
          dogId: created.id,
          userId: ownerId,
          role: "owner",
          status: "active",
          invitedBy: ownerId,
          joinedAt: new Date(),
        },
      });
      return created;
    });
    ok(res, dog, 201);
  }),
);

appRoutes.get(
  "/dogs",
  asyncHandler(async (req, res) => {
    const requesterId = userId(req as AuthedRequest);
    const dogs = await prisma.dog.findMany({
      where: {
        OR: [
          { primaryOwnerId: requesterId },
          {
            memberships: {
              some: { userId: requesterId, status: "active" },
            },
          },
        ],
      },
      orderBy: { createdAt: "desc" },
    });
    ok(res, dogs);
  }),
);

appRoutes.get(
  "/dogs/:dogId",
  asyncHandler(async (req, res) => {
    ok(
      res,
      await requireDogAccess(
        userId(req as AuthedRequest),
        parseId(req.params.dogId, "dogId"),
      ),
    );
  }),
);

appRoutes.patch(
  "/dogs/:dogId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogOwnerAccess(ownerId, dogId);
    const dog = await prisma.dog.update({
      where: { id: dogId },
      data: {
        name: typeof req.body.name === "string" ? req.body.name : undefined,
        breed: typeof req.body.breed === "string" ? req.body.breed : undefined,
        birthDate: optionalDate(req.body.birthDate),
        sex: typeof req.body.sex === "string" ? req.body.sex : undefined,
        neutered:
          typeof req.body.neutered === "boolean"
            ? req.body.neutered
            : undefined,
        currentWeightKg: optionalNumber(req.body.currentWeightKg),
        targetWeightKg: optionalNumber(req.body.targetWeightKg),
        activityLevel:
          typeof req.body.activityLevel === "string"
            ? req.body.activityLevel
            : undefined,
        insuranceStatus:
          typeof req.body.insuranceStatus === "string"
            ? req.body.insuranceStatus
            : undefined,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
      },
    });
    await recalculateCostForecasts(prisma, dogId);
    ok(res, dog);
  }),
);

appRoutes.get(
  "/dogs/:dogId/delete-preview",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const dog = await requireDogOwnerAccess(ownerId, dogId);

    const [
      schedules,
      conditions,
      medications,
      healthLogs,
      medicalVisits,
      expenses,
      forecasts,
      visitReports,
      attachments,
    ] = await Promise.all([
      prisma.careSchedule.count({ where: { dogId } }),
      prisma.dogCondition.count({ where: { dogId } }),
      prisma.dogMedication.count({ where: { dogId } }),
      prisma.healthLog.count({ where: { dogId } }),
      prisma.medicalVisit.count({ where: { dogId } }),
      prisma.expense.count({ where: { dogId } }),
      prisma.costForecast.count({ where: { dogId } }),
      prisma.visitReport.count({ where: { dogId } }),
      prisma.medicalVisitAttachment.aggregate({
        where: { medicalVisit: { dogId } },
        _count: { _all: true },
        _sum: { fileSizeBytes: true },
      }),
    ]);

    ok(res, {
      dog: { id: dog.id, name: dog.name },
      scope: "pet",
      accessPolicy: "primary_owner_only",
      counts: {
        schedules,
        conditions,
        medications,
        healthLogs,
        medicalVisits,
        expenses,
        forecasts,
        visitReports,
        attachments: attachments._count._all,
      },
      attachmentBytes: attachments._sum.fileSizeBytes ?? 0,
    });
  }),
);

appRoutes.delete(
  "/dogs/:dogId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogOwnerAccess(ownerId, dogId);

    const attachments = await prisma.medicalVisitAttachment.findMany({
      where: { medicalVisit: { dogId } },
      select: { fileUrl: true },
    });

    await prisma.dog.delete({ where: { id: dogId } });
    await Promise.all(
      attachments.map((attachment) => deleteAttachmentFile(attachment.fileUrl)),
    );

    ok(res, {
      deleted: true,
      scope: "pet",
      accessPolicy: "primary_owner_only",
    });
  }),
);

appRoutes.get(
  "/dogs/:dogId/members",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);

    const memberships = await prisma.dogMembership.findMany({
      where: { dogId, status: "active" },
      orderBy: [{ role: "asc" }, { createdAt: "asc" }],
      include: {
        user: { select: { id: true, email: true, name: true } },
      },
    });

    ok(
      res,
      memberships.map((membership) => ({
        id: membership.id,
        dogId: membership.dogId,
        userId: membership.userId,
        role: membership.role,
        status: membership.status,
        joinedAt: membership.joinedAt,
        createdAt: membership.createdAt,
        user: membership.user,
      })),
    );
  }),
);

appRoutes.post(
  "/dogs/:dogId/members",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogOwnerAccess(ownerId, dogId);

    const email = requireString(req.body.email, "email").toLowerCase();
    const role = normalizeMembershipRole(req.body.role ?? "viewer");
    const member = await prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, name: true },
    });
    if (!member) {
      throw new HttpError(404, "NOT_FOUND", "user not found");
    }

    const membership = await prisma.dogMembership.upsert({
      where: { dogId_userId: { dogId, userId: member.id } },
      create: {
        dogId,
        userId: member.id,
        role,
        status: "active",
        invitedBy: ownerId,
        joinedAt: new Date(),
      },
      update: {
        role,
        status: "active",
        invitedBy: ownerId,
        joinedAt: new Date(),
      },
      include: {
        user: { select: { id: true, email: true, name: true } },
      },
    });
    await writeAuditEvent(prisma, {
      dogId,
      actorId: ownerId,
      entityType: "membership",
      entityId: membership.id,
      action: "upsert",
      summary: `${membership.user.name} ${membership.role}`,
      metadata: { role: membership.role },
    });

    ok(
      res,
      {
        id: membership.id,
        dogId: membership.dogId,
        userId: membership.userId,
        role: membership.role,
        status: membership.status,
        joinedAt: membership.joinedAt,
        user: membership.user,
      },
      201,
    );
  }),
);

appRoutes.patch(
  "/dog-memberships/:membershipId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const membershipId = parseId(req.params.membershipId, "membershipId");
    const existing = await requireMembershipOwnerAccess(ownerId, membershipId);
    const role =
      req.body.role === undefined ? existing.role : normalizeMembershipRole(req.body.role);
    const status =
      typeof req.body.status === "string" ? req.body.status : existing.status;

    if (status !== "active" && status !== "removed") {
      throw new HttpError(
        400,
        "VALIDATION_ERROR",
        "status must be active or removed",
      );
    }

    if (existing.userId === ownerId && (role !== "owner" || status !== "active")) {
      throw new HttpError(
        400,
        "VALIDATION_ERROR",
        "cannot demote or remove your own owner membership",
      );
    }

    const membership = await prisma.dogMembership.update({
      where: { id: membershipId },
      data: { role, status },
      include: {
        user: { select: { id: true, email: true, name: true } },
      },
    });
    await writeAuditEvent(prisma, {
      dogId: membership.dogId,
      actorId: ownerId,
      entityType: "membership",
      entityId: membership.id,
      action: "update",
      summary: `${membership.user.name} ${membership.role}`,
      metadata: { role: membership.role, status: membership.status },
    });

    ok(res, {
      id: membership.id,
      dogId: membership.dogId,
      userId: membership.userId,
      role: membership.role,
      status: membership.status,
      joinedAt: membership.joinedAt,
      user: membership.user,
    });
  }),
);

appRoutes.delete(
  "/dog-memberships/:membershipId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const membershipId = parseId(req.params.membershipId, "membershipId");
    const existing = await requireMembershipOwnerAccess(ownerId, membershipId);

    if (existing.userId === ownerId) {
      throw new HttpError(
        400,
        "VALIDATION_ERROR",
        "cannot remove your own owner membership",
      );
    }

    await prisma.dogMembership.update({
      where: { id: membershipId },
      data: { status: "removed" },
    });
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "membership",
      entityId: membershipId,
      action: "remove",
      summary: existing.userId.toString(),
      metadata: { status: "removed" },
    });

    ok(res, { removed: true });
  }),
);

appRoutes.get(
  "/dogs/:dogId/dashboard",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { dog, role } = await dogAccessContext(ownerId, dogId);
    const recordVisibility = sensitiveRecordWhere(role, ownerId);
    const canEditRecords = role === "owner" || role === "editor";
    const today = new Date();
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    const [
      todaySchedules,
      recentHealthLogs,
      expenses,
      forecasts,
      members,
      rawActivity,
      hiddenConditions,
      hiddenMedications,
      hiddenHealthLogs,
      hiddenMedicalVisits,
      hiddenExpenses,
    ] =
      await Promise.all([
        prisma.careSchedule.findMany({
          where: {
            dogId,
            status: "pending",
            dueDate: {
              gte: addDays(new Date(today.toISOString().slice(0, 10)), -30),
              lte: monthEnd,
            },
          },
          orderBy: { dueDate: "asc" },
          take: 5,
        }),
        prisma.healthLog.findMany({
          where: { dogId, ...recordVisibility },
          orderBy: { recordedAt: "desc" },
          take: 5,
        }),
        prisma.expense.findMany({
          where: {
            dogId,
            ...recordVisibility,
            expenseDate: { gte: monthStart, lte: monthEnd },
          },
        }),
        latestForecasts(prisma, dogId),
        prisma.dogMembership.findMany({
          where: { dogId, status: "active" },
          orderBy: [{ role: "asc" }, { createdAt: "asc" }],
          include: { user: { select: userSummarySelect } },
        }),
        prisma.recordAuditEvent.findMany({
          where: { dogId },
          orderBy: { createdAt: "desc" },
          take: 20,
          include: { actor: { select: userSummarySelect } },
        }),
        canEditRecords
          ? Promise.resolve(0)
          : prisma.dogCondition.count({
              where: {
                dogId,
                isSensitive: true,
                NOT: { createdBy: ownerId },
              },
            }),
        canEditRecords
          ? Promise.resolve(0)
          : prisma.dogMedication.count({
              where: {
                dogId,
                isSensitive: true,
                NOT: { createdBy: ownerId },
              },
            }),
        canEditRecords
          ? Promise.resolve(0)
          : prisma.healthLog.count({
              where: {
                dogId,
                isSensitive: true,
                NOT: { createdBy: ownerId },
              },
            }),
        canEditRecords
          ? Promise.resolve(0)
          : prisma.medicalVisit.count({
              where: {
                dogId,
                isSensitive: true,
                NOT: { createdBy: ownerId },
              },
            }),
        canEditRecords
          ? Promise.resolve(0)
          : prisma.expense.count({
              where: {
                dogId,
                isSensitive: true,
                NOT: { createdBy: ownerId },
              },
            }),
      ]);
    const userDirectory = buildUserDirectory(
      members.map((membership) => membership.user),
    );
    const recentActivity = rawActivity
      .filter((event) => auditEventVisible(event, ownerId, role))
      .slice(0, 8)
      .map((event) => auditEventResponse(event, ownerId));

    const byCategory = Object.values(
      expenses.reduce<Record<string, { category: string; amount: number }>>(
        (acc, expense) => {
          acc[expense.expenseCategory] ??= {
            category: expense.expenseCategory,
            amount: 0,
          };
          acc[expense.expenseCategory].amount += Number(expense.amount);
          return acc;
        },
        {},
      ),
    );
    ok(res, {
      dog: {
        id: dog.id,
        name: dog.name,
        breed: dog.breed,
        birthDate: dog.birthDate,
        sex: dog.sex,
        neutered: dog.neutered,
        currentWeightKg: dog.currentWeightKg,
        targetWeightKg: dog.targetWeightKg,
        activityLevel: dog.activityLevel,
        insuranceStatus: dog.insuranceStatus,
        notes: dog.notes,
      },
      todaySchedules: todaySchedules.map((schedule) =>
        careScheduleResponse(schedule, ownerId, role, userDirectory),
      ),
      recentHealthLogs: recentHealthLogs.map((log) =>
        recordResponse(log, ownerId, role, userDirectory),
      ),
      monthlyExpenseSummary: {
        totalAmount: byCategory.reduce((sum, item) => sum + item.amount, 0),
        byCategory,
      },
      latestForecast: forecasts.basic
        ? {
            monthlyEstimate: forecasts.basic.monthlyEstimate,
            yearlyEstimate: forecasts.basic.yearlyEstimate,
          }
        : null,
      access: {
        userId: ownerId,
        role,
        canManage: role === "owner",
        canEditRecords,
        canViewSensitive: canEditRecords,
      },
      collaboration: {
        members: members.map((membership) => ({
          id: membership.id,
          dogId: membership.dogId,
          userId: membership.userId,
          role: membership.role,
          status: membership.status,
          joinedAt: membership.joinedAt,
          user: membership.user,
        })),
        hiddenSensitiveCounts: {
          conditions: hiddenConditions,
          medications: hiddenMedications,
          healthLogs: hiddenHealthLogs,
          medicalVisits: hiddenMedicalVisits,
          expenses: hiddenExpenses,
          total:
            hiddenConditions +
            hiddenMedications +
            hiddenHealthLogs +
            hiddenMedicalVisits +
            hiddenExpenses,
        },
        recentActivity,
      },
    });
  }),
);

appRoutes.get(
  "/dogs/:dogId/conditions",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const conditions = await prisma.dogCondition.findMany({
      where: {
        dogId,
        ...sensitiveRecordWhere(role, ownerId),
        status:
          typeof req.query.status === "string" ? req.query.status : undefined,
      },
      orderBy: [{ status: "asc" }, { updatedAt: "desc" }],
    });
    const users = await loadDogUserDirectory(
      dogId,
      conditions.map((condition) => condition.createdBy),
    );
    ok(
      res,
      conditions.map((condition) =>
        recordResponse(condition, ownerId, role, users),
      ),
    );
  }),
);

appRoutes.post(
  "/dogs/:dogId/conditions",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const condition = await prisma.dogCondition.create({
      data: {
        dogId,
        conditionType: requireString(req.body.conditionType, "conditionType"),
        conditionName: requireString(req.body.conditionName, "conditionName"),
        severity:
          typeof req.body.severity === "string" ? req.body.severity : undefined,
        diagnosedOn: optionalDate(req.body.diagnosedOn),
        status:
          typeof req.body.status === "string" ? req.body.status : "active",
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    await recalculateCostForecasts(prisma, dogId);
    await writeAuditEvent(prisma, {
      dogId,
      actorId: ownerId,
      entityType: "condition",
      entityId: condition.id,
      action: "create",
      summary: condition.conditionName,
      metadata: { isSensitive: condition.isSensitive },
    });
    ok(res, condition, 201);
  }),
);

appRoutes.patch(
  "/conditions/:conditionId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const conditionId = parseId(req.params.conditionId, "conditionId");
    const existing = await requireConditionWriteAccess(ownerId, conditionId);
    const condition = await prisma.dogCondition.update({
      where: { id: conditionId },
      data: {
        conditionType:
          typeof req.body.conditionType === "string"
            ? req.body.conditionType
            : undefined,
        conditionName:
          typeof req.body.conditionName === "string"
            ? req.body.conditionName
            : undefined,
        severity:
          typeof req.body.severity === "string" ? req.body.severity : undefined,
        diagnosedOn: patchOptionalDate(req.body, "diagnosedOn"),
        status:
          typeof req.body.status === "string" ? req.body.status : undefined,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive:
          req.body.isSensitive === undefined
            ? undefined
            : normalizeSensitiveFlag(req.body),
      },
    });
    await recalculateCostForecasts(prisma, existing.dogId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "condition",
      entityId: condition.id,
      action: "update",
      summary: condition.conditionName,
      metadata: { isSensitive: condition.isSensitive },
    });
    ok(res, condition);
  }),
);

appRoutes.delete(
  "/conditions/:conditionId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const conditionId = parseId(req.params.conditionId, "conditionId");
    const existing = await requireConditionWriteAccess(ownerId, conditionId);
    await prisma.dogCondition.delete({ where: { id: conditionId } });
    await recalculateCostForecasts(prisma, existing.dogId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "condition",
      entityId: conditionId,
      action: "delete",
      summary: existing.conditionName,
      metadata: { isSensitive: existing.isSensitive },
    });
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/dogs/:dogId/medications",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const onlyActive = req.query.active === "true";
    const medications = await prisma.dogMedication.findMany({
      where: {
        dogId,
        ...sensitiveRecordWhere(role, ownerId),
        isActive: onlyActive ? true : undefined,
      },
      orderBy: [{ isActive: "desc" }, { updatedAt: "desc" }],
    });
    const users = await loadDogUserDirectory(
      dogId,
      medications.map((medication) => medication.createdBy),
    );
    ok(
      res,
      medications.map((medication) =>
        recordResponse(medication, ownerId, role, users),
      ),
    );
  }),
);

appRoutes.post(
  "/dogs/:dogId/medications",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const medication = await prisma.dogMedication.create({
      data: {
        dogId,
        medicationName: requireString(
          req.body.medicationName,
          "medicationName",
        ),
        dosage:
          typeof req.body.dosage === "string" ? req.body.dosage : undefined,
        frequencyText:
          typeof req.body.frequencyText === "string"
            ? req.body.frequencyText
            : undefined,
        startedOn: patchOptionalDate(req.body, "startedOn"),
        endedOn: patchOptionalDate(req.body, "endedOn"),
        prescribedBy:
          typeof req.body.prescribedBy === "string"
            ? req.body.prescribedBy
            : undefined,
        isActive: req.body.isActive !== false,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    await recalculateCostForecasts(prisma, dogId);
    await writeAuditEvent(prisma, {
      dogId,
      actorId: ownerId,
      entityType: "medication",
      entityId: medication.id,
      action: "create",
      summary: medication.medicationName,
      metadata: { isSensitive: medication.isSensitive },
    });
    ok(res, medication, 201);
  }),
);

appRoutes.patch(
  "/medications/:medicationId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const medicationId = parseId(req.params.medicationId, "medicationId");
    const existing = await requireMedicationWriteAccess(ownerId, medicationId);
    const medication = await prisma.dogMedication.update({
      where: { id: medicationId },
      data: {
        medicationName:
          typeof req.body.medicationName === "string"
            ? req.body.medicationName
            : undefined,
        dosage:
          typeof req.body.dosage === "string" ? req.body.dosage : undefined,
        frequencyText:
          typeof req.body.frequencyText === "string"
            ? req.body.frequencyText
            : undefined,
        startedOn: optionalDate(req.body.startedOn),
        endedOn: optionalDate(req.body.endedOn),
        prescribedBy:
          typeof req.body.prescribedBy === "string"
            ? req.body.prescribedBy
            : undefined,
        isActive:
          typeof req.body.isActive === "boolean"
            ? req.body.isActive
            : undefined,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive:
          req.body.isSensitive === undefined
            ? undefined
            : normalizeSensitiveFlag(req.body),
      },
    });
    await recalculateCostForecasts(prisma, existing.dogId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "medication",
      entityId: medication.id,
      action: "update",
      summary: medication.medicationName,
      metadata: { isSensitive: medication.isSensitive },
    });
    ok(res, medication);
  }),
);

appRoutes.delete(
  "/medications/:medicationId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const medicationId = parseId(req.params.medicationId, "medicationId");
    const existing = await requireMedicationWriteAccess(ownerId, medicationId);
    await prisma.dogMedication.delete({ where: { id: medicationId } });
    await recalculateCostForecasts(prisma, existing.dogId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "medication",
      entityId: medicationId,
      action: "delete",
      summary: existing.medicationName,
      metadata: { isSensitive: existing.isSensitive },
    });
    ok(res, { deleted: true });
  }),
);

appRoutes.post(
  "/dogs/:dogId/care-schedules/generate",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const generatedCount = await generateDefaultCareSchedules(
      prisma,
      dogId,
      optionalDate(req.body.baseDate) ?? new Date(),
      ownerId,
    );
    ok(res, { generatedCount }, 201);
  }),
);

appRoutes.get(
  "/dogs/:dogId/care-schedules",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const schedules = await prisma.careSchedule.findMany({
      where: {
        dogId,
        status:
          typeof req.query.status === "string" ? req.query.status : undefined,
        dueDate: {
          gte:
            typeof req.query.from === "string"
              ? new Date(req.query.from)
              : undefined,
          lte:
            typeof req.query.to === "string"
              ? new Date(req.query.to)
              : undefined,
        },
      },
      orderBy: { dueDate: "asc" },
    });
    const users = await loadDogUserDirectory(
      dogId,
      schedules.flatMap((schedule) => [schedule.createdBy, schedule.assignedTo]),
    );
    ok(
      res,
      schedules.map((schedule) =>
        careScheduleResponse(schedule, ownerId, role, users),
      ),
    );
  }),
);

appRoutes.post(
  "/dogs/:dogId/care-schedules",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const { role } = await dogAccessContext(ownerId, dogId);
    const assignedTo = await parseAssignableUserId(
      req.body.assignedToUserId ?? req.body.assignedTo,
      dogId,
    );
    const schedule = await prisma.careSchedule.create({
      data: {
        dogId,
        scheduleType: requireString(req.body.scheduleType, "scheduleType"),
        title: requireString(req.body.title, "title"),
        description:
          typeof req.body.description === "string"
            ? req.body.description
            : undefined,
        dueDate: optionalDate(req.body.dueDate) ?? new Date(),
        repeatCycleDays:
          typeof req.body.repeatCycleDays === "number"
            ? req.body.repeatCycleDays
            : undefined,
        priority:
          typeof req.body.priority === "string" ? req.body.priority : "medium",
        sourceType:
          typeof req.body.sourceType === "string"
            ? req.body.sourceType
            : "manual",
        createdBy: ownerId,
        assignedTo: assignedTo === undefined ? ownerId : assignedTo,
      },
    });
    await writeAuditEvent(prisma, {
      dogId,
      actorId: ownerId,
      entityType: "care_schedule",
      entityId: schedule.id,
      action: "create",
      summary: schedule.title,
      metadata: {
        scheduleType: schedule.scheduleType,
        assignedTo: schedule.assignedTo?.toString() ?? null,
      },
    });
    const users = await loadDogUserDirectory(dogId, [
      schedule.createdBy,
      schedule.assignedTo,
    ]);
    ok(res, careScheduleResponse(schedule, ownerId, role, users), 201);
  }),
);

appRoutes.get(
  "/care-schedules/:scheduleId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const schedule = await requireScheduleAccess(ownerId, scheduleId);
    const { role } = await dogAccessContext(ownerId, schedule.dogId);
    const users = await loadDogUserDirectory(schedule.dogId, [
      schedule.createdBy,
      schedule.assignedTo,
    ]);
    ok(
      res,
      careScheduleResponse(schedule, ownerId, role, users),
    );
  }),
);

appRoutes.patch(
  "/care-schedules/:scheduleId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireScheduleWriteAccess(ownerId, scheduleId);
    const { role } = await dogAccessContext(ownerId, existing.dogId);
    const assignedTo = await parseAssignableUserId(
      req.body.assignedToUserId ?? req.body.assignedTo,
      existing.dogId,
    );
    const schedule = await prisma.careSchedule.update({
      where: { id: scheduleId },
      data: {
        title: typeof req.body.title === "string" ? req.body.title : undefined,
        description:
          typeof req.body.description === "string"
            ? req.body.description
            : undefined,
        dueDate: optionalDate(req.body.dueDate),
        scheduleType:
          typeof req.body.scheduleType === "string"
            ? req.body.scheduleType
            : undefined,
        repeatCycleDays:
          req.body.repeatCycleDays === null
            ? null
            : typeof req.body.repeatCycleDays === "number"
              ? req.body.repeatCycleDays
              : undefined,
        priority:
          typeof req.body.priority === "string" ? req.body.priority : undefined,
        reminderEnabled:
          typeof req.body.reminderEnabled === "boolean"
            ? req.body.reminderEnabled
            : undefined,
        assignedTo,
      },
    });
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "care_schedule",
      entityId: schedule.id,
      action: "update",
      summary: schedule.title,
      metadata: {
        scheduleType: schedule.scheduleType,
        assignedTo: schedule.assignedTo?.toString() ?? null,
      },
    });
    const users = await loadDogUserDirectory(existing.dogId, [
      schedule.createdBy,
      schedule.assignedTo,
    ]);
    ok(res, careScheduleResponse(schedule, ownerId, role, users));
  }),
);

appRoutes.post(
  "/care-schedules/:scheduleId/complete",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireScheduleWriteAccess(ownerId, scheduleId);
    const { role } = await dogAccessContext(ownerId, existing.dogId);
    if (existing.status !== "pending") {
      const users = await loadDogUserDirectory(existing.dogId, [
        existing.createdBy,
        existing.assignedTo,
      ]);
      ok(res, careScheduleResponse(existing, ownerId, role, users));
      return;
    }
    const completedAt = optionalDate(req.body.completedAt) ?? new Date();
    const schedule = await prisma.careSchedule.update({
      where: { id: scheduleId },
      data: { status: "completed", completedAt },
    });

    await createNextRecurringSchedule(existing, ownerId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "care_schedule",
      entityId: schedule.id,
      action: "complete",
      summary: schedule.title,
      metadata: { scheduleType: schedule.scheduleType },
    });

    const users = await loadDogUserDirectory(existing.dogId, [
      schedule.createdBy,
      schedule.assignedTo,
    ]);
    ok(res, careScheduleResponse(schedule, ownerId, role, users));
  }),
);

appRoutes.post(
  "/care-schedules/:scheduleId/skip",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireScheduleWriteAccess(ownerId, scheduleId);
    const { role } = await dogAccessContext(ownerId, existing.dogId);
    if (existing.status !== "pending") {
      const users = await loadDogUserDirectory(existing.dogId, [
        existing.createdBy,
        existing.assignedTo,
      ]);
      ok(res, careScheduleResponse(existing, ownerId, role, users));
      return;
    }
    const schedule = await prisma.careSchedule.update({
      where: { id: scheduleId },
      data: { status: "skipped" },
    });
    await createNextRecurringSchedule(existing, ownerId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "care_schedule",
      entityId: schedule.id,
      action: "skip",
      summary: schedule.title,
      metadata: { scheduleType: schedule.scheduleType },
    });
    const users = await loadDogUserDirectory(existing.dogId, [
      schedule.createdBy,
      schedule.assignedTo,
    ]);
    ok(res, careScheduleResponse(schedule, ownerId, role, users));
  }),
);

appRoutes.get(
  "/dogs/:dogId/timeline",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const type = timelineType(req.query.type);
    const from = optionalDate(req.query.from);
    const to = optionalDate(req.query.to);
    const take = skip + pageSize;
    const dateFilter = {
      ...(from ? { gte: from } : {}),
      ...(to ? { lte: to } : {}),
    };
    const recordVisibility = sensitiveRecordWhere(role, ownerId);
    const healthWhere = { dogId, ...recordVisibility, recordedAt: dateFilter };
    const visitWhere = { dogId, ...recordVisibility, visitDate: dateFilter };
    const expenseWhere = { dogId, ...recordVisibility, expenseDate: dateFilter };

    const [logs, visits, expenses, healthTotal, visitTotal, expenseTotal] =
      await Promise.all([
        type === "all" || type === "health_log"
          ? prisma.healthLog.findMany({
              where: healthWhere,
              orderBy: { recordedAt: "desc" },
              take,
            })
          : [],
        type === "all" || type === "medical_visit"
          ? prisma.medicalVisit.findMany({
              where: visitWhere,
              orderBy: { visitDate: "desc" },
              include: { _count: { select: { attachments: true } } },
              take,
            })
          : [],
        type === "all" || type === "expense"
          ? prisma.expense.findMany({
              where: expenseWhere,
              orderBy: { expenseDate: "desc" },
              take,
            })
          : [],
        type === "all" || type === "health_log"
          ? prisma.healthLog.count({ where: healthWhere })
          : 0,
        type === "all" || type === "medical_visit"
          ? prisma.medicalVisit.count({ where: visitWhere })
          : 0,
        type === "all" || type === "expense"
          ? prisma.expense.count({ where: expenseWhere })
          : 0,
      ]);
    const users = await loadDogUserDirectory(dogId, [
      ...logs.map((log) => log.createdBy),
      ...visits.map((visit) => visit.createdBy),
      ...expenses.map((expense) => expense.createdBy),
    ]);

    const items = [
      ...logs.map((log) => ({
        itemType: "health_log",
        id: log.id,
        logType: log.logType,
        title: log.title,
        eventAt: log.recordedAt,
        summary:
          log.valueNumeric !== null && log.valueNumeric !== undefined
            ? `${log.valueNumeric}${log.valueUnit ?? ""}`
            : log.memo,
        collaboration: collaborationMeta({
          record: log,
          viewerId: ownerId,
          accessRole: role,
          users,
        }),
      })),
      ...visits.map((visit) => ({
        itemType: "medical_visit",
        id: visit.id,
        eventAt: visit.visitDate,
        title: `${visit.hospitalName} 방문`,
        summary: visit.visitReason ?? visit.diagnosis,
        hospitalName: visit.hospitalName,
        attachmentCount: visit._count.attachments,
        collaboration: collaborationMeta({
          record: visit,
          viewerId: ownerId,
          accessRole: role,
          users,
        }),
      })),
      ...expenses.map((expense) => ({
        itemType: "expense",
        id: expense.id,
        eventAt: expense.expenseDate,
        title: `${expense.expenseCategory} 지출`,
        summary: expense.vendorName ?? expense.memo,
        expenseCategory: expense.expenseCategory,
        amount: expense.amount,
        collaboration: collaborationMeta({
          record: expense,
          viewerId: ownerId,
          accessRole: role,
          users,
        }),
      })),
    ].sort(
      (a, b) => new Date(b.eventAt).getTime() - new Date(a.eventAt).getTime(),
    );
    ok(res, {
      items: items.slice(skip, skip + pageSize),
      page,
      pageSize,
      total: healthTotal + visitTotal + expenseTotal,
      type,
    });
  }),
);

appRoutes.get(
  "/dogs/:dogId/activity",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const rawEvents = await prisma.recordAuditEvent.findMany({
      where: { dogId },
      orderBy: { createdAt: "desc" },
      skip,
      take: pageSize * 2,
      include: { actor: { select: userSummarySelect } },
    });
    const visibleEvents = rawEvents
      .filter((event) => auditEventVisible(event, ownerId, role))
      .slice(0, pageSize)
      .map((event) => auditEventResponse(event, ownerId));
    ok(res, {
      items: visibleEvents,
      page,
      pageSize,
      total: visibleEvents.length + skip,
    });
  }),
);

appRoutes.get(
  "/dogs/:dogId/health-logs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const where = {
      dogId,
      ...sensitiveRecordWhere(role, ownerId),
      logType: typeof req.query.type === "string" ? req.query.type : undefined,
    };
    const [items, total] = await Promise.all([
      prisma.healthLog.findMany({
        where,
        orderBy: { recordedAt: "desc" },
        skip,
        take: pageSize,
      }),
      prisma.healthLog.count({ where }),
    ]);
    const users = await loadDogUserDirectory(
      dogId,
      items.map((item) => item.createdBy),
    );
    ok(res, {
      items: items.map((item) => recordResponse(item, ownerId, role, users)),
      page,
      pageSize,
      total,
    });
  }),
);

appRoutes.post(
  "/dogs/:dogId/health-logs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const { role } = await dogAccessContext(ownerId, dogId);
    const log = await prisma.healthLog.create({
      data: {
        dogId,
        logType: requireString(req.body.logType, "logType"),
        title: typeof req.body.title === "string" ? req.body.title : undefined,
        recordedAt: optionalDate(req.body.recordedAt) ?? new Date(),
        valueNumeric: optionalNumber(req.body.valueNumeric),
        valueUnit:
          typeof req.body.valueUnit === "string"
            ? req.body.valueUnit
            : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        metadata:
          req.body.metadata === undefined ? Prisma.JsonNull : req.body.metadata,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    await writeAuditEvent(prisma, {
      dogId,
      actorId: ownerId,
      entityType: "health_log",
      entityId: log.id,
      action: "create",
      summary: log.title ?? log.logType,
      metadata: { isSensitive: log.isSensitive },
    });
    const users = await loadDogUserDirectory(dogId, [log.createdBy]);
    ok(res, recordResponse(log, ownerId, role, users), 201);
  }),
);

appRoutes.get(
  "/health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const log = await requireHealthLogAccess(
      ownerId,
      parseId(req.params.logId, "logId"),
    );
    const { role } = await dogAccessContext(ownerId, log.dogId);
    const users = await loadDogUserDirectory(log.dogId, [log.createdBy]);
    ok(res, recordResponse(log, ownerId, role, users));
  }),
);

appRoutes.patch(
  "/health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const logId = parseId(req.params.logId, "logId");
    const existing = await requireHealthLogWriteAccess(ownerId, logId);
    const { role } = await dogAccessContext(ownerId, existing.dogId);
    const log = await prisma.healthLog.update({
      where: { id: logId },
      data: {
        logType:
          typeof req.body.logType === "string" ? req.body.logType : undefined,
        title:
          typeof req.body.title === "string" ? req.body.title : undefined,
        recordedAt: optionalDate(req.body.recordedAt),
        valueNumeric: optionalNumber(req.body.valueNumeric),
        valueUnit:
          typeof req.body.valueUnit === "string"
            ? req.body.valueUnit
            : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        metadata:
          req.body.metadata === undefined ? undefined : req.body.metadata,
        isSensitive:
          req.body.isSensitive === undefined
            ? undefined
            : normalizeSensitiveFlag(req.body),
      },
    });
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "health_log",
      entityId: log.id,
      action: "update",
      summary: log.title ?? log.logType,
      metadata: { isSensitive: log.isSensitive },
    });
    const users = await loadDogUserDirectory(existing.dogId, [log.createdBy]);
    ok(res, recordResponse(log, ownerId, role, users));
  }),
);

appRoutes.delete(
  "/health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const logId = parseId(req.params.logId, "logId");
    await requireHealthLogWriteAccess(ownerId, logId);
    const existing = await prisma.healthLog.delete({ where: { id: logId } });
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "health_log",
      entityId: logId,
      action: "delete",
      summary: existing.title ?? existing.logType,
      metadata: { isSensitive: existing.isSensitive },
    });
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/dogs/:dogId/medical-visits",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const [items, total] = await Promise.all([
      prisma.medicalVisit.findMany({
        where: { dogId, ...sensitiveRecordWhere(role, ownerId) },
        orderBy: { visitDate: "desc" },
        include: { attachments: { orderBy: { createdAt: "desc" } } },
        skip,
        take: pageSize,
      }),
      prisma.medicalVisit.count({
        where: { dogId, ...sensitiveRecordWhere(role, ownerId) },
      }),
    ]);
    const users = await loadDogUserDirectory(
      dogId,
      items.map((item) => item.createdBy),
    );
    ok(res, {
      items: items.map((item) => recordResponse(item, ownerId, role, users)),
      page,
      pageSize,
      total,
    });
  }),
);

appRoutes.post(
  "/dogs/:dogId/medical-visits",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const result = await prisma.$transaction(async (tx) => {
      const visit = await tx.medicalVisit.create({
        data: {
          dogId,
          hospitalName: requireString(req.body.hospitalName, "hospitalName"),
          veterinarianName:
            typeof req.body.veterinarianName === "string"
              ? req.body.veterinarianName
              : undefined,
          visitDate: optionalDate(req.body.visitDate) ?? new Date(),
          visitReason:
            typeof req.body.visitReason === "string"
              ? req.body.visitReason
              : undefined,
          symptoms:
            typeof req.body.symptoms === "string"
              ? req.body.symptoms
              : undefined,
          diagnosis:
            typeof req.body.diagnosis === "string"
              ? req.body.diagnosis
              : undefined,
          treatment:
            typeof req.body.treatment === "string"
              ? req.body.treatment
              : undefined,
          prescribedItems:
            typeof req.body.prescribedItems === "string"
              ? req.body.prescribedItems
              : undefined,
          followUpDate: optionalDate(req.body.followUpDate),
          notes:
            typeof req.body.notes === "string" ? req.body.notes : undefined,
          isSensitive: normalizeSensitiveFlag(req.body),
          createdBy: ownerId,
        },
      });
      let expenseId: bigint | null = null;
      if (req.body.expense?.create === true) {
        const expense = await tx.expense.create({
          data: {
            dogId,
            medicalVisitId: visit.id,
            expenseCategory: "hospital",
            amount: Number(req.body.expense.amount ?? 0),
            expenseDate:
              optionalDate(req.body.expense.expenseDate) ?? new Date(),
            vendorName:
              typeof req.body.expense.vendorName === "string"
                ? req.body.expense.vendorName
                : req.body.hospitalName,
            memo:
              typeof req.body.expense.memo === "string"
                ? req.body.expense.memo
                : undefined,
            isSensitive: visit.isSensitive,
            createdBy: ownerId,
          },
        });
        expenseId = expense.id;
        await writeAuditEvent(tx, {
          dogId,
          actorId: ownerId,
          entityType: "expense",
          entityId: expense.id,
          action: "create",
          summary: expense.vendorName ?? "hospital",
          metadata: { isSensitive: expense.isSensitive },
        });
        await recalculateCostForecasts(tx, dogId);
      }
      await writeAuditEvent(tx, {
        dogId,
        actorId: ownerId,
        entityType: "medical_visit",
        entityId: visit.id,
        action: "create",
        summary: visit.hospitalName,
        metadata: { isSensitive: visit.isSensitive },
      });
      return { id: visit.id, expenseId };
    });
    ok(res, result, 201);
  }),
);

appRoutes.get(
  "/medical-visits/:visitId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    await requireMedicalVisitAccess(ownerId, visitId);
    const visit = await prisma.medicalVisit.findUnique({
      where: { id: visitId },
      include: { attachments: { orderBy: { createdAt: "desc" } } },
    });
    if (!visit) throw new HttpError(404, "NOT_FOUND", "medical visit not found");
    const { role } = await dogAccessContext(ownerId, visit.dogId);
    const users = await loadDogUserDirectory(visit.dogId, [visit.createdBy]);
    ok(res, recordResponse(visit, ownerId, role, users));
  }),
);

appRoutes.get(
  "/medical-visits/:visitId/attachments",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    await requireMedicalVisitAccess(ownerId, visitId);
    const attachments = await prisma.medicalVisitAttachment.findMany({
      where: { medicalVisitId: visitId },
      orderBy: { createdAt: "desc" },
    });
    ok(res, attachments);
  }),
);

appRoutes.post(
  "/medical-visits/:visitId/attachments",
  attachmentUpload.single("file"),
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    await requireMedicalVisitWriteAccess(ownerId, visitId);

    if (!req.file) {
      throw new HttpError(400, "VALIDATION_ERROR", "file is required");
    }

    const fileUrl = `medical-visits/${req.file.filename}`;
    const attachment = await prisma.medicalVisitAttachment.create({
      data: {
        medicalVisitId: visitId,
        fileType: normalizeAttachmentType(req.body.fileType),
        fileUrl,
        originalFilename: req.file.originalname,
        mimeType: req.file.mimetype,
        fileSizeBytes: req.file.size,
        uploadedBy: ownerId,
      },
    });
    ok(res, attachment, 201);
  }),
);

appRoutes.get(
  "/attachments/:attachmentId/download",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const attachmentId = parseId(req.params.attachmentId, "attachmentId");
    const attachment = await requireAttachmentAccess(ownerId, attachmentId);
    const absolutePath = resolveUploadPath(attachment.fileUrl);
    if (!fs.existsSync(absolutePath)) {
      throw new HttpError(404, "NOT_FOUND", "attachment file not found");
    }
    res.download(
      absolutePath,
      attachment.originalFilename ?? path.basename(attachment.fileUrl),
    );
  }),
);

appRoutes.delete(
  "/attachments/:attachmentId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const attachmentId = parseId(req.params.attachmentId, "attachmentId");
    const attachment = await requireAttachmentWriteAccess(ownerId, attachmentId);
    await prisma.medicalVisitAttachment.delete({
      where: { id: attachmentId },
    });
    await deleteAttachmentFile(attachment.fileUrl);
    ok(res, { deleted: true });
  }),
);

appRoutes.patch(
  "/medical-visits/:visitId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    const existing = await requireMedicalVisitWriteAccess(ownerId, visitId);
    const { role } = await dogAccessContext(ownerId, existing.dogId);
    const visit = await prisma.medicalVisit.update({
      where: { id: visitId },
      data: {
        hospitalName:
          typeof req.body.hospitalName === "string"
            ? req.body.hospitalName
            : undefined,
        veterinarianName:
          typeof req.body.veterinarianName === "string"
            ? req.body.veterinarianName
            : undefined,
        visitDate: optionalDate(req.body.visitDate),
        visitReason:
          typeof req.body.visitReason === "string"
            ? req.body.visitReason
            : undefined,
        symptoms:
          typeof req.body.symptoms === "string" ? req.body.symptoms : undefined,
        diagnosis:
          typeof req.body.diagnosis === "string"
            ? req.body.diagnosis
            : undefined,
        treatment:
          typeof req.body.treatment === "string"
            ? req.body.treatment
            : undefined,
        prescribedItems:
          typeof req.body.prescribedItems === "string"
            ? req.body.prescribedItems
            : undefined,
        followUpDate: optionalDate(req.body.followUpDate),
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive:
          req.body.isSensitive === undefined
            ? undefined
            : normalizeSensitiveFlag(req.body),
      },
    });
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "medical_visit",
      entityId: visit.id,
      action: "update",
      summary: visit.hospitalName,
      metadata: { isSensitive: visit.isSensitive },
    });
    const users = await loadDogUserDirectory(existing.dogId, [visit.createdBy]);
    ok(res, recordResponse(visit, ownerId, role, users));
  }),
);

appRoutes.delete(
  "/medical-visits/:visitId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    const existing = await requireMedicalVisitWriteAccess(ownerId, visitId);
    const attachments = await prisma.medicalVisitAttachment.findMany({
      where: { medicalVisitId: visitId },
    });
    await prisma.$transaction(async (tx) => {
      await tx.expense.updateMany({
        where: { medicalVisitId: visitId },
        data: { medicalVisitId: null },
      });
      await tx.medicalVisit.delete({ where: { id: visitId } });
      await recalculateCostForecasts(tx, existing.dogId);
      await writeAuditEvent(tx, {
        dogId: existing.dogId,
        actorId: ownerId,
        entityType: "medical_visit",
        entityId: visitId,
        action: "delete",
        summary: existing.hospitalName,
        metadata: { isSensitive: existing.isSensitive },
      });
    });
    await Promise.all(
      attachments.map((attachment) => deleteAttachmentFile(attachment.fileUrl)),
    );
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/dogs/:dogId/expenses",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const { role } = await dogAccessContext(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const where = {
      dogId,
      ...sensitiveRecordWhere(role, ownerId),
      expenseCategory:
        typeof req.query.category === "string" ? req.query.category : undefined,
      expenseDate: {
        gte:
          typeof req.query.from === "string"
            ? new Date(req.query.from)
            : undefined,
        lte:
          typeof req.query.to === "string" ? new Date(req.query.to) : undefined,
      },
    };
    const [items, total] = await Promise.all([
      prisma.expense.findMany({
        where,
        orderBy: { expenseDate: "desc" },
        skip,
        take: pageSize,
      }),
      prisma.expense.count({ where }),
    ]);
    const users = await loadDogUserDirectory(
      dogId,
      items.map((item) => item.createdBy),
    );
    ok(res, {
      items: items.map((item) => recordResponse(item, ownerId, role, users)),
      page,
      pageSize,
      total,
    });
  }),
);

appRoutes.post(
  "/dogs/:dogId/expenses",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const { role } = await dogAccessContext(ownerId, dogId);
    const expense = await prisma.expense.create({
      data: {
        dogId,
        medicalVisitId: req.body.medicalVisitId
          ? BigInt(req.body.medicalVisitId)
          : undefined,
        expenseCategory: requireString(
          req.body.expenseCategory,
          "expenseCategory",
        ),
        amount: Number(req.body.amount),
        expenseDate: optionalDate(req.body.expenseDate) ?? new Date(),
        vendorName:
          typeof req.body.vendorName === "string"
            ? req.body.vendorName
            : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    await recalculateCostForecasts(prisma, dogId);
    await writeAuditEvent(prisma, {
      dogId,
      actorId: ownerId,
      entityType: "expense",
      entityId: expense.id,
      action: "create",
      summary: expense.vendorName ?? expense.expenseCategory,
      metadata: { isSensitive: expense.isSensitive },
    });
    const users = await loadDogUserDirectory(dogId, [expense.createdBy]);
    ok(res, recordResponse(expense, ownerId, role, users), 201);
  }),
);

appRoutes.get(
  "/dogs/:dogId/expenses/summary",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const { role } = await dogAccessContext(ownerId, dogId);
    const year = Number(req.query.year ?? new Date().getFullYear());
    const month = Number(req.query.month ?? new Date().getMonth() + 1);
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0);
    const expenses = await prisma.expense.findMany({
      where: {
        dogId,
        ...sensitiveRecordWhere(role, ownerId),
        expenseDate: { gte: start, lte: end },
      },
    });
    const byCategory = Object.values(
      expenses.reduce<Record<string, { category: string; amount: number }>>(
        (acc, expense) => {
          acc[expense.expenseCategory] ??= {
            category: expense.expenseCategory,
            amount: 0,
          };
          acc[expense.expenseCategory].amount += Number(expense.amount);
          return acc;
        },
        {},
      ),
    );
    ok(res, {
      totalAmount: byCategory.reduce((sum, item) => sum + item.amount, 0),
      byCategory,
    });
  }),
);

appRoutes.get(
  "/dogs/:dogId/expenses/stats",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const { role } = await dogAccessContext(ownerId, dogId);
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - now.getDay());
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 2, 1);
    const expenses = await prisma.expense.findMany({
      where: { dogId, ...sensitiveRecordWhere(role, ownerId), expenseDate: { gte: threeMonthsAgo } },
    });
    const sumAmount = (exps: typeof expenses) => exps.reduce((s, e) => s + Number(e.amount), 0);
    const todayTotal = sumAmount(expenses.filter((e) => new Date(e.expenseDate) >= todayStart));
    const weekTotal = sumAmount(expenses.filter((e) => new Date(e.expenseDate) >= weekStart));
    const monthExpenses = expenses.filter((e) => new Date(e.expenseDate) >= monthStart);
    const monthTotal = sumAmount(monthExpenses);
    const catMap: Record<string, number> = {};
    for (const e of monthExpenses) {
      catMap[e.expenseCategory] = (catMap[e.expenseCategory] ?? 0) + Number(e.amount);
    }
    const byCategory = Object.entries(catMap)
      .map(([category, amount]) => ({ category, amount, ratio: monthTotal > 0 ? amount / monthTotal : 0 }))
      .sort((a, b) => b.amount - a.amount);
    const monthlyTotals = [];
    for (let i = 2; i >= 0; i--) {
      const ms = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const me = new Date(now.getFullYear(), now.getMonth() - i + 1, 0);
      const mExps = expenses.filter((e) => new Date(e.expenseDate) >= ms && new Date(e.expenseDate) <= me);
      monthlyTotals.push({ year: ms.getFullYear(), month: ms.getMonth() + 1, amount: sumAmount(mExps) });
    }
    ok(res, { today: todayTotal, thisWeek: weekTotal, thisMonth: monthTotal, byCategory, monthlyTotals });
  }),
);

appRoutes.get(
  "/expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expense = await requireExpenseAccess(
      ownerId,
      parseId(req.params.expenseId, "expenseId"),
    );
    const { role } = await dogAccessContext(ownerId, expense.dogId);
    const users = await loadDogUserDirectory(expense.dogId, [
      expense.createdBy,
    ]);
    ok(res, recordResponse(expense, ownerId, role, users));
  }),
);

appRoutes.patch(
  "/expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expenseId = parseId(req.params.expenseId, "expenseId");
    const existing = await requireExpenseWriteAccess(ownerId, expenseId);
    const { role } = await dogAccessContext(ownerId, existing.dogId);
    const expense = await prisma.expense.update({
      where: { id: expenseId },
      data: {
        expenseCategory:
          typeof req.body.expenseCategory === "string"
            ? req.body.expenseCategory
            : undefined,
        amount:
          req.body.amount !== undefined ? Number(req.body.amount) : undefined,
        expenseDate: optionalDate(req.body.expenseDate),
        vendorName:
          typeof req.body.vendorName === "string"
            ? req.body.vendorName
            : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        isSensitive:
          req.body.isSensitive === undefined
            ? undefined
            : normalizeSensitiveFlag(req.body),
      },
    });
    await recalculateCostForecasts(prisma, existing.dogId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "expense",
      entityId: expense.id,
      action: "update",
      summary: expense.vendorName ?? expense.expenseCategory,
      metadata: { isSensitive: expense.isSensitive },
    });
    const users = await loadDogUserDirectory(existing.dogId, [
      expense.createdBy,
    ]);
    ok(res, recordResponse(expense, ownerId, role, users));
  }),
);

appRoutes.delete(
  "/expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expenseId = parseId(req.params.expenseId, "expenseId");
    const existing = await requireExpenseWriteAccess(ownerId, expenseId);
    await prisma.expense.delete({ where: { id: expenseId } });
    await recalculateCostForecasts(prisma, existing.dogId);
    await writeAuditEvent(prisma, {
      dogId: existing.dogId,
      actorId: ownerId,
      entityType: "expense",
      entityId: expenseId,
      action: "delete",
      summary: existing.vendorName ?? existing.expenseCategory,
      metadata: { isSensitive: existing.isSensitive },
    });
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/dogs/:dogId/cost-forecasts/latest",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const forecasts = await latestForecasts(prisma, dogId);
    ok(res, {
      basic: forecastResponse(forecasts.basic),
      caution: forecastResponse(forecasts.caution),
      highRisk: forecastResponse(forecasts.highRisk),
      generatedAt: forecasts.generatedAt,
    });
  }),
);

appRoutes.post(
  "/dogs/:dogId/cost-forecasts/recalculate",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const generatedCount = await recalculateCostForecasts(prisma, dogId);
    ok(res, { generatedCount }, 201);
  }),
);

appRoutes.get(
  "/dogs/:dogId/cost-forecasts/history",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const [items, total] = await Promise.all([
      prisma.costForecast.findMany({
        where: { dogId },
        orderBy: { generatedAt: "desc" },
        skip,
        take: pageSize,
      }),
      prisma.costForecast.count({ where: { dogId } }),
    ]);
    ok(res, { items, page, pageSize, total });
  }),
);

appRoutes.post(
  "/dogs/:dogId/visit-reports",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogWriteAccess(ownerId, dogId);
    const report = await buildVisitReport(prisma, dogId, ownerId);
    ok(res, { id: report.id, title: report.title }, 201);
  }),
);

appRoutes.get(
  "/dogs/:dogId/visit-reports/latest",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const report = await prisma.visitReport.findFirst({
      where: { dogId },
      orderBy: { generatedAt: "desc" },
    });
    ok(
      res,
      visitReportResponse(report),
    );
  }),
);

appRoutes.get(
  "/dogs/:dogId/visit-reports",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const [items, total] = await Promise.all([
      prisma.visitReport.findMany({
        where: { dogId },
        orderBy: { generatedAt: "desc" },
        skip,
        take: pageSize,
      }),
      prisma.visitReport.count({ where: { dogId } }),
    ]);
    ok(res, { items: items.map(visitReportResponse), page, pageSize, total });
  }),
);

appRoutes.get(
  "/visit-reports/:reportId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const reportId = parseId(req.params.reportId, "reportId");
    const report = await prisma.visitReport.findUnique({
      where: { id: reportId },
    });
    if (!report)
      throw new HttpError(404, "NOT_FOUND", "visit report not found");
    await requireDogAccess(ownerId, report.dogId);
    ok(res, visitReportResponse(report));
  }),
);

// ─── Cat helpers ────────────────────────────────────────────────────────────

async function requireCatAccess(ownerId: bigint, catId: bigint) {
  const cat = await prisma.cat.findFirst({
    where: {
      id: catId,
      OR: [
        { primaryOwnerId: ownerId },
        { memberships: { some: { userId: ownerId, status: "active" } } },
      ],
    },
  });
  if (!cat) throw new HttpError(404, "NOT_FOUND", "cat not found");
  return cat;
}

async function requireCatOwnerAccess(ownerId: bigint, catId: bigint) {
  const cat = await prisma.cat.findFirst({
    where: {
      id: catId,
      OR: [
        { primaryOwnerId: ownerId },
        { memberships: { some: { userId: ownerId, role: "owner", status: "active" } } },
      ],
    },
  });
  if (!cat) throw new HttpError(404, "NOT_FOUND", "cat not found");
  return cat;
}

async function requireCatWriteAccess(uid: bigint, catId: bigint) {
  const cat = await prisma.cat.findFirst({
    where: {
      id: catId,
      OR: [
        { primaryOwnerId: uid },
        { memberships: { some: { userId: uid, status: "active", role: { in: ["owner", "editor"] } } } },
      ],
    },
  });
  if (!cat) throw new HttpError(404, "NOT_FOUND", "cat not found");
  return cat;
}

async function catAccessRole(uid: bigint, cat: { id: bigint; primaryOwnerId: bigint }) {
  if (cat.primaryOwnerId === uid) return "owner";
  const membership = await prisma.catMembership.findFirst({
    where: { catId: cat.id, userId: uid, status: "active" },
    select: { role: true },
  });
  return (membership?.role as AccessRole | undefined) ?? null;
}

async function catAccessContext(viewerId: bigint, catId: bigint) {
  const cat = await requireCatAccess(viewerId, catId);
  const role = await catAccessRole(viewerId, cat);
  return { cat, role };
}

async function loadCatUserDirectory(catId: bigint, extraUserIds: Array<bigint | null | undefined> = []) {
  const memberships = await prisma.catMembership.findMany({
    where: { catId, status: "active" },
    include: { user: { select: userSummarySelect } },
  });
  const directory = buildUserDirectory(memberships.map((m) => m.user));
  const missingUserIds = extraUserIds
    .filter((id): id is bigint => id !== null && id !== undefined)
    .filter((id) => !directory.has(id.toString()));
  if (missingUserIds.length > 0) {
    const users = await prisma.user.findMany({
      where: { id: { in: missingUserIds } },
      select: userSummarySelect,
    });
    for (const user of users) {
      directory.set(user.id.toString(), user);
    }
  }
  return directory;
}

async function parseAssignableUserIdForCat(value: unknown, catId: bigint, label = "assignedToUserId") {
  if (value === undefined) return undefined;
  if (value === null || value === "") return null;
  const assignedTo = parseId(String(value), label);
  const hasAccess = await prisma.cat.findFirst({
    where: {
      id: catId,
      OR: [
        { primaryOwnerId: assignedTo },
        { memberships: { some: { userId: assignedTo, status: "active" } } },
      ],
    },
    select: { id: true },
  });
  if (!hasAccess) {
    throw new HttpError(400, "VALIDATION_ERROR", "assigned user must be an active family member");
  }
  return assignedTo;
}

async function requireCatMembershipOwnerAccess(ownerId: bigint, membershipId: bigint) {
  const membership = await prisma.catMembership.findUnique({ where: { id: membershipId } });
  if (!membership) throw new HttpError(404, "NOT_FOUND", "membership not found");
  await requireCatOwnerAccess(ownerId, membership.catId);
  return membership;
}

async function requireCatScheduleAccess(ownerId: bigint, scheduleId: bigint) {
  const schedule = await prisma.catCareSchedule.findUnique({ where: { id: scheduleId } });
  if (!schedule) throw new HttpError(404, "NOT_FOUND", "schedule not found");
  await requireCatAccess(ownerId, schedule.catId);
  return schedule;
}

async function requireCatScheduleWriteAccess(ownerId: bigint, scheduleId: bigint) {
  const schedule = await prisma.catCareSchedule.findUnique({ where: { id: scheduleId } });
  if (!schedule) throw new HttpError(404, "NOT_FOUND", "schedule not found");
  await requireCatWriteAccess(ownerId, schedule.catId);
  return schedule;
}

async function requireCatConditionWriteAccess(ownerId: bigint, conditionId: bigint) {
  const condition = await prisma.catCondition.findUnique({ where: { id: conditionId } });
  if (!condition) throw new HttpError(404, "NOT_FOUND", "condition not found");
  await requireCatWriteAccess(ownerId, condition.catId);
  return condition;
}

async function requireCatMedicationWriteAccess(ownerId: bigint, medicationId: bigint) {
  const medication = await prisma.catMedication.findUnique({ where: { id: medicationId } });
  if (!medication) throw new HttpError(404, "NOT_FOUND", "medication not found");
  await requireCatWriteAccess(ownerId, medication.catId);
  return medication;
}

async function requireCatHealthLogAccess(ownerId: bigint, logId: bigint) {
  const log = await prisma.catHealthLog.findUnique({ where: { id: logId } });
  if (!log) throw new HttpError(404, "NOT_FOUND", "health log not found");
  const { role } = await catAccessContext(ownerId, log.catId);
  if (!canViewSensitiveRecord({ accessRole: role, viewerId: ownerId, createdBy: log.createdBy, isSensitive: log.isSensitive })) {
    throw new HttpError(404, "NOT_FOUND", "health log not found");
  }
  return log;
}

async function requireCatHealthLogWriteAccess(ownerId: bigint, logId: bigint) {
  const log = await prisma.catHealthLog.findUnique({ where: { id: logId } });
  if (!log) throw new HttpError(404, "NOT_FOUND", "health log not found");
  await requireCatWriteAccess(ownerId, log.catId);
  return log;
}

async function requireCatMedicalVisitAccess(ownerId: bigint, visitId: bigint) {
  const visit = await prisma.catMedicalVisit.findUnique({ where: { id: visitId } });
  if (!visit) throw new HttpError(404, "NOT_FOUND", "medical visit not found");
  const { role } = await catAccessContext(ownerId, visit.catId);
  if (!canViewSensitiveRecord({ accessRole: role, viewerId: ownerId, createdBy: visit.createdBy, isSensitive: visit.isSensitive })) {
    throw new HttpError(404, "NOT_FOUND", "medical visit not found");
  }
  return visit;
}

async function requireCatMedicalVisitWriteAccess(ownerId: bigint, visitId: bigint) {
  const visit = await prisma.catMedicalVisit.findUnique({ where: { id: visitId } });
  if (!visit) throw new HttpError(404, "NOT_FOUND", "medical visit not found");
  await requireCatWriteAccess(ownerId, visit.catId);
  return visit;
}

async function requireCatAttachmentAccess(ownerId: bigint, attachmentId: bigint) {
  const attachment = await prisma.catMedicalVisitAttachment.findUnique({
    where: { id: attachmentId },
    include: { medicalVisit: { select: { catId: true } } },
  });
  if (!attachment) throw new HttpError(404, "NOT_FOUND", "attachment not found");
  await requireCatAccess(ownerId, attachment.medicalVisit.catId);
  return attachment;
}

async function requireCatAttachmentWriteAccess(ownerId: bigint, attachmentId: bigint) {
  const attachment = await prisma.catMedicalVisitAttachment.findUnique({
    where: { id: attachmentId },
    include: { medicalVisit: { select: { catId: true } } },
  });
  if (!attachment) throw new HttpError(404, "NOT_FOUND", "attachment not found");
  await requireCatWriteAccess(ownerId, attachment.medicalVisit.catId);
  return attachment;
}

async function requireCatExpenseAccess(ownerId: bigint, expenseId: bigint) {
  const expense = await prisma.catExpense.findUnique({ where: { id: expenseId } });
  if (!expense) throw new HttpError(404, "NOT_FOUND", "expense not found");
  const { role } = await catAccessContext(ownerId, expense.catId);
  if (!canViewSensitiveRecord({ accessRole: role, viewerId: ownerId, createdBy: expense.createdBy, isSensitive: expense.isSensitive })) {
    throw new HttpError(404, "NOT_FOUND", "expense not found");
  }
  return expense;
}

async function requireCatExpenseWriteAccess(ownerId: bigint, expenseId: bigint) {
  const expense = await prisma.catExpense.findUnique({ where: { id: expenseId } });
  if (!expense) throw new HttpError(404, "NOT_FOUND", "expense not found");
  await requireCatWriteAccess(ownerId, expense.catId);
  return expense;
}

async function createNextRecurringCatSchedule(
  schedule: Awaited<ReturnType<typeof requireCatScheduleAccess>>,
  createdBy: bigint,
) {
  if (!schedule.repeatCycleDays) return null;
  return prisma.catCareSchedule.create({
    data: {
      catId: schedule.catId,
      scheduleType: schedule.scheduleType,
      title: schedule.title,
      description: schedule.description,
      dueDate: addDays(schedule.dueDate, schedule.repeatCycleDays),
      repeatCycleDays: schedule.repeatCycleDays,
      priority: schedule.priority,
      sourceType: schedule.sourceType,
      reminderEnabled: schedule.reminderEnabled,
      createdBy,
      assignedTo: schedule.assignedTo,
    },
  });
}

function catVisitReportResponse(
  report: Awaited<ReturnType<typeof prisma.catVisitReport.findFirst>>,
) {
  if (!report) return null;
  const summary = jsonRecord(report.summaryJson);
  const sharePath = `/cat-visit-reports/${report.id}`;
  const summaryShare = jsonRecord(summary?.share);
  return {
    ...report,
    summary,
    notice: visitReportNotice,
    share: {
      ...(summaryShare ?? {}),
      sharePath,
      pdfUrl: report.pdfUrl ?? summaryShare?.pdfUrl ?? null,
      pdfStatus: report.pdfUrl ? "ready" : (summaryShare?.pdfStatus ?? "not_generated"),
    },
  };
}

// ─── Cat endpoints ───────────────────────────────────────────────────────────

appRoutes.post(
  "/onboarding/cats",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catInput = req.body.cat ?? {};
    const baseDate = optionalDate(req.body.baseDate) ?? new Date();

    const result = await prisma.$transaction(async (tx) => {
      const cat = await tx.cat.create({
        data: {
          primaryOwnerId: ownerId,
          name: requireString(catInput.name, "name"),
          breed: requireString(catInput.breed, "breed"),
          birthDate: optionalDate(catInput.birthDate),
          sex: requireString(catInput.sex, "sex"),
          neutered: Boolean(catInput.neutered),
          currentWeightKg: optionalNumber(catInput.currentWeightKg),
          targetWeightKg: optionalNumber(catInput.targetWeightKg),
          activityLevel: typeof catInput.activityLevel === "string" ? catInput.activityLevel : "medium",
          insuranceStatus: typeof catInput.insuranceStatus === "string" ? catInput.insuranceStatus : "none",
          notes: typeof catInput.notes === "string" ? catInput.notes : undefined,
        },
      });
      await tx.catMembership.create({
        data: {
          catId: cat.id,
          userId: ownerId,
          role: "owner",
          status: "active",
          invitedBy: ownerId,
          joinedAt: new Date(),
        },
      });

      for (const condition of Array.isArray(req.body.conditions) ? req.body.conditions : []) {
        await tx.catCondition.create({
          data: {
            catId: cat.id,
            conditionType: requireString(condition.conditionType, "conditionType"),
            conditionName: requireString(condition.conditionName, "conditionName"),
            severity: typeof condition.severity === "string" ? condition.severity : undefined,
            diagnosedOn: optionalDate(condition.diagnosedOn),
            status: typeof condition.status === "string" ? condition.status : "active",
            notes: typeof condition.notes === "string" ? condition.notes : undefined,
          },
        });
      }

      for (const medication of Array.isArray(req.body.medications) ? req.body.medications : []) {
        await tx.catMedication.create({
          data: {
            catId: cat.id,
            medicationName: requireString(medication.medicationName, "medicationName"),
            dosage: typeof medication.dosage === "string" ? medication.dosage : undefined,
            frequencyText: typeof medication.frequencyText === "string" ? medication.frequencyText : undefined,
            startedOn: optionalDate(medication.startedOn),
            endedOn: optionalDate(medication.endedOn),
            prescribedBy: typeof medication.prescribedBy === "string" ? medication.prescribedBy : undefined,
            isActive: medication.isActive !== false,
            notes: typeof medication.notes === "string" ? medication.notes : undefined,
          },
        });
      }

      const generatedScheduleCount = await generateDefaultCatCareSchedules(tx, cat.id, baseDate, ownerId);
      await recalculateCatCostForecasts(tx, cat.id);
      const forecasts = await latestCatForecasts(tx, cat.id);
      return { cat, generatedScheduleCount, forecasts };
    });

    ok(res, {
      catId: result.cat.id,
      generatedScheduleCount: result.generatedScheduleCount,
      forecastSummary: {
        monthlyEstimate: result.forecasts.basic?.monthlyEstimate ?? null,
        yearlyEstimate: result.forecasts.basic?.yearlyEstimate ?? null,
      },
    }, 201);
  }),
);

appRoutes.post(
  "/cats",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const cat = await prisma.$transaction(async (tx) => {
      const created = await tx.cat.create({
        data: {
          primaryOwnerId: ownerId,
          name: requireString(req.body.name, "name"),
          breed: requireString(req.body.breed, "breed"),
          birthDate: optionalDate(req.body.birthDate),
          sex: requireString(req.body.sex, "sex"),
          neutered: Boolean(req.body.neutered),
          currentWeightKg: optionalNumber(req.body.currentWeightKg),
          targetWeightKg: optionalNumber(req.body.targetWeightKg),
          activityLevel: typeof req.body.activityLevel === "string" ? req.body.activityLevel : "medium",
          insuranceStatus: typeof req.body.insuranceStatus === "string" ? req.body.insuranceStatus : "none",
          notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        },
        select: { id: true, name: true },
      });
      await tx.catMembership.create({
        data: {
          catId: created.id,
          userId: ownerId,
          role: "owner",
          status: "active",
          invitedBy: ownerId,
          joinedAt: new Date(),
        },
      });
      return created;
    });
    ok(res, cat, 201);
  }),
);

appRoutes.get(
  "/cats",
  asyncHandler(async (req, res) => {
    const requesterId = userId(req as AuthedRequest);
    const cats = await prisma.cat.findMany({
      where: {
        OR: [
          { primaryOwnerId: requesterId },
          { memberships: { some: { userId: requesterId, status: "active" } } },
        ],
      },
      orderBy: { createdAt: "desc" },
    });
    ok(res, cats);
  }),
);

appRoutes.get(
  "/cats/:catId",
  asyncHandler(async (req, res) => {
    ok(res, await requireCatAccess(userId(req as AuthedRequest), parseId(req.params.catId, "catId")));
  }),
);

appRoutes.patch(
  "/cats/:catId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatOwnerAccess(ownerId, catId);
    const cat = await prisma.cat.update({
      where: { id: catId },
      data: {
        name: typeof req.body.name === "string" ? req.body.name : undefined,
        breed: typeof req.body.breed === "string" ? req.body.breed : undefined,
        birthDate: optionalDate(req.body.birthDate),
        sex: typeof req.body.sex === "string" ? req.body.sex : undefined,
        neutered: typeof req.body.neutered === "boolean" ? req.body.neutered : undefined,
        currentWeightKg: optionalNumber(req.body.currentWeightKg),
        targetWeightKg: optionalNumber(req.body.targetWeightKg),
        activityLevel: typeof req.body.activityLevel === "string" ? req.body.activityLevel : undefined,
        insuranceStatus: typeof req.body.insuranceStatus === "string" ? req.body.insuranceStatus : undefined,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
      },
    });
    await recalculateCatCostForecasts(prisma, catId);
    ok(res, cat);
  }),
);

appRoutes.get(
  "/cats/:catId/delete-preview",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const cat = await requireCatOwnerAccess(ownerId, catId);

    const [schedules, conditions, medications, healthLogs, medicalVisits, expenses, forecasts, visitReports, attachments] =
      await Promise.all([
        prisma.catCareSchedule.count({ where: { catId } }),
        prisma.catCondition.count({ where: { catId } }),
        prisma.catMedication.count({ where: { catId } }),
        prisma.catHealthLog.count({ where: { catId } }),
        prisma.catMedicalVisit.count({ where: { catId } }),
        prisma.catExpense.count({ where: { catId } }),
        prisma.catCostForecast.count({ where: { catId } }),
        prisma.catVisitReport.count({ where: { catId } }),
        prisma.catMedicalVisitAttachment.aggregate({
          where: { medicalVisit: { catId } },
          _count: { _all: true },
          _sum: { fileSizeBytes: true },
        }),
      ]);

    ok(res, {
      cat: { id: cat.id, name: cat.name },
      scope: "pet",
      accessPolicy: "primary_owner_only",
      counts: { schedules, conditions, medications, healthLogs, medicalVisits, expenses, forecasts, visitReports, attachments: attachments._count._all },
      attachmentBytes: attachments._sum.fileSizeBytes ?? 0,
    });
  }),
);

appRoutes.delete(
  "/cats/:catId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatOwnerAccess(ownerId, catId);

    const attachments = await prisma.catMedicalVisitAttachment.findMany({
      where: { medicalVisit: { catId } },
      select: { fileUrl: true },
    });

    await prisma.cat.delete({ where: { id: catId } });
    await Promise.all(attachments.map((a) => deleteAttachmentFile(a.fileUrl)));

    ok(res, { deleted: true, scope: "pet", accessPolicy: "primary_owner_only" });
  }),
);

appRoutes.get(
  "/cats/:catId/members",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatAccess(ownerId, catId);

    const memberships = await prisma.catMembership.findMany({
      where: { catId, status: "active" },
      orderBy: [{ role: "asc" }, { createdAt: "asc" }],
      include: { user: { select: { id: true, email: true, name: true } } },
    });

    ok(res, memberships.map((m) => ({ id: m.id, catId: m.catId, userId: m.userId, role: m.role, status: m.status, joinedAt: m.joinedAt, createdAt: m.createdAt, user: m.user })));
  }),
);

appRoutes.post(
  "/cats/:catId/members",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatOwnerAccess(ownerId, catId);

    const email = requireString(req.body.email, "email").toLowerCase();
    const role = normalizeMembershipRole(req.body.role ?? "viewer");
    const member = await prisma.user.findUnique({ where: { email }, select: { id: true, email: true, name: true } });
    if (!member) throw new HttpError(404, "NOT_FOUND", "user not found");

    const membership = await prisma.catMembership.upsert({
      where: { catId_userId: { catId, userId: member.id } },
      create: { catId, userId: member.id, role, status: "active", invitedBy: ownerId, joinedAt: new Date() },
      update: { role, status: "active", invitedBy: ownerId, joinedAt: new Date() },
      include: { user: { select: { id: true, email: true, name: true } } },
    });

    ok(res, { id: membership.id, catId: membership.catId, userId: membership.userId, role: membership.role, status: membership.status, joinedAt: membership.joinedAt, user: membership.user }, 201);
  }),
);

appRoutes.patch(
  "/cat-memberships/:membershipId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const membershipId = parseId(req.params.membershipId, "membershipId");
    const existing = await requireCatMembershipOwnerAccess(ownerId, membershipId);
    const role = req.body.role === undefined ? existing.role : normalizeMembershipRole(req.body.role);
    const status = typeof req.body.status === "string" ? req.body.status : existing.status;

    if (status !== "active" && status !== "removed") {
      throw new HttpError(400, "VALIDATION_ERROR", "status must be active or removed");
    }
    if (existing.userId === ownerId && (role !== "owner" || status !== "active")) {
      throw new HttpError(400, "VALIDATION_ERROR", "cannot demote or remove your own owner membership");
    }

    const membership = await prisma.catMembership.update({
      where: { id: membershipId },
      data: { role, status },
      include: { user: { select: { id: true, email: true, name: true } } },
    });

    ok(res, { id: membership.id, catId: membership.catId, userId: membership.userId, role: membership.role, status: membership.status, joinedAt: membership.joinedAt, user: membership.user });
  }),
);

appRoutes.delete(
  "/cat-memberships/:membershipId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const membershipId = parseId(req.params.membershipId, "membershipId");
    const existing = await requireCatMembershipOwnerAccess(ownerId, membershipId);

    if (existing.userId === ownerId) {
      throw new HttpError(400, "VALIDATION_ERROR", "cannot remove your own owner membership");
    }

    await prisma.catMembership.update({ where: { id: membershipId }, data: { status: "removed" } });
    ok(res, { removed: true });
  }),
);

appRoutes.get(
  "/cats/:catId/dashboard",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { cat, role } = await catAccessContext(ownerId, catId);
    const recordVisibility = sensitiveRecordWhere(role, ownerId);
    const canEditRecords = role === "owner" || role === "editor";
    const today = new Date();
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);

    const [todaySchedules, recentHealthLogs, expenses, forecasts, members, hiddenConditions, hiddenMedications, hiddenHealthLogs, hiddenMedicalVisits, hiddenExpenses] =
      await Promise.all([
        prisma.catCareSchedule.findMany({
          where: { catId, status: "pending", dueDate: { gte: addDays(new Date(today.toISOString().slice(0, 10)), -30), lte: monthEnd } },
          orderBy: { dueDate: "asc" },
          take: 5,
        }),
        prisma.catHealthLog.findMany({ where: { catId, ...recordVisibility }, orderBy: { recordedAt: "desc" }, take: 5 }),
        prisma.catExpense.findMany({ where: { catId, ...recordVisibility, expenseDate: { gte: monthStart, lte: monthEnd } } }),
        latestCatForecasts(prisma, catId),
        prisma.catMembership.findMany({ where: { catId, status: "active" }, orderBy: [{ role: "asc" }, { createdAt: "asc" }], include: { user: { select: userSummarySelect } } }),
        canEditRecords ? Promise.resolve(0) : prisma.catCondition.count({ where: { catId, isSensitive: true, NOT: { createdBy: ownerId } } }),
        canEditRecords ? Promise.resolve(0) : prisma.catMedication.count({ where: { catId, isSensitive: true, NOT: { createdBy: ownerId } } }),
        canEditRecords ? Promise.resolve(0) : prisma.catHealthLog.count({ where: { catId, isSensitive: true, NOT: { createdBy: ownerId } } }),
        canEditRecords ? Promise.resolve(0) : prisma.catMedicalVisit.count({ where: { catId, isSensitive: true, NOT: { createdBy: ownerId } } }),
        canEditRecords ? Promise.resolve(0) : prisma.catExpense.count({ where: { catId, isSensitive: true, NOT: { createdBy: ownerId } } }),
      ]);

    const userDirectory = buildUserDirectory(members.map((m) => m.user));
    const byCategory = Object.values(
      expenses.reduce<Record<string, { category: string; amount: number }>>((acc, e) => {
        acc[e.expenseCategory] ??= { category: e.expenseCategory, amount: 0 };
        acc[e.expenseCategory].amount += Number(e.amount);
        return acc;
      }, {}),
    );

    ok(res, {
      cat: { id: cat.id, name: cat.name, breed: cat.breed, birthDate: cat.birthDate, sex: cat.sex, neutered: cat.neutered, currentWeightKg: cat.currentWeightKg, targetWeightKg: cat.targetWeightKg, activityLevel: cat.activityLevel, insuranceStatus: cat.insuranceStatus, notes: cat.notes },
      todaySchedules: todaySchedules.map((s) => careScheduleResponse(s as Parameters<typeof careScheduleResponse>[0], ownerId, role, userDirectory)),
      recentHealthLogs: recentHealthLogs.map((log) => recordResponse(log, ownerId, role, userDirectory)),
      monthlyExpenseSummary: { totalAmount: byCategory.reduce((sum, item) => sum + item.amount, 0), byCategory },
      latestForecast: forecasts.basic ? { monthlyEstimate: forecasts.basic.monthlyEstimate, yearlyEstimate: forecasts.basic.yearlyEstimate } : null,
      access: { userId: ownerId, role, canManage: role === "owner", canEditRecords, canViewSensitive: canEditRecords },
      collaboration: {
        members: members.map((m) => ({ id: m.id, catId: m.catId, userId: m.userId, role: m.role, status: m.status, joinedAt: m.joinedAt, user: m.user })),
        hiddenSensitiveCounts: { conditions: hiddenConditions, medications: hiddenMedications, healthLogs: hiddenHealthLogs, medicalVisits: hiddenMedicalVisits, expenses: hiddenExpenses, total: hiddenConditions + hiddenMedications + hiddenHealthLogs + hiddenMedicalVisits + hiddenExpenses },
      },
    });
  }),
);

appRoutes.get(
  "/cats/:catId/conditions",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { role } = await catAccessContext(ownerId, catId);
    const conditions = await prisma.catCondition.findMany({
      where: { catId, ...sensitiveRecordWhere(role, ownerId), status: typeof req.query.status === "string" ? req.query.status : undefined },
      orderBy: [{ status: "asc" }, { updatedAt: "desc" }],
    });
    const users = await loadCatUserDirectory(catId, conditions.map((c) => c.createdBy));
    ok(res, conditions.map((c) => recordResponse(c, ownerId, role, users)));
  }),
);

appRoutes.post(
  "/cats/:catId/conditions",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const condition = await prisma.catCondition.create({
      data: {
        catId,
        conditionType: requireString(req.body.conditionType, "conditionType"),
        conditionName: requireString(req.body.conditionName, "conditionName"),
        severity: typeof req.body.severity === "string" ? req.body.severity : undefined,
        diagnosedOn: optionalDate(req.body.diagnosedOn),
        status: typeof req.body.status === "string" ? req.body.status : "active",
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    await recalculateCatCostForecasts(prisma, catId);
    ok(res, condition, 201);
  }),
);

appRoutes.patch(
  "/cat-conditions/:conditionId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const conditionId = parseId(req.params.conditionId, "conditionId");
    const existing = await requireCatConditionWriteAccess(ownerId, conditionId);
    const condition = await prisma.catCondition.update({
      where: { id: conditionId },
      data: {
        conditionType: typeof req.body.conditionType === "string" ? req.body.conditionType : undefined,
        conditionName: typeof req.body.conditionName === "string" ? req.body.conditionName : undefined,
        severity: typeof req.body.severity === "string" ? req.body.severity : undefined,
        diagnosedOn: patchOptionalDate(req.body, "diagnosedOn"),
        status: typeof req.body.status === "string" ? req.body.status : undefined,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive: req.body.isSensitive === undefined ? undefined : normalizeSensitiveFlag(req.body),
      },
    });
    await recalculateCatCostForecasts(prisma, existing.catId);
    ok(res, condition);
  }),
);

appRoutes.delete(
  "/cat-conditions/:conditionId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const conditionId = parseId(req.params.conditionId, "conditionId");
    const existing = await requireCatConditionWriteAccess(ownerId, conditionId);
    await prisma.catCondition.delete({ where: { id: conditionId } });
    await recalculateCatCostForecasts(prisma, existing.catId);
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/cats/:catId/medications",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { role } = await catAccessContext(ownerId, catId);
    const onlyActive = req.query.active === "true";
    const medications = await prisma.catMedication.findMany({
      where: { catId, ...sensitiveRecordWhere(role, ownerId), isActive: onlyActive ? true : undefined },
      orderBy: [{ isActive: "desc" }, { updatedAt: "desc" }],
    });
    const users = await loadCatUserDirectory(catId, medications.map((m) => m.createdBy));
    ok(res, medications.map((m) => recordResponse(m, ownerId, role, users)));
  }),
);

appRoutes.post(
  "/cats/:catId/medications",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const medication = await prisma.catMedication.create({
      data: {
        catId,
        medicationName: requireString(req.body.medicationName, "medicationName"),
        dosage: typeof req.body.dosage === "string" ? req.body.dosage : undefined,
        frequencyText: typeof req.body.frequencyText === "string" ? req.body.frequencyText : undefined,
        startedOn: patchOptionalDate(req.body, "startedOn"),
        endedOn: patchOptionalDate(req.body, "endedOn"),
        prescribedBy: typeof req.body.prescribedBy === "string" ? req.body.prescribedBy : undefined,
        isActive: req.body.isActive !== false,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    await recalculateCatCostForecasts(prisma, catId);
    ok(res, medication, 201);
  }),
);

appRoutes.patch(
  "/cat-medications/:medicationId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const medicationId = parseId(req.params.medicationId, "medicationId");
    const existing = await requireCatMedicationWriteAccess(ownerId, medicationId);
    const medication = await prisma.catMedication.update({
      where: { id: medicationId },
      data: {
        medicationName: typeof req.body.medicationName === "string" ? req.body.medicationName : undefined,
        dosage: typeof req.body.dosage === "string" ? req.body.dosage : undefined,
        frequencyText: typeof req.body.frequencyText === "string" ? req.body.frequencyText : undefined,
        startedOn: optionalDate(req.body.startedOn),
        endedOn: optionalDate(req.body.endedOn),
        prescribedBy: typeof req.body.prescribedBy === "string" ? req.body.prescribedBy : undefined,
        isActive: typeof req.body.isActive === "boolean" ? req.body.isActive : undefined,
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive: req.body.isSensitive === undefined ? undefined : normalizeSensitiveFlag(req.body),
      },
    });
    await recalculateCatCostForecasts(prisma, existing.catId);
    ok(res, medication);
  }),
);

appRoutes.delete(
  "/cat-medications/:medicationId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const medicationId = parseId(req.params.medicationId, "medicationId");
    const existing = await requireCatMedicationWriteAccess(ownerId, medicationId);
    await prisma.catMedication.delete({ where: { id: medicationId } });
    await recalculateCatCostForecasts(prisma, existing.catId);
    ok(res, { deleted: true });
  }),
);

appRoutes.post(
  "/cats/:catId/care-schedules/generate",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const generatedCount = await generateDefaultCatCareSchedules(
      prisma,
      catId,
      optionalDate(req.body.baseDate) ?? new Date(),
      ownerId,
    );
    ok(res, { generatedCount }, 201);
  }),
);

appRoutes.get(
  "/cats/:catId/care-schedules",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { role } = await catAccessContext(ownerId, catId);
    const schedules = await prisma.catCareSchedule.findMany({
      where: {
        catId,
        status: typeof req.query.status === "string" ? req.query.status : undefined,
        dueDate: {
          gte: typeof req.query.from === "string" ? new Date(req.query.from) : undefined,
          lte: typeof req.query.to === "string" ? new Date(req.query.to) : undefined,
        },
      },
      orderBy: { dueDate: "asc" },
    });
    const users = await loadCatUserDirectory(catId, schedules.flatMap((s) => [s.createdBy, s.assignedTo]));
    ok(res, schedules.map((s) => careScheduleResponse(s as Parameters<typeof careScheduleResponse>[0], ownerId, role, users)));
  }),
);

appRoutes.post(
  "/cats/:catId/care-schedules",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const { role } = await catAccessContext(ownerId, catId);
    const assignedTo = await parseAssignableUserIdForCat(req.body.assignedToUserId ?? req.body.assignedTo, catId);
    const schedule = await prisma.catCareSchedule.create({
      data: {
        catId,
        scheduleType: requireString(req.body.scheduleType, "scheduleType"),
        title: requireString(req.body.title, "title"),
        description: typeof req.body.description === "string" ? req.body.description : undefined,
        dueDate: optionalDate(req.body.dueDate) ?? new Date(),
        repeatCycleDays: typeof req.body.repeatCycleDays === "number" ? req.body.repeatCycleDays : undefined,
        priority: typeof req.body.priority === "string" ? req.body.priority : "medium",
        sourceType: typeof req.body.sourceType === "string" ? req.body.sourceType : "manual",
        createdBy: ownerId,
        assignedTo: assignedTo === undefined ? ownerId : assignedTo,
      },
    });
    const users = await loadCatUserDirectory(catId, [schedule.createdBy, schedule.assignedTo]);
    ok(res, careScheduleResponse(schedule as Parameters<typeof careScheduleResponse>[0], ownerId, role, users), 201);
  }),
);

appRoutes.get(
  "/cat-care-schedules/:scheduleId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const schedule = await requireCatScheduleAccess(ownerId, scheduleId);
    const { role } = await catAccessContext(ownerId, schedule.catId);
    const users = await loadCatUserDirectory(schedule.catId, [schedule.createdBy, schedule.assignedTo]);
    ok(res, careScheduleResponse(schedule as Parameters<typeof careScheduleResponse>[0], ownerId, role, users));
  }),
);

appRoutes.patch(
  "/cat-care-schedules/:scheduleId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireCatScheduleWriteAccess(ownerId, scheduleId);
    const { role } = await catAccessContext(ownerId, existing.catId);
    const assignedTo = await parseAssignableUserIdForCat(req.body.assignedToUserId ?? req.body.assignedTo, existing.catId);
    const schedule = await prisma.catCareSchedule.update({
      where: { id: scheduleId },
      data: {
        title: typeof req.body.title === "string" ? req.body.title : undefined,
        description: typeof req.body.description === "string" ? req.body.description : undefined,
        dueDate: optionalDate(req.body.dueDate),
        scheduleType: typeof req.body.scheduleType === "string" ? req.body.scheduleType : undefined,
        repeatCycleDays: req.body.repeatCycleDays === null ? null : typeof req.body.repeatCycleDays === "number" ? req.body.repeatCycleDays : undefined,
        priority: typeof req.body.priority === "string" ? req.body.priority : undefined,
        reminderEnabled: typeof req.body.reminderEnabled === "boolean" ? req.body.reminderEnabled : undefined,
        assignedTo,
      },
    });
    const users = await loadCatUserDirectory(existing.catId, [schedule.createdBy, schedule.assignedTo]);
    ok(res, careScheduleResponse(schedule as Parameters<typeof careScheduleResponse>[0], ownerId, role, users));
  }),
);

appRoutes.post(
  "/cat-care-schedules/:scheduleId/complete",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireCatScheduleWriteAccess(ownerId, scheduleId);
    const { role } = await catAccessContext(ownerId, existing.catId);
    if (existing.status !== "pending") {
      const users = await loadCatUserDirectory(existing.catId, [existing.createdBy, existing.assignedTo]);
      ok(res, careScheduleResponse(existing as Parameters<typeof careScheduleResponse>[0], ownerId, role, users));
      return;
    }
    const completedAt = optionalDate(req.body.completedAt) ?? new Date();
    const schedule = await prisma.catCareSchedule.update({ where: { id: scheduleId }, data: { status: "completed", completedAt } });
    await createNextRecurringCatSchedule(existing, ownerId);
    const users = await loadCatUserDirectory(existing.catId, [schedule.createdBy, schedule.assignedTo]);
    ok(res, careScheduleResponse(schedule as Parameters<typeof careScheduleResponse>[0], ownerId, role, users));
  }),
);

appRoutes.post(
  "/cat-care-schedules/:scheduleId/skip",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireCatScheduleWriteAccess(ownerId, scheduleId);
    const { role } = await catAccessContext(ownerId, existing.catId);
    if (existing.status !== "pending") {
      const users = await loadCatUserDirectory(existing.catId, [existing.createdBy, existing.assignedTo]);
      ok(res, careScheduleResponse(existing as Parameters<typeof careScheduleResponse>[0], ownerId, role, users));
      return;
    }
    const schedule = await prisma.catCareSchedule.update({ where: { id: scheduleId }, data: { status: "skipped" } });
    await createNextRecurringCatSchedule(existing, ownerId);
    const users = await loadCatUserDirectory(existing.catId, [schedule.createdBy, schedule.assignedTo]);
    ok(res, careScheduleResponse(schedule as Parameters<typeof careScheduleResponse>[0], ownerId, role, users));
  }),
);

appRoutes.get(
  "/cats/:catId/timeline",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { role } = await catAccessContext(ownerId, catId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const type = timelineType(req.query.type);
    const from = optionalDate(req.query.from);
    const to = optionalDate(req.query.to);
    const take = skip + pageSize;
    const dateFilter = { ...(from ? { gte: from } : {}), ...(to ? { lte: to } : {}) };
    const recordVisibility = sensitiveRecordWhere(role, ownerId);
    const healthWhere = { catId, ...recordVisibility, recordedAt: dateFilter };
    const visitWhere = { catId, ...recordVisibility, visitDate: dateFilter };
    const expenseWhere = { catId, ...recordVisibility, expenseDate: dateFilter };

    const [logs, visits, expenses, healthTotal, visitTotal, expenseTotal] = await Promise.all([
      type === "all" || type === "health_log" ? prisma.catHealthLog.findMany({ where: healthWhere, orderBy: { recordedAt: "desc" }, take }) : [],
      type === "all" || type === "medical_visit" ? prisma.catMedicalVisit.findMany({ where: visitWhere, orderBy: { visitDate: "desc" }, include: { _count: { select: { attachments: true } } }, take }) : [],
      type === "all" || type === "expense" ? prisma.catExpense.findMany({ where: expenseWhere, orderBy: { expenseDate: "desc" }, take }) : [],
      type === "all" || type === "health_log" ? prisma.catHealthLog.count({ where: healthWhere }) : 0,
      type === "all" || type === "medical_visit" ? prisma.catMedicalVisit.count({ where: visitWhere }) : 0,
      type === "all" || type === "expense" ? prisma.catExpense.count({ where: expenseWhere }) : 0,
    ]);

    const items = [
      ...logs.map((log) => ({ itemType: "health_log", id: log.id, logType: log.logType, title: log.title, eventAt: log.recordedAt, summary: log.valueNumeric !== null && log.valueNumeric !== undefined ? `${log.valueNumeric}${log.valueUnit ?? ""}` : log.memo, collaboration: collaborationMeta({ record: log, viewerId: ownerId, accessRole: role }) })),
      ...visits.map((visit) => ({ itemType: "medical_visit", id: visit.id, eventAt: visit.visitDate, title: `${visit.hospitalName} 방문`, summary: visit.visitReason ?? visit.diagnosis, hospitalName: visit.hospitalName, attachmentCount: visit._count.attachments, collaboration: collaborationMeta({ record: visit, viewerId: ownerId, accessRole: role }) })),
      ...expenses.map((expense) => ({ itemType: "expense", id: expense.id, eventAt: expense.expenseDate, title: `${expense.expenseCategory} 지출`, summary: expense.vendorName ?? expense.memo, expenseCategory: expense.expenseCategory, amount: expense.amount, collaboration: collaborationMeta({ record: expense, viewerId: ownerId, accessRole: role }) })),
    ].sort((a, b) => new Date(b.eventAt).getTime() - new Date(a.eventAt).getTime());

    ok(res, { items: items.slice(skip, skip + pageSize), page, pageSize, total: healthTotal + visitTotal + expenseTotal, type });
  }),
);

appRoutes.get(
  "/cats/:catId/health-logs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { role } = await catAccessContext(ownerId, catId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const where = { catId, ...sensitiveRecordWhere(role, ownerId), logType: typeof req.query.type === "string" ? req.query.type : undefined };
    const [items, total] = await Promise.all([
      prisma.catHealthLog.findMany({ where, orderBy: { recordedAt: "desc" }, skip, take: pageSize }),
      prisma.catHealthLog.count({ where }),
    ]);
    const users = await loadCatUserDirectory(catId, items.map((item) => item.createdBy));
    ok(res, { items: items.map((item) => recordResponse(item, ownerId, role, users)), page, pageSize, total });
  }),
);

appRoutes.post(
  "/cats/:catId/health-logs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const { role } = await catAccessContext(ownerId, catId);
    const log = await prisma.catHealthLog.create({
      data: {
        catId,
        logType: requireString(req.body.logType, "logType"),
        title: typeof req.body.title === "string" ? req.body.title : undefined,
        recordedAt: optionalDate(req.body.recordedAt) ?? new Date(),
        valueNumeric: optionalNumber(req.body.valueNumeric),
        valueUnit: typeof req.body.valueUnit === "string" ? req.body.valueUnit : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        metadata: req.body.metadata === undefined ? Prisma.JsonNull : req.body.metadata,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    const users = await loadCatUserDirectory(catId, [log.createdBy]);
    ok(res, recordResponse(log, ownerId, role, users), 201);
  }),
);

appRoutes.get(
  "/cat-health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const log = await requireCatHealthLogAccess(ownerId, parseId(req.params.logId, "logId"));
    const { role } = await catAccessContext(ownerId, log.catId);
    const users = await loadCatUserDirectory(log.catId, [log.createdBy]);
    ok(res, recordResponse(log, ownerId, role, users));
  }),
);

appRoutes.patch(
  "/cat-health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const logId = parseId(req.params.logId, "logId");
    const existing = await requireCatHealthLogWriteAccess(ownerId, logId);
    const { role } = await catAccessContext(ownerId, existing.catId);
    const log = await prisma.catHealthLog.update({
      where: { id: logId },
      data: {
        logType: typeof req.body.logType === "string" ? req.body.logType : undefined,
        title: typeof req.body.title === "string" ? req.body.title : undefined,
        recordedAt: optionalDate(req.body.recordedAt),
        valueNumeric: optionalNumber(req.body.valueNumeric),
        valueUnit: typeof req.body.valueUnit === "string" ? req.body.valueUnit : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        metadata: req.body.metadata === undefined ? undefined : req.body.metadata,
        isSensitive: req.body.isSensitive === undefined ? undefined : normalizeSensitiveFlag(req.body),
      },
    });
    const users = await loadCatUserDirectory(existing.catId, [log.createdBy]);
    ok(res, recordResponse(log, ownerId, role, users));
  }),
);

appRoutes.delete(
  "/cat-health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const logId = parseId(req.params.logId, "logId");
    await requireCatHealthLogWriteAccess(ownerId, logId);
    await prisma.catHealthLog.delete({ where: { id: logId } });
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/cats/:catId/medical-visits",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { role } = await catAccessContext(ownerId, catId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const [items, total] = await Promise.all([
      prisma.catMedicalVisit.findMany({ where: { catId, ...sensitiveRecordWhere(role, ownerId) }, orderBy: { visitDate: "desc" }, include: { attachments: { orderBy: { createdAt: "desc" } } }, skip, take: pageSize }),
      prisma.catMedicalVisit.count({ where: { catId, ...sensitiveRecordWhere(role, ownerId) } }),
    ]);
    const users = await loadCatUserDirectory(catId, items.map((item) => item.createdBy));
    ok(res, { items: items.map((item) => recordResponse(item, ownerId, role, users)), page, pageSize, total });
  }),
);

appRoutes.post(
  "/cats/:catId/medical-visits",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const result = await prisma.$transaction(async (tx) => {
      const visit = await tx.catMedicalVisit.create({
        data: {
          catId,
          hospitalName: requireString(req.body.hospitalName, "hospitalName"),
          veterinarianName: typeof req.body.veterinarianName === "string" ? req.body.veterinarianName : undefined,
          visitDate: optionalDate(req.body.visitDate) ?? new Date(),
          visitReason: typeof req.body.visitReason === "string" ? req.body.visitReason : undefined,
          symptoms: typeof req.body.symptoms === "string" ? req.body.symptoms : undefined,
          diagnosis: typeof req.body.diagnosis === "string" ? req.body.diagnosis : undefined,
          treatment: typeof req.body.treatment === "string" ? req.body.treatment : undefined,
          prescribedItems: typeof req.body.prescribedItems === "string" ? req.body.prescribedItems : undefined,
          followUpDate: optionalDate(req.body.followUpDate),
          notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
          isSensitive: normalizeSensitiveFlag(req.body),
          createdBy: ownerId,
        },
      });
      let expenseId: bigint | null = null;
      if (req.body.expense?.create === true) {
        const expense = await tx.catExpense.create({
          data: {
            catId,
            medicalVisitId: visit.id,
            expenseCategory: "hospital",
            amount: Number(req.body.expense.amount ?? 0),
            expenseDate: optionalDate(req.body.expense.expenseDate) ?? new Date(),
            vendorName: typeof req.body.expense.vendorName === "string" ? req.body.expense.vendorName : req.body.hospitalName,
            memo: typeof req.body.expense.memo === "string" ? req.body.expense.memo : undefined,
            isSensitive: visit.isSensitive,
            createdBy: ownerId,
          },
        });
        expenseId = expense.id;
        await recalculateCatCostForecasts(tx, catId);
      }
      return { id: visit.id, expenseId };
    });
    ok(res, result, 201);
  }),
);

appRoutes.get(
  "/cat-medical-visits/:visitId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    await requireCatMedicalVisitAccess(ownerId, visitId);
    const visit = await prisma.catMedicalVisit.findUnique({ where: { id: visitId }, include: { attachments: { orderBy: { createdAt: "desc" } } } });
    if (!visit) throw new HttpError(404, "NOT_FOUND", "medical visit not found");
    const { role } = await catAccessContext(ownerId, visit.catId);
    const users = await loadCatUserDirectory(visit.catId, [visit.createdBy]);
    ok(res, recordResponse(visit, ownerId, role, users));
  }),
);

appRoutes.get(
  "/cat-medical-visits/:visitId/attachments",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    await requireCatMedicalVisitAccess(ownerId, visitId);
    const attachments = await prisma.catMedicalVisitAttachment.findMany({ where: { medicalVisitId: visitId }, orderBy: { createdAt: "desc" } });
    ok(res, attachments);
  }),
);

appRoutes.post(
  "/cat-medical-visits/:visitId/attachments",
  catAttachmentUpload.single("file"),
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    await requireCatMedicalVisitWriteAccess(ownerId, visitId);
    if (!req.file) throw new HttpError(400, "VALIDATION_ERROR", "file is required");
    const fileUrl = `cat-medical-visits/${req.file.filename}`;
    const attachment = await prisma.catMedicalVisitAttachment.create({
      data: {
        medicalVisitId: visitId,
        fileType: normalizeAttachmentType(req.body.fileType),
        fileUrl,
        originalFilename: req.file.originalname,
        mimeType: req.file.mimetype,
        fileSizeBytes: req.file.size,
        uploadedBy: ownerId,
      },
    });
    ok(res, attachment, 201);
  }),
);

appRoutes.get(
  "/cat-attachments/:attachmentId/download",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const attachmentId = parseId(req.params.attachmentId, "attachmentId");
    const attachment = await requireCatAttachmentAccess(ownerId, attachmentId);
    const absolutePath = resolveUploadPath(attachment.fileUrl);
    if (!fs.existsSync(absolutePath)) throw new HttpError(404, "NOT_FOUND", "attachment file not found");
    res.download(absolutePath, attachment.originalFilename ?? path.basename(attachment.fileUrl));
  }),
);

appRoutes.delete(
  "/cat-attachments/:attachmentId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const attachmentId = parseId(req.params.attachmentId, "attachmentId");
    const attachment = await requireCatAttachmentWriteAccess(ownerId, attachmentId);
    await prisma.catMedicalVisitAttachment.delete({ where: { id: attachmentId } });
    await deleteAttachmentFile(attachment.fileUrl);
    ok(res, { deleted: true });
  }),
);

appRoutes.patch(
  "/cat-medical-visits/:visitId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    const existing = await requireCatMedicalVisitWriteAccess(ownerId, visitId);
    const { role } = await catAccessContext(ownerId, existing.catId);
    const visit = await prisma.catMedicalVisit.update({
      where: { id: visitId },
      data: {
        hospitalName: typeof req.body.hospitalName === "string" ? req.body.hospitalName : undefined,
        veterinarianName: typeof req.body.veterinarianName === "string" ? req.body.veterinarianName : undefined,
        visitDate: optionalDate(req.body.visitDate),
        visitReason: typeof req.body.visitReason === "string" ? req.body.visitReason : undefined,
        symptoms: typeof req.body.symptoms === "string" ? req.body.symptoms : undefined,
        diagnosis: typeof req.body.diagnosis === "string" ? req.body.diagnosis : undefined,
        treatment: typeof req.body.treatment === "string" ? req.body.treatment : undefined,
        prescribedItems: typeof req.body.prescribedItems === "string" ? req.body.prescribedItems : undefined,
        followUpDate: optionalDate(req.body.followUpDate),
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
        isSensitive: req.body.isSensitive === undefined ? undefined : normalizeSensitiveFlag(req.body),
      },
    });
    const users = await loadCatUserDirectory(existing.catId, [visit.createdBy]);
    ok(res, recordResponse(visit, ownerId, role, users));
  }),
);

appRoutes.delete(
  "/cat-medical-visits/:visitId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    const existing = await requireCatMedicalVisitWriteAccess(ownerId, visitId);
    const attachments = await prisma.catMedicalVisitAttachment.findMany({ where: { medicalVisitId: visitId } });
    await prisma.$transaction(async (tx) => {
      await tx.catExpense.updateMany({ where: { medicalVisitId: visitId }, data: { medicalVisitId: null } });
      await tx.catMedicalVisit.delete({ where: { id: visitId } });
      await recalculateCatCostForecasts(tx, existing.catId);
    });
    await Promise.all(attachments.map((a) => deleteAttachmentFile(a.fileUrl)));
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/cats/:catId/expenses",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    const { role } = await catAccessContext(ownerId, catId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const where = {
      catId,
      ...sensitiveRecordWhere(role, ownerId),
      expenseCategory: typeof req.query.category === "string" ? req.query.category : undefined,
      expenseDate: { gte: typeof req.query.from === "string" ? new Date(req.query.from) : undefined, lte: typeof req.query.to === "string" ? new Date(req.query.to) : undefined },
    };
    const [items, total] = await Promise.all([
      prisma.catExpense.findMany({ where, orderBy: { expenseDate: "desc" }, skip, take: pageSize }),
      prisma.catExpense.count({ where }),
    ]);
    const users = await loadCatUserDirectory(catId, items.map((item) => item.createdBy));
    ok(res, { items: items.map((item) => recordResponse(item, ownerId, role, users)), page, pageSize, total });
  }),
);

appRoutes.post(
  "/cats/:catId/expenses",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const { role } = await catAccessContext(ownerId, catId);
    const expense = await prisma.catExpense.create({
      data: {
        catId,
        medicalVisitId: req.body.medicalVisitId ? BigInt(req.body.medicalVisitId) : undefined,
        expenseCategory: requireString(req.body.expenseCategory, "expenseCategory"),
        amount: Number(req.body.amount),
        expenseDate: optionalDate(req.body.expenseDate) ?? new Date(),
        vendorName: typeof req.body.vendorName === "string" ? req.body.vendorName : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        isSensitive: normalizeSensitiveFlag(req.body),
        createdBy: ownerId,
      },
    });
    await recalculateCatCostForecasts(prisma, catId);
    const users = await loadCatUserDirectory(catId, [expense.createdBy]);
    ok(res, recordResponse(expense, ownerId, role, users), 201);
  }),
);

appRoutes.get(
  "/cats/:catId/expenses/summary",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatAccess(ownerId, catId);
    const { role } = await catAccessContext(ownerId, catId);
    const year = Number(req.query.year ?? new Date().getFullYear());
    const month = Number(req.query.month ?? new Date().getMonth() + 1);
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0);
    const expenses = await prisma.catExpense.findMany({ where: { catId, ...sensitiveRecordWhere(role, ownerId), expenseDate: { gte: start, lte: end } } });
    const byCategory = Object.values(
      expenses.reduce<Record<string, { category: string; amount: number }>>((acc, e) => {
        acc[e.expenseCategory] ??= { category: e.expenseCategory, amount: 0 };
        acc[e.expenseCategory].amount += Number(e.amount);
        return acc;
      }, {}),
    );
    ok(res, { totalAmount: byCategory.reduce((sum, item) => sum + item.amount, 0), byCategory });
  }),
);

appRoutes.get(
  "/cats/:catId/expenses/stats",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatAccess(ownerId, catId);
    const { role } = await catAccessContext(ownerId, catId);
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - now.getDay());
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 2, 1);
    const expenses = await prisma.catExpense.findMany({
      where: { catId, ...sensitiveRecordWhere(role, ownerId), expenseDate: { gte: threeMonthsAgo } },
    });
    const sumAmount = (exps: typeof expenses) => exps.reduce((s, e) => s + Number(e.amount), 0);
    const todayTotal = sumAmount(expenses.filter((e) => new Date(e.expenseDate) >= todayStart));
    const weekTotal = sumAmount(expenses.filter((e) => new Date(e.expenseDate) >= weekStart));
    const monthExpenses = expenses.filter((e) => new Date(e.expenseDate) >= monthStart);
    const monthTotal = sumAmount(monthExpenses);
    const catMap: Record<string, number> = {};
    for (const e of monthExpenses) {
      catMap[e.expenseCategory] = (catMap[e.expenseCategory] ?? 0) + Number(e.amount);
    }
    const byCategory = Object.entries(catMap)
      .map(([category, amount]) => ({ category, amount, ratio: monthTotal > 0 ? amount / monthTotal : 0 }))
      .sort((a, b) => b.amount - a.amount);
    const monthlyTotals = [];
    for (let i = 2; i >= 0; i--) {
      const ms = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const me = new Date(now.getFullYear(), now.getMonth() - i + 1, 0);
      const mExps = expenses.filter((e) => new Date(e.expenseDate) >= ms && new Date(e.expenseDate) <= me);
      monthlyTotals.push({ year: ms.getFullYear(), month: ms.getMonth() + 1, amount: sumAmount(mExps) });
    }
    ok(res, { today: todayTotal, thisWeek: weekTotal, thisMonth: monthTotal, byCategory, monthlyTotals });
  }),
);

appRoutes.get(
  "/cat-expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expense = await requireCatExpenseAccess(ownerId, parseId(req.params.expenseId, "expenseId"));
    const { role } = await catAccessContext(ownerId, expense.catId);
    const users = await loadCatUserDirectory(expense.catId, [expense.createdBy]);
    ok(res, recordResponse(expense, ownerId, role, users));
  }),
);

appRoutes.patch(
  "/cat-expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expenseId = parseId(req.params.expenseId, "expenseId");
    const existing = await requireCatExpenseWriteAccess(ownerId, expenseId);
    const { role } = await catAccessContext(ownerId, existing.catId);
    const expense = await prisma.catExpense.update({
      where: { id: expenseId },
      data: {
        expenseCategory: typeof req.body.expenseCategory === "string" ? req.body.expenseCategory : undefined,
        amount: req.body.amount !== undefined ? Number(req.body.amount) : undefined,
        expenseDate: optionalDate(req.body.expenseDate),
        vendorName: typeof req.body.vendorName === "string" ? req.body.vendorName : undefined,
        memo: typeof req.body.memo === "string" ? req.body.memo : undefined,
        isSensitive: req.body.isSensitive === undefined ? undefined : normalizeSensitiveFlag(req.body),
      },
    });
    await recalculateCatCostForecasts(prisma, existing.catId);
    const users = await loadCatUserDirectory(existing.catId, [expense.createdBy]);
    ok(res, recordResponse(expense, ownerId, role, users));
  }),
);

appRoutes.delete(
  "/cat-expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expenseId = parseId(req.params.expenseId, "expenseId");
    const existing = await requireCatExpenseWriteAccess(ownerId, expenseId);
    await prisma.catExpense.delete({ where: { id: expenseId } });
    await recalculateCatCostForecasts(prisma, existing.catId);
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/cats/:catId/cost-forecasts/latest",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatAccess(ownerId, catId);
    const forecasts = await latestCatForecasts(prisma, catId);
    ok(res, {
      basic: forecastResponse(forecasts.basic as any), // eslint-disable-line @typescript-eslint/no-explicit-any
      caution: forecastResponse(forecasts.caution as any), // eslint-disable-line @typescript-eslint/no-explicit-any
      highRisk: forecastResponse(forecasts.highRisk as any), // eslint-disable-line @typescript-eslint/no-explicit-any
      generatedAt: forecasts.generatedAt,
    });
  }),
);

appRoutes.post(
  "/cats/:catId/cost-forecasts/recalculate",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const generatedCount = await recalculateCatCostForecasts(prisma, catId);
    ok(res, { generatedCount }, 201);
  }),
);

appRoutes.get(
  "/cats/:catId/cost-forecasts/history",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatAccess(ownerId, catId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const [items, total] = await Promise.all([
      prisma.catCostForecast.findMany({ where: { catId }, orderBy: { generatedAt: "desc" }, skip, take: pageSize }),
      prisma.catCostForecast.count({ where: { catId } }),
    ]);
    ok(res, { items, page, pageSize, total });
  }),
);

appRoutes.post(
  "/cats/:catId/visit-reports",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatWriteAccess(ownerId, catId);
    const report = await buildCatVisitReport(prisma, catId, ownerId);
    ok(res, { id: report.id, title: report.title }, 201);
  }),
);

appRoutes.get(
  "/cats/:catId/visit-reports/latest",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatAccess(ownerId, catId);
    const report = await prisma.catVisitReport.findFirst({ where: { catId }, orderBy: { generatedAt: "desc" } });
    ok(res, catVisitReportResponse(report));
  }),
);

appRoutes.get(
  "/cats/:catId/visit-reports",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const catId = parseId(req.params.catId, "catId");
    await requireCatAccess(ownerId, catId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const [items, total] = await Promise.all([
      prisma.catVisitReport.findMany({ where: { catId }, orderBy: { generatedAt: "desc" }, skip, take: pageSize }),
      prisma.catVisitReport.count({ where: { catId } }),
    ]);
    ok(res, { items: items.map(catVisitReportResponse), page, pageSize, total });
  }),
);

appRoutes.get(
  "/cat-visit-reports/:reportId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const reportId = parseId(req.params.reportId, "reportId");
    const report = await prisma.catVisitReport.findUnique({ where: { id: reportId } });
    if (!report) throw new HttpError(404, "NOT_FOUND", "visit report not found");
    await requireCatAccess(ownerId, report.catId);
    ok(res, catVisitReportResponse(report));
  }),
);
