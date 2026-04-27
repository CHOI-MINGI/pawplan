import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

export const visitReportNotice =
  "이 리포트는 보호자가 입력한 기록을 병원 방문 전에 정리하기 위한 자료이며, 진단이나 치료 판단을 대체하지 않습니다.";

export async function buildVisitReport(tx: Tx, dogId: bigint, userId: bigint) {
  const [dog, symptoms, weights, medications, conditions, visits] = await Promise.all([
    tx.dog.findUniqueOrThrow({ where: { id: dogId } }),
    tx.healthLog.findMany({
      where: { dogId, logType: "symptom" },
      orderBy: { recordedAt: "desc" },
      take: 5,
    }),
    tx.healthLog.findMany({
      where: { dogId, logType: "weight", valueNumeric: { not: null } },
      orderBy: { recordedAt: "desc" },
      take: 2,
    }),
    tx.dogMedication.findMany({ where: { dogId, isActive: true }, orderBy: { startedOn: "desc" }, take: 10 }),
    tx.dogCondition.findMany({ where: { dogId, status: { in: ["active", "monitoring"] } }, take: 10 }),
    tx.medicalVisit.findMany({ where: { dogId }, orderBy: { visitDate: "desc" }, take: 5 }),
  ]);

  const ageYears = dog.birthDate ? Math.floor((Date.now() - dog.birthDate.getTime()) / (365.25 * 24 * 60 * 60 * 1000)) : null;
  const summary = {
    dog: {
      name: dog.name,
      breed: dog.breed,
      ageYears,
      currentWeightKg: dog.currentWeightKg ? Number(dog.currentWeightKg) : null,
    },
    recentSymptoms: symptoms.map((log) => log.memo || log.title || "증상 메모"),
    weightTrend:
      weights.length >= 2
        ? {
            previousWeightKg: Number(weights[1].valueNumeric),
            currentWeightKg: Number(weights[0].valueNumeric),
          }
        : null,
    activeMedications: medications.map((medication) =>
      [medication.medicationName, medication.frequencyText].filter(Boolean).join(" "),
    ),
    conditions: conditions.map((condition) => condition.conditionName),
    recentVisits: visits.map((visit) =>
      `${visit.visitDate.toISOString().slice(0, 10)} ${visit.visitReason || visit.diagnosis || visit.hospitalName}`,
    ),
  };

  const title = `${new Date().toISOString().slice(0, 10)} 병원 방문 리포트`;
  const renderedText = [
    `${dog.name} / ${dog.breed}${ageYears !== null ? ` / ${ageYears}세` : ""}`,
    symptoms.length ? `최근 증상: ${summary.recentSymptoms.join(", ")}` : "최근 증상 기록 없음",
    medications.length ? `복용약: ${summary.activeMedications.join(", ")}` : "현재 복용약 기록 없음",
    conditions.length ? `주의 정보: ${summary.conditions.join(", ")}` : "등록된 알레르기/기저질환 없음",
    visitReportNotice,
  ].join("\n");

  return tx.visitReport.create({
    data: {
      dogId,
      title,
      summaryJson: summary,
      renderedText,
      generatedBy: userId,
    },
  });
}
