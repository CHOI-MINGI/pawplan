import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

const dayMs = 24 * 60 * 60 * 1000;

type CareScheduleLike = {
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
};

const scheduleTypeLabels: Record<string, string> = {
  heartworm: "심장사상충",
  medication: "복약",
  deworming: "구충",
  vaccine: "예방접종",
  checkup: "건강검진",
  grooming: "미용·위생",
};

function addDays(base: Date, days: number) {
  return new Date(base.getTime() + days * dayMs);
}

function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

export function careScheduleTypeLabel(scheduleType: string) {
  return scheduleTypeLabels[scheduleType] ?? "돌봄";
}

export function careReminderPolicy(scheduleType: string, priority: string) {
  const highPriority = priority === "high";
  if (scheduleType === "vaccine" || scheduleType === "checkup") {
    return {
      leadDays: highPriority ? [7, 1, 0] : [3, 0],
      hour: 9,
      minute: 0,
      delivery: highPriority ? "push_candidate" : "local",
    };
  }
  if (scheduleType === "heartworm" || scheduleType === "medication") {
    return {
      leadDays: highPriority ? [1, 0] : [0],
      hour: 8,
      minute: 0,
      delivery: highPriority ? "push_candidate" : "local",
    };
  }
  if (scheduleType === "deworming") {
    return {
      leadDays: [3, 0],
      hour: 9,
      minute: 0,
      delivery: highPriority ? "push_candidate" : "local",
    };
  }
  return {
    leadDays: highPriority ? [1, 0] : [0],
    hour: scheduleType === "grooming" ? 10 : 9,
    minute: 0,
    delivery: "local",
  };
}

export function buildCarePlanMetadata(
  schedule: CareScheduleLike,
  viewerId: bigint,
  now = new Date(),
) {
  const today = startOfDay(now);
  const dueDay = startOfDay(schedule.dueDate);
  const dueInDays = Math.round((dueDay.getTime() - today.getTime()) / dayMs);
  const overdueDays = Math.max(0, -dueInDays);
  const repeatFailureThreshold = schedule.repeatCycleDays
    ? Math.max(2, Math.min(7, Math.ceil(schedule.repeatCycleDays * 0.1)))
    : 3;
  const failureStatus =
    schedule.status !== "pending"
      ? "closed"
      : overdueDays >= repeatFailureThreshold
        ? "missed_repeated"
        : overdueDays > 0
          ? "overdue"
          : dueInDays === 0
            ? "due_today"
            : dueInDays <= 7
              ? "due_soon"
              : "ok";
  const policy = careReminderPolicy(schedule.scheduleType, schedule.priority);
  const responsibleUserId = schedule.assignedTo ?? schedule.createdBy;
  const responsibleLabel = responsibleUserId
    ? responsibleUserId === viewerId
      ? "나"
      : "가족 구성원"
    : "담당자 미지정";
  const pushCandidate =
    policy.delivery === "push_candidate" ||
    failureStatus === "missed_repeated" ||
    (schedule.priority === "high" && failureStatus !== "ok");

  return {
    typeLabel: careScheduleTypeLabel(schedule.scheduleType),
    dueInDays,
    overdueDays,
    failureStatus,
    failureMessage:
      failureStatus === "missed_repeated"
        ? "반복 일정이 지연되고 있어 담당자 확인이 필요합니다."
        : failureStatus === "overdue"
          ? "예정일이 지나 완료 또는 건너뛰기 확인이 필요합니다."
          : null,
    reminderPolicy: policy,
    delivery: pushCandidate ? "push_candidate" : "local",
    responsibleUserId,
    responsibleLabel,
    responsibilitySource: schedule.assignedTo
      ? "assignee"
      : schedule.createdBy
        ? "creator"
        : "none",
  };
}

export function decorateCareSchedule<T extends CareScheduleLike>(
  schedule: T,
  viewerId: bigint,
  now = new Date(),
) {
  return {
    ...schedule,
    carePlan: buildCarePlanMetadata(schedule, viewerId, now),
  };
}

export async function generateDefaultCareSchedules(tx: Tx, dogId: bigint, baseDate: Date, createdBy?: bigint) {
  const dog = await tx.dog.findUniqueOrThrow({ where: { id: dogId } });
  const ageYears = dog.birthDate ? Math.max(0, (baseDate.getTime() - dog.birthDate.getTime()) / (365.25 * dayMs)) : 3;

  const templates = [
    {
      scheduleType: "heartworm",
      title: "심장사상충 예방",
      description: "월 1회 권장되는 예방 일정입니다.",
      dueDate: addDays(baseDate, 7),
      repeatCycleDays: 30,
      priority: "high",
    },
    {
      scheduleType: "deworming",
      title: "정기 구충",
      description: "기본 구충 관리 일정입니다.",
      dueDate: addDays(baseDate, 30),
      repeatCycleDays: 90,
      priority: "medium",
    },
    {
      scheduleType: "vaccine",
      title: ageYears < 1 ? "기초 예방접종 확인" : "광견병 예방접종",
      description: ageYears < 1 ? "어린 강아지의 기초 접종 이력을 확인하세요." : "연 1회 권장되는 예방 일정입니다.",
      dueDate: addDays(baseDate, ageYears < 1 ? 14 : 60),
      repeatCycleDays: ageYears < 1 ? null : 365,
      priority: "high",
    },
    {
      scheduleType: "checkup",
      title: ageYears >= 7 ? "노령견 건강검진" : "정기 건강검진",
      description: ageYears >= 7 ? "노령견은 더 짧은 주기의 검진을 권장합니다." : "반기 또는 연 1회 검진 일정을 관리하세요.",
      dueDate: addDays(baseDate, ageYears >= 7 ? 45 : 90),
      repeatCycleDays: ageYears >= 7 ? 180 : 365,
      priority: ageYears >= 7 ? "high" : "medium",
    },
    {
      scheduleType: "grooming",
      title: "미용 및 위생 관리",
      description: "피부와 위생 상태를 주기적으로 확인하세요.",
      dueDate: addDays(baseDate, 45),
      repeatCycleDays: 60,
      priority: "low",
    },
  ];

  const existing = await tx.careSchedule.count({ where: { dogId, sourceType: "system" } });
  if (existing > 0) return 0;

  await tx.careSchedule.createMany({
    data: templates.map((template) => ({
      ...template,
      dogId,
      createdBy,
      sourceType: "system",
      reminderEnabled: true,
    })),
  });

  return templates.length;
}
