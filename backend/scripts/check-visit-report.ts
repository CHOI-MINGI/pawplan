import assert from "node:assert/strict";
import { buildVisitReport } from "../src/domain/visitReport.js";

function daysAgo(days: number) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

async function main() {
  let created: Record<string, any> | null = null;
  const tx = {
    dog: {
      findUniqueOrThrow: async () => ({
        id: 1n,
        name: "콩이",
        breed: "푸들",
        birthDate: daysAgo(365 * 6),
        currentWeightKg: 6.1,
      }),
    },
    healthLog: {
      findMany: async ({ where }: { where: Record<string, any> }) => {
        if (where.logType === "weight") {
          return [
            {
              logType: "weight",
              title: "체중",
              recordedAt: daysAgo(4),
              valueNumeric: 6.1,
              valueUnit: "kg",
              memo: null,
            },
            {
              logType: "weight",
              title: "체중",
              recordedAt: daysAgo(26),
              valueNumeric: 5.6,
              valueUnit: "kg",
              memo: null,
            },
          ];
        }
        return [
          {
            logType: "symptom",
            title: "귀 가려움",
            recordedAt: daysAgo(3),
            valueNumeric: null,
            valueUnit: null,
            memo: "귀를 자주 긁고 냄새가 남",
          },
          {
            logType: "symptom",
            title: "식욕 변화",
            recordedAt: daysAgo(12),
            valueNumeric: null,
            valueUnit: null,
            memo: "사료를 남김",
          },
        ];
      },
    },
    dogMedication: {
      findMany: async () => [
        {
          medicationName: "항생제",
          dosage: null,
          frequencyText: "하루 2회",
          startedOn: daysAgo(5),
          endedOn: null,
          notes: null,
        },
      ],
    },
    dogCondition: {
      findMany: async () => [
        {
          conditionType: "allergy",
          conditionName: "피부 알레르기",
          severity: null,
          diagnosedOn: null,
          status: "monitoring",
          notes: null,
        },
      ],
    },
    medicalVisit: {
      findMany: async () => [
        {
          hospitalName: "튼튼동물병원",
          veterinarianName: null,
          visitDate: daysAgo(8),
          visitReason: "귀 가려움",
          symptoms: "귀 가려움",
          diagnosis: null,
          treatment: null,
          prescribedItems: "항생제",
          followUpDate: daysAgo(-7),
          notes: null,
        },
      ],
    },
    visitReport: {
      create: async ({ data }: { data: Record<string, any> }) => {
        created = { id: 99n, ...data };
        return created;
      },
    },
  };

  const report = await buildVisitReport(tx as any, 1n, 7n);
  const summary = report.summaryJson as Record<string, any>;

  assert.equal(summary.reportVersion, "vet_visit_summary_v2");
  assert.equal(summary.recent30Days.symptomCount, 2);
  assert.equal(summary.recent30Days.visitCount, 1);
  assert.ok(
    summary.recent30Days.weightTrend.deltaPct >= 5,
    "weight trend should capture recent change",
  );
  assert.ok(
    summary.questionList.some((item: Record<string, unknown>) =>
      String(item.question).includes("증상"),
    ),
    "symptom-based vet question should be generated",
  );
  assert.ok(
    summary.missingRecords.some((item: Record<string, unknown>) =>
      String(item.title).includes("복약"),
    ),
    "missing medication dosage should be flagged",
  );
  assert.ok(
    String(report.renderedText).includes("수의사에게 물어볼 질문"),
    "rendered text should include vet questions",
  );
  assert.ok(created, "report should be created");

  console.log("Visit report checks passed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
