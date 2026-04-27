import { Router } from "express";
import { Prisma } from "@prisma/client";
import fs from "node:fs";
import { promises as fsp } from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import multer from "multer";
import { AuthedRequest, requireAuth } from "../auth.js";
import { generateDefaultCareSchedules } from "../domain/carePlan.js";
import {
  latestForecasts,
  recalculateCostForecasts,
} from "../domain/costForecast.js";
import { buildVisitReport, visitReportNotice } from "../domain/visitReport.js";
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

function userId(req: AuthedRequest) {
  return req.userId;
}

async function requireDogAccess(ownerId: bigint, dogId: bigint) {
  const dog = await prisma.dog.findUnique({ where: { id: dogId } });
  if (!dog || dog.primaryOwnerId !== ownerId) {
    throw new HttpError(404, "NOT_FOUND", "dog not found");
  }
  return dog;
}

async function requireScheduleAccess(ownerId: bigint, scheduleId: bigint) {
  const schedule = await prisma.careSchedule.findUnique({
    where: { id: scheduleId },
  });
  if (!schedule) throw new HttpError(404, "NOT_FOUND", "schedule not found");
  await requireDogAccess(ownerId, schedule.dogId);
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

async function requireMedicationAccess(ownerId: bigint, medicationId: bigint) {
  const medication = await prisma.dogMedication.findUnique({
    where: { id: medicationId },
  });
  if (!medication)
    throw new HttpError(404, "NOT_FOUND", "medication not found");
  await requireDogAccess(ownerId, medication.dogId);
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
    },
  });
}

async function requireHealthLogAccess(ownerId: bigint, logId: bigint) {
  const log = await prisma.healthLog.findUnique({ where: { id: logId } });
  if (!log) throw new HttpError(404, "NOT_FOUND", "health log not found");
  await requireDogAccess(ownerId, log.dogId);
  return log;
}

async function requireMedicalVisitAccess(ownerId: bigint, visitId: bigint) {
  const visit = await prisma.medicalVisit.findUnique({
    where: { id: visitId },
  });
  if (!visit) throw new HttpError(404, "NOT_FOUND", "medical visit not found");
  await requireDogAccess(ownerId, visit.dogId);
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

async function requireExpenseAccess(ownerId: bigint, expenseId: bigint) {
  const expense = await prisma.expense.findUnique({ where: { id: expenseId } });
  if (!expense) throw new HttpError(404, "NOT_FOUND", "expense not found");
  await requireDogAccess(ownerId, expense.dogId);
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

function forecastResponse(
  row: Awaited<ReturnType<typeof latestForecasts>>["basic"],
) {
  if (!row) return null;
  return {
    monthlyEstimate: row.monthlyEstimate,
    rangeMin: row.rangeMin,
    rangeMax: row.rangeMax,
    yearlyEstimate: row.yearlyEstimate,
    sixMonthEstimate: row.sixMonthEstimate,
    lifetimeEstimate: row.lifetimeEstimate,
    confidenceLevel: row.confidenceLevel,
    breakdown: row.breakdown,
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
    const dog = await prisma.dog.create({
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
        notes: typeof req.body.notes === "string" ? req.body.notes : undefined,
      },
      select: { id: true, name: true },
    });
    ok(res, dog, 201);
  }),
);

appRoutes.get(
  "/dogs",
  asyncHandler(async (req, res) => {
    const dogs = await prisma.dog.findMany({
      where: { primaryOwnerId: userId(req as AuthedRequest) },
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
    await requireDogAccess(ownerId, dogId);
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
  "/dogs/:dogId/dashboard",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    const dog = await requireDogAccess(ownerId, dogId);
    const today = new Date();
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    const [todaySchedules, recentHealthLogs, expenses, forecasts] =
      await Promise.all([
        prisma.careSchedule.findMany({
          where: {
            dogId,
            status: "pending",
            dueDate: {
              gte: new Date(today.toISOString().slice(0, 10)),
              lte: monthEnd,
            },
          },
          orderBy: { dueDate: "asc" },
          take: 5,
        }),
        prisma.healthLog.findMany({
          where: { dogId },
          orderBy: { recordedAt: "desc" },
          take: 5,
        }),
        prisma.expense.findMany({
          where: { dogId, expenseDate: { gte: monthStart, lte: monthEnd } },
        }),
        latestForecasts(prisma, dogId),
      ]);

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
      todaySchedules,
      recentHealthLogs,
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
    });
  }),
);

appRoutes.get(
  "/dogs/:dogId/conditions",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const conditions = await prisma.dogCondition.findMany({
      where: {
        dogId,
        status:
          typeof req.query.status === "string" ? req.query.status : undefined,
      },
      orderBy: [{ status: "asc" }, { updatedAt: "desc" }],
    });
    ok(res, conditions);
  }),
);

appRoutes.post(
  "/dogs/:dogId/conditions",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
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
      },
    });
    await recalculateCostForecasts(prisma, dogId);
    ok(res, condition, 201);
  }),
);

appRoutes.patch(
  "/conditions/:conditionId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const conditionId = parseId(req.params.conditionId, "conditionId");
    const existing = await requireConditionAccess(ownerId, conditionId);
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
      },
    });
    await recalculateCostForecasts(prisma, existing.dogId);
    ok(res, condition);
  }),
);

appRoutes.delete(
  "/conditions/:conditionId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const conditionId = parseId(req.params.conditionId, "conditionId");
    const existing = await requireConditionAccess(ownerId, conditionId);
    await prisma.dogCondition.delete({ where: { id: conditionId } });
    await recalculateCostForecasts(prisma, existing.dogId);
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/dogs/:dogId/medications",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const onlyActive = req.query.active === "true";
    const medications = await prisma.dogMedication.findMany({
      where: { dogId, isActive: onlyActive ? true : undefined },
      orderBy: [{ isActive: "desc" }, { updatedAt: "desc" }],
    });
    ok(res, medications);
  }),
);

appRoutes.post(
  "/dogs/:dogId/medications",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
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
      },
    });
    await recalculateCostForecasts(prisma, dogId);
    ok(res, medication, 201);
  }),
);

appRoutes.patch(
  "/medications/:medicationId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const medicationId = parseId(req.params.medicationId, "medicationId");
    const existing = await requireMedicationAccess(ownerId, medicationId);
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
      },
    });
    await recalculateCostForecasts(prisma, existing.dogId);
    ok(res, medication);
  }),
);

appRoutes.delete(
  "/medications/:medicationId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const medicationId = parseId(req.params.medicationId, "medicationId");
    const existing = await requireMedicationAccess(ownerId, medicationId);
    await prisma.dogMedication.delete({ where: { id: medicationId } });
    await recalculateCostForecasts(prisma, existing.dogId);
    ok(res, { deleted: true });
  }),
);

appRoutes.post(
  "/dogs/:dogId/care-schedules/generate",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
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
    await requireDogAccess(ownerId, dogId);
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
    ok(res, schedules);
  }),
);

appRoutes.post(
  "/dogs/:dogId/care-schedules",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
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
      },
    });
    ok(res, schedule, 201);
  }),
);

appRoutes.get(
  "/care-schedules/:scheduleId",
  asyncHandler(async (req, res) => {
    ok(
      res,
      await requireScheduleAccess(
        userId(req as AuthedRequest),
        parseId(req.params.scheduleId, "scheduleId"),
      ),
    );
  }),
);

appRoutes.patch(
  "/care-schedules/:scheduleId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    await requireScheduleAccess(ownerId, scheduleId);
    const schedule = await prisma.careSchedule.update({
      where: { id: scheduleId },
      data: {
        title: typeof req.body.title === "string" ? req.body.title : undefined,
        description:
          typeof req.body.description === "string"
            ? req.body.description
            : undefined,
        dueDate: optionalDate(req.body.dueDate),
        priority:
          typeof req.body.priority === "string" ? req.body.priority : undefined,
        reminderEnabled:
          typeof req.body.reminderEnabled === "boolean"
            ? req.body.reminderEnabled
            : undefined,
      },
    });
    ok(res, schedule);
  }),
);

appRoutes.post(
  "/care-schedules/:scheduleId/complete",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireScheduleAccess(ownerId, scheduleId);
    if (existing.status !== "pending") {
      ok(res, existing);
      return;
    }
    const completedAt = optionalDate(req.body.completedAt) ?? new Date();
    const schedule = await prisma.careSchedule.update({
      where: { id: scheduleId },
      data: { status: "completed", completedAt },
    });

    await createNextRecurringSchedule(existing, ownerId);

    ok(res, schedule);
  }),
);

appRoutes.post(
  "/care-schedules/:scheduleId/skip",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const scheduleId = parseId(req.params.scheduleId, "scheduleId");
    const existing = await requireScheduleAccess(ownerId, scheduleId);
    if (existing.status !== "pending") {
      ok(res, existing);
      return;
    }
    const schedule = await prisma.careSchedule.update({
      where: { id: scheduleId },
      data: { status: "skipped" },
    });
    await createNextRecurringSchedule(existing, ownerId);
    ok(res, schedule);
  }),
);

appRoutes.get(
  "/dogs/:dogId/timeline",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const type = timelineType(req.query.type);
    const from = optionalDate(req.query.from);
    const to = optionalDate(req.query.to);
    const take = skip + pageSize;
    const dateFilter = {
      ...(from ? { gte: from } : {}),
      ...(to ? { lte: to } : {}),
    };
    const healthWhere = { dogId, recordedAt: dateFilter };
    const visitWhere = { dogId, visitDate: dateFilter };
    const expenseWhere = { dogId, expenseDate: dateFilter };

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
      })),
      ...visits.map((visit) => ({
        itemType: "medical_visit",
        id: visit.id,
        eventAt: visit.visitDate,
        title: `${visit.hospitalName} 방문`,
        summary: visit.visitReason ?? visit.diagnosis,
        hospitalName: visit.hospitalName,
        attachmentCount: visit._count.attachments,
      })),
      ...expenses.map((expense) => ({
        itemType: "expense",
        id: expense.id,
        eventAt: expense.expenseDate,
        title: `${expense.expenseCategory} 지출`,
        summary: expense.vendorName ?? expense.memo,
        expenseCategory: expense.expenseCategory,
        amount: expense.amount,
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
  "/dogs/:dogId/health-logs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const where = {
      dogId,
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
    ok(res, { items, page, pageSize, total });
  }),
);

appRoutes.post(
  "/dogs/:dogId/health-logs",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
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
        createdBy: ownerId,
      },
    });
    ok(res, log, 201);
  }),
);

appRoutes.get(
  "/health-logs/:logId",
  asyncHandler(async (req, res) => {
    ok(
      res,
      await requireHealthLogAccess(
        userId(req as AuthedRequest),
        parseId(req.params.logId, "logId"),
      ),
    );
  }),
);

appRoutes.patch(
  "/health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const logId = parseId(req.params.logId, "logId");
    await requireHealthLogAccess(ownerId, logId);
    ok(
      res,
      await prisma.healthLog.update({
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
        },
      }),
    );
  }),
);

appRoutes.delete(
  "/health-logs/:logId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const logId = parseId(req.params.logId, "logId");
    await requireHealthLogAccess(ownerId, logId);
    await prisma.healthLog.delete({ where: { id: logId } });
    ok(res, { deleted: true });
  }),
);

appRoutes.get(
  "/dogs/:dogId/medical-visits",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const [items, total] = await Promise.all([
      prisma.medicalVisit.findMany({
        where: { dogId },
        orderBy: { visitDate: "desc" },
        include: { attachments: { orderBy: { createdAt: "desc" } } },
        skip,
        take: pageSize,
      }),
      prisma.medicalVisit.count({ where: { dogId } }),
    ]);
    ok(res, { items, page, pageSize, total });
  }),
);

appRoutes.post(
  "/dogs/:dogId/medical-visits",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
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
            createdBy: ownerId,
          },
        });
        expenseId = expense.id;
        await recalculateCostForecasts(tx, dogId);
      }
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
    ok(
      res,
      await prisma.medicalVisit.findUnique({
        where: { id: visitId },
        include: { attachments: { orderBy: { createdAt: "desc" } } },
      }),
    );
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
    await requireMedicalVisitAccess(ownerId, visitId);

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
    const attachment = await requireAttachmentAccess(ownerId, attachmentId);
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
    await requireMedicalVisitAccess(ownerId, visitId);
    ok(
      res,
      await prisma.medicalVisit.update({
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
        },
      }),
    );
  }),
);

appRoutes.delete(
  "/medical-visits/:visitId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const visitId = parseId(req.params.visitId, "visitId");
    const existing = await requireMedicalVisitAccess(ownerId, visitId);
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
    await requireDogAccess(ownerId, dogId);
    const { page, pageSize, skip } = parsePaging(req as AuthedRequest);
    const where = {
      dogId,
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
    ok(res, { items, page, pageSize, total });
  }),
);

appRoutes.post(
  "/dogs/:dogId/expenses",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
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
        createdBy: ownerId,
      },
    });
    await recalculateCostForecasts(prisma, dogId);
    ok(res, expense, 201);
  }),
);

appRoutes.get(
  "/dogs/:dogId/expenses/summary",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const dogId = parseId(req.params.dogId, "dogId");
    await requireDogAccess(ownerId, dogId);
    const year = Number(req.query.year ?? new Date().getFullYear());
    const month = Number(req.query.month ?? new Date().getMonth() + 1);
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0);
    const expenses = await prisma.expense.findMany({
      where: { dogId, expenseDate: { gte: start, lte: end } },
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
  "/expenses/:expenseId",
  asyncHandler(async (req, res) => {
    ok(
      res,
      await requireExpenseAccess(
        userId(req as AuthedRequest),
        parseId(req.params.expenseId, "expenseId"),
      ),
    );
  }),
);

appRoutes.patch(
  "/expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expenseId = parseId(req.params.expenseId, "expenseId");
    const existing = await requireExpenseAccess(ownerId, expenseId);
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
      },
    });
    await recalculateCostForecasts(prisma, existing.dogId);
    ok(res, expense);
  }),
);

appRoutes.delete(
  "/expenses/:expenseId",
  asyncHandler(async (req, res) => {
    const ownerId = userId(req as AuthedRequest);
    const expenseId = parseId(req.params.expenseId, "expenseId");
    const existing = await requireExpenseAccess(ownerId, expenseId);
    await prisma.expense.delete({ where: { id: expenseId } });
    await recalculateCostForecasts(prisma, existing.dogId);
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
    await requireDogAccess(ownerId, dogId);
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
    await requireDogAccess(ownerId, dogId);
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
      report
        ? { ...report, summary: report.summaryJson, notice: visitReportNotice }
        : null,
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
    ok(res, { items, page, pageSize, total });
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
    ok(res, {
      ...report,
      summary: report.summaryJson,
      notice: visitReportNotice,
    });
  }),
);
