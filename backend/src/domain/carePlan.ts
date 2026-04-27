import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

const dayMs = 24 * 60 * 60 * 1000;

function addDays(base: Date, days: number) {
  return new Date(base.getTime() + days * dayMs);
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
