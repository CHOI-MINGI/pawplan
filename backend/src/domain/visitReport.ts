import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

type HealthLogRow = {
  logType: string;
  title: string | null;
  recordedAt: Date;
  valueNumeric: Prisma.Decimal | null;
  valueUnit: string | null;
  memo: string | null;
};

type MedicationRow = {
  medicationName: string;
  dosage: string | null;
  frequencyText: string | null;
  startedOn: Date | null;
  endedOn: Date | null;
  notes: string | null;
};

type ConditionRow = {
  conditionType: string;
  conditionName: string;
  severity: string | null;
  diagnosedOn: Date | null;
  status: string;
  notes: string | null;
};

type MedicalVisitRow = {
  hospitalName: string;
  veterinarianName: string | null;
  visitDate: Date;
  visitReason: string | null;
  symptoms: string | null;
  diagnosis: string | null;
  treatment: string | null;
  prescribedItems: string | null;
  followUpDate: Date | null;
  notes: string | null;
};

type ReportQuestion = {
  priority: "high" | "medium" | "low";
  question: string;
  reason: string;
  source: string;
};

type MissingRecord = {
  severity: "high" | "medium" | "low";
  title: string;
  reason: string;
};

const dayMs = 24 * 60 * 60 * 1000;

export const visitReportNotice =
  "이 리포트는 보호자가 입력한 기록을 병원 방문 전에 정리하기 위한 자료이며, 진단이나 치료 판단을 대체하지 않습니다.";

function formatDate(date: Date | null | undefined) {
  return date ? date.toISOString().slice(0, 10) : null;
}

function textOrNull(value: string | null | undefined) {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : null;
}

function ageYears(birthDate: Date | null) {
  return birthDate
    ? Math.floor((Date.now() - birthDate.getTime()) / (365.25 * dayMs))
    : null;
}

function logLabel(log: HealthLogRow) {
  return textOrNull(log.memo) ?? textOrNull(log.title) ?? "증상 메모";
}

function medicationLabel(medication: MedicationRow) {
  return [
    medication.medicationName,
    medication.dosage,
    medication.frequencyText,
  ]
    .filter(Boolean)
    .join(" ");
}

function visitLabel(visit: MedicalVisitRow) {
  return [
    formatDate(visit.visitDate),
    visit.hospitalName,
    textOrNull(visit.visitReason) ??
      textOrNull(visit.diagnosis) ??
      textOrNull(visit.symptoms),
  ]
    .filter(Boolean)
    .join(" ");
}

function weightTrend(weights: readonly HealthLogRow[]) {
  if (weights.length < 2) return null;
  const current = Number(weights[0]!.valueNumeric);
  const previous = Number(weights[weights.length - 1]!.valueNumeric);
  if (!Number.isFinite(current) || !Number.isFinite(previous)) return null;
  const deltaKg = Number((current - previous).toFixed(2));
  const deltaPct =
    previous > 0 ? Number(((deltaKg / previous) * 100).toFixed(1)) : 0;
  return {
    previousWeightKg: previous,
    currentWeightKg: current,
    deltaKg,
    deltaPct,
    direction: deltaKg > 0 ? "increased" : deltaKg < 0 ? "decreased" : "flat",
  };
}

function buildRecentChanges(args: {
  symptoms30: readonly HealthLogRow[];
  weights30: readonly HealthLogRow[];
  visits30: readonly MedicalVisitRow[];
  medications30: readonly MedicationRow[];
  conditions30: readonly ConditionRow[];
}) {
  const changes: { type: string; title: string; detail: string }[] = [];
  if (args.symptoms30.length > 0) {
    changes.push({
      type: "symptom",
      title: `증상 기록 ${args.symptoms30.length}건`,
      detail: args.symptoms30.slice(0, 3).map(logLabel).join(", "),
    });
  }
  const trend = weightTrend(args.weights30);
  if (trend && Math.abs(trend.deltaKg) > 0) {
    changes.push({
      type: "weight",
      title: `체중 ${trend.deltaKg > 0 ? "증가" : "감소"}`,
      detail: `${trend.previousWeightKg}kg에서 ${trend.currentWeightKg}kg로 ${Math.abs(trend.deltaKg)}kg 변화했습니다.`,
    });
  }
  if (args.visits30.length > 0) {
    changes.push({
      type: "visit",
      title: `병원 방문 ${args.visits30.length}회`,
      detail: args.visits30.slice(0, 3).map(visitLabel).join(", "),
    });
  }
  if (args.medications30.length > 0) {
    changes.push({
      type: "medication",
      title: `최근 시작된 복약 ${args.medications30.length}건`,
      detail: args.medications30.map(medicationLabel).join(", "),
    });
  }
  if (args.conditions30.length > 0) {
    changes.push({
      type: "condition",
      title: `최근 등록된 질환 ${args.conditions30.length}건`,
      detail: args.conditions30
        .map((condition) => condition.conditionName)
        .join(", "),
    });
  }
  if (changes.length === 0) {
    changes.push({
      type: "none",
      title: "최근 30일 주요 변화 기록 없음",
      detail: "방문 전 증상, 체중, 복약 변화를 추가하면 상담 품질이 좋아집니다.",
    });
  }
  return changes;
}

function buildQuestions(args: {
  symptoms30: readonly HealthLogRow[];
  trend: ReturnType<typeof weightTrend>;
  medications: readonly MedicationRow[];
  conditions: readonly ConditionRow[];
  visits30: readonly MedicalVisitRow[];
}) {
  const questions: ReportQuestion[] = [];

  if (args.symptoms30.length > 0) {
    questions.push({
      priority: "high",
      question: "최근 반복된 증상이 기존 질환이나 복약과 관련이 있을까요?",
      reason: args.symptoms30.slice(0, 3).map(logLabel).join(", "),
      source: "최근 30일 증상 기록",
    });
  }

  if (args.trend && Math.abs(args.trend.deltaPct) >= 5) {
    questions.push({
      priority: "high",
      question: "최근 체중 변화에 맞춰 식단, 운동량, 검사가 조정되어야 할까요?",
      reason: `${args.trend.previousWeightKg}kg에서 ${args.trend.currentWeightKg}kg로 ${args.trend.deltaPct}% 변화했습니다.`,
      source: "최근 체중 기록",
    });
  }

  if (args.medications.length > 0) {
    questions.push({
      priority: "medium",
      question: "현재 복용약의 용량, 복용 기간, 부작용 체크 포인트를 확인해 주세요.",
      reason: args.medications.slice(0, 4).map(medicationLabel).join(", "),
      source: "활성 복약 기록",
    });
  }

  if (args.conditions.length > 0) {
    questions.push({
      priority: "medium",
      question: "등록된 질환의 추적 검사 주기와 악화 신호는 무엇인가요?",
      reason: args.conditions
        .slice(0, 4)
        .map((condition) => condition.conditionName)
        .join(", "),
      source: "활성 질환 기록",
    });
  }

  const followUps = args.visits30.filter((visit) => visit.followUpDate);
  if (followUps.length > 0) {
    questions.push({
      priority: "medium",
      question: "이전 방문에서 잡힌 추적 일정과 이번 방문 목적이 맞게 이어지고 있나요?",
      reason: followUps
        .map((visit) => `${visit.hospitalName} ${formatDate(visit.followUpDate)}`)
        .join(", "),
      source: "최근 병원 방문",
    });
  }

  if (questions.length === 0) {
    questions.push({
      priority: "low",
      question: "현재 기록 기준으로 이번 방문에서 우선 확인해야 할 기본 검진 범위는 무엇인가요?",
      reason: "최근 변화 기록이 적어 기본 건강 상태 확인 질문을 우선 제안합니다.",
      source: "리포트 기본 질문",
    });
  }

  return questions.slice(0, 6);
}

function buildMissingRecords(args: {
  symptoms30: readonly HealthLogRow[];
  weights30: readonly HealthLogRow[];
  medications: readonly MedicationRow[];
  conditions: readonly ConditionRow[];
  visits: readonly MedicalVisitRow[];
}) {
  const missing: MissingRecord[] = [];
  if (args.symptoms30.length === 0) {
    missing.push({
      severity: "medium",
      title: "최근 30일 증상 기록 없음",
      reason: "기침, 가려움, 구토, 식욕 변화처럼 방문 사유와 연결되는 기록이 비어 있습니다.",
    });
  }
  if (args.weights30.length === 0) {
    missing.push({
      severity: "medium",
      title: "최근 30일 체중 기록 없음",
      reason: "체중 변화는 복약 용량, 식단, 관절 부담 판단에 자주 쓰입니다.",
    });
  }
  for (const medication of args.medications) {
    if (!textOrNull(medication.dosage) || !textOrNull(medication.frequencyText)) {
      missing.push({
        severity: "high",
        title: `${medication.medicationName} 복약 정보 보강 필요`,
        reason: "용량 또는 복용 주기가 비어 있어 진료 전 확인이 필요합니다.",
      });
    }
  }
  for (const condition of args.conditions) {
    if (!condition.severity || !condition.diagnosedOn) {
      missing.push({
        severity: "low",
        title: `${condition.conditionName} 질환 정보 보강 필요`,
        reason: "진단일 또는 중증도 기록이 비어 있어 추적 상담 근거가 약합니다.",
      });
    }
  }
  for (const visit of args.visits.slice(0, 3)) {
    if (!textOrNull(visit.diagnosis) || !textOrNull(visit.treatment)) {
      missing.push({
        severity: "low",
        title: `${formatDate(visit.visitDate)} 방문 결과 보강 필요`,
        reason: "진단 또는 처치 내용이 비어 있어 이전 진료 맥락을 설명하기 어렵습니다.",
      });
    }
  }
  if (missing.length === 0) {
    missing.push({
      severity: "low",
      title: "큰 누락 기록 없음",
      reason: "방문 전 증상 시작일과 사진 자료가 있으면 추가로 준비해 주세요.",
    });
  }
  return missing.slice(0, 8);
}

function renderSection(title: string, lines: readonly string[]) {
  return [`[${title}]`, ...lines.map((line) => `- ${line}`)].join("\n");
}

export async function buildVisitReport(tx: Tx, dogId: bigint, userId: bigint) {
  const now = new Date();
  const since30 = new Date(now.getTime() - 30 * dayMs);
  const since90 = new Date(now.getTime() - 90 * dayMs);

  const [dog, healthLogs, weights, medications, conditions, visits] =
    await Promise.all([
      tx.dog.findUniqueOrThrow({ where: { id: dogId } }),
      tx.healthLog.findMany({
        where: { dogId, recordedAt: { gte: since90 } },
        orderBy: { recordedAt: "desc" },
        take: 40,
      }),
      tx.healthLog.findMany({
        where: { dogId, logType: "weight", valueNumeric: { not: null } },
        orderBy: { recordedAt: "desc" },
        take: 12,
      }),
      tx.dogMedication.findMany({
        where: { dogId, isActive: true },
        orderBy: { startedOn: "desc" },
        take: 10,
      }),
      tx.dogCondition.findMany({
        where: { dogId, status: { in: ["active", "monitoring"] } },
        orderBy: { updatedAt: "desc" },
        take: 10,
      }),
      tx.medicalVisit.findMany({
        where: { dogId },
        orderBy: { visitDate: "desc" },
        take: 8,
      }),
    ]);

  const symptoms = healthLogs.filter((log) => log.logType === "symptom");
  const symptoms30 = symptoms.filter((log) => log.recordedAt >= since30);
  const weights30 = weights.filter((log) => log.recordedAt >= since30);
  const visits30 = visits.filter((visit) => visit.visitDate >= since30);
  const medications30 = medications.filter(
    (medication) => medication.startedOn && medication.startedOn >= since30,
  );
  const conditions30 = conditions.filter(
    (condition) => condition.diagnosedOn && condition.diagnosedOn >= since30,
  );
  const trend = weightTrend(weights30.length >= 2 ? weights30 : weights);

  const recentChanges = buildRecentChanges({
    symptoms30,
    weights30,
    visits30,
    medications30,
    conditions30,
  });
  const questionList = buildQuestions({
    symptoms30,
    trend,
    medications,
    conditions,
    visits30,
  });
  const missingRecords = buildMissingRecords({
    symptoms30,
    weights30,
    medications,
    conditions,
    visits,
  });

  const age = ageYears(dog.birthDate);
  const latestSymptoms = symptoms.slice(0, 5).map((log) => ({
    recordedAt: formatDate(log.recordedAt),
    title: textOrNull(log.title),
    memo: logLabel(log),
  }));
  const activeMedications = medications.map((medication) => ({
    name: medication.medicationName,
    dosage: textOrNull(medication.dosage),
    frequencyText: textOrNull(medication.frequencyText),
    startedOn: formatDate(medication.startedOn),
    notes: textOrNull(medication.notes),
    label: medicationLabel(medication),
  }));
  const activeConditions = conditions.map((condition) => ({
    type: condition.conditionType,
    name: condition.conditionName,
    severity: textOrNull(condition.severity),
    diagnosedOn: formatDate(condition.diagnosedOn),
    status: condition.status,
    notes: textOrNull(condition.notes),
  }));
  const recentVisits = visits.map((visit) => ({
    hospitalName: visit.hospitalName,
    veterinarianName: textOrNull(visit.veterinarianName),
    visitDate: formatDate(visit.visitDate),
    visitReason: textOrNull(visit.visitReason),
    symptoms: textOrNull(visit.symptoms),
    diagnosis: textOrNull(visit.diagnosis),
    treatment: textOrNull(visit.treatment),
    prescribedItems: textOrNull(visit.prescribedItems),
    followUpDate: formatDate(visit.followUpDate),
    notes: textOrNull(visit.notes),
    label: visitLabel(visit),
  }));

  const summary = {
    reportVersion: "vet_visit_summary_v2",
    generatedAt: now.toISOString(),
    dog: {
      name: dog.name,
      breed: dog.breed,
      ageYears: age,
      currentWeightKg: dog.currentWeightKg ? Number(dog.currentWeightKg) : null,
    },
    recent30Days: {
      windowStart: formatDate(since30),
      windowEnd: formatDate(now),
      symptomCount: symptoms30.length,
      visitCount: visits30.length,
      medicationStartCount: medications30.length,
      conditionStartCount: conditions30.length,
      weightTrend: trend,
      changes: recentChanges,
    },
    recentSymptoms: latestSymptoms,
    weightTrend: trend,
    activeMedications,
    conditions: activeConditions,
    recentVisits,
    questionList,
    missingRecords,
    share: {
      pdfStatus: "not_generated",
      pdfUrl: null,
      sharePath: null,
      suggestedFilename: `${dog.name}-visit-report-${formatDate(now)}.txt`,
      shareTextAvailable: true,
    },
  };

  const title = `${formatDate(now)} 병원 방문 리포트`;
  const renderedText = [
    `${dog.name} / ${dog.breed}${age !== null ? ` / ${age}세` : ""}`,
    renderSection(
      "진료 전 핵심 요약",
      [
        symptoms30.length
          ? `최근 30일 증상 ${symptoms30.length}건: ${symptoms30
              .slice(0, 3)
              .map(logLabel)
              .join(", ")}`
          : "최근 30일 증상 기록 없음",
        trend
          ? `체중 변화: ${trend.previousWeightKg}kg -> ${trend.currentWeightKg}kg (${trend.deltaPct}%)`
          : "체중 변화 판단에 충분한 기록 없음",
        visits30.length
          ? `최근 30일 병원 방문 ${visits30.length}회`
          : "최근 30일 병원 방문 기록 없음",
      ],
    ),
    renderSection(
      "수의사에게 물어볼 질문",
      questionList.map((item) => `${item.question} (${item.reason})`),
    ),
    renderSection(
      "복약/질환",
      [
        medications.length
          ? `복용약: ${activeMedications.map((item) => item.label).join(", ")}`
          : "현재 복용약 기록 없음",
        conditions.length
          ? `주의 정보: ${activeConditions.map((item) => item.name).join(", ")}`
          : "등록된 알레르기/기저질환 없음",
      ],
    ),
    renderSection(
      "최근 방문",
      recentVisits.length
        ? recentVisits.slice(0, 5).map((visit) => visit.label)
        : ["최근 병원 방문 기록 없음"],
    ),
    renderSection(
      "누락/확인 필요 기록",
      missingRecords.map((item) => `${item.title}: ${item.reason}`),
    ),
    visitReportNotice,
  ].join("\n\n");

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

export async function buildCatVisitReport(tx: Tx, catId: bigint, userId: bigint) {
  const now = new Date();
  const since30 = new Date(now.getTime() - 30 * dayMs);
  const since90 = new Date(now.getTime() - 90 * dayMs);

  const [cat, healthLogs, weights, medications, conditions, visits] =
    await Promise.all([
      tx.cat.findUniqueOrThrow({ where: { id: catId } }),
      tx.catHealthLog.findMany({
        where: { catId, recordedAt: { gte: since90 } },
        orderBy: { recordedAt: "desc" },
        take: 40,
      }),
      tx.catHealthLog.findMany({
        where: { catId, logType: "weight", valueNumeric: { not: null } },
        orderBy: { recordedAt: "desc" },
        take: 12,
      }),
      tx.catMedication.findMany({
        where: { catId, isActive: true },
        orderBy: { startedOn: "desc" },
        take: 10,
      }),
      tx.catCondition.findMany({
        where: { catId, status: { in: ["active", "monitoring"] } },
        orderBy: { updatedAt: "desc" },
        take: 10,
      }),
      tx.catMedicalVisit.findMany({
        where: { catId },
        orderBy: { visitDate: "desc" },
        take: 8,
      }),
    ]);

  const symptoms = healthLogs.filter((log) => log.logType === "symptom");
  const symptoms30 = symptoms.filter((log) => log.recordedAt >= since30);
  const weights30 = weights.filter((log) => log.recordedAt >= since30);
  const visits30 = visits.filter((visit) => visit.visitDate >= since30);
  const medications30 = medications.filter(
    (m) => m.startedOn && m.startedOn >= since30,
  );
  const conditions30 = conditions.filter(
    (c) => c.diagnosedOn && c.diagnosedOn >= since30,
  );
  const trend = weightTrend(weights30.length >= 2 ? weights30 : weights);

  const recentChanges = buildRecentChanges({ symptoms30, weights30, visits30, medications30, conditions30 });
  const questionList = buildQuestions({ symptoms30, trend, medications, conditions, visits30 });
  const missingRecords = buildMissingRecords({ symptoms30, weights30, medications, conditions, visits });

  const age = ageYears(cat.birthDate);
  const latestSymptoms = symptoms.slice(0, 5).map((log) => ({
    recordedAt: formatDate(log.recordedAt),
    title: textOrNull(log.title),
    memo: logLabel(log),
  }));
  const activeMedications = medications.map((m) => ({
    name: m.medicationName,
    dosage: textOrNull(m.dosage),
    frequencyText: textOrNull(m.frequencyText),
    startedOn: formatDate(m.startedOn),
    notes: textOrNull(m.notes),
    label: medicationLabel(m),
  }));
  const activeConditions = conditions.map((c) => ({
    type: c.conditionType,
    name: c.conditionName,
    severity: textOrNull(c.severity),
    diagnosedOn: formatDate(c.diagnosedOn),
    status: c.status,
    notes: textOrNull(c.notes),
  }));
  const recentVisits = visits.map((visit) => ({
    hospitalName: visit.hospitalName,
    veterinarianName: textOrNull(visit.veterinarianName),
    visitDate: formatDate(visit.visitDate),
    visitReason: textOrNull(visit.visitReason),
    symptoms: textOrNull(visit.symptoms),
    diagnosis: textOrNull(visit.diagnosis),
    treatment: textOrNull(visit.treatment),
    prescribedItems: textOrNull(visit.prescribedItems),
    followUpDate: formatDate(visit.followUpDate),
    notes: textOrNull(visit.notes),
    label: visitLabel(visit),
  }));

  const summary = {
    reportVersion: "cat_vet_visit_summary_v1",
    generatedAt: now.toISOString(),
    cat: {
      name: cat.name,
      breed: cat.breed,
      ageYears: age,
      currentWeightKg: cat.currentWeightKg ? Number(cat.currentWeightKg) : null,
    },
    recent30Days: {
      windowStart: formatDate(since30),
      windowEnd: formatDate(now),
      symptomCount: symptoms30.length,
      visitCount: visits30.length,
      medicationStartCount: medications30.length,
      conditionStartCount: conditions30.length,
      weightTrend: trend,
      changes: recentChanges,
    },
    recentSymptoms: latestSymptoms,
    weightTrend: trend,
    activeMedications,
    conditions: activeConditions,
    recentVisits,
    questionList,
    missingRecords,
    share: {
      pdfStatus: "not_generated",
      pdfUrl: null,
      sharePath: null,
      suggestedFilename: `${cat.name}-visit-report-${formatDate(now)}.txt`,
      shareTextAvailable: true,
    },
  };

  const title = `${formatDate(now)} 병원 방문 리포트`;
  const renderedText = [
    `${cat.name} / ${cat.breed}${age !== null ? ` / ${age}세` : ""}`,
    renderSection(
      "진료 전 핵심 요약",
      [
        symptoms30.length
          ? `최근 30일 증상 ${symptoms30.length}건: ${symptoms30.slice(0, 3).map(logLabel).join(", ")}`
          : "최근 30일 증상 기록 없음",
        trend
          ? `체중 변화: ${trend.previousWeightKg}kg -> ${trend.currentWeightKg}kg (${trend.deltaPct}%)`
          : "체중 변화 판단에 충분한 기록 없음",
        visits30.length
          ? `최근 30일 병원 방문 ${visits30.length}회`
          : "최근 30일 병원 방문 기록 없음",
      ],
    ),
    renderSection(
      "수의사에게 물어볼 질문",
      questionList.map((item) => `${item.question} (${item.reason})`),
    ),
    renderSection(
      "복약/질환",
      [
        medications.length
          ? `복용약: ${activeMedications.map((item) => item.label).join(", ")}`
          : "현재 복용약 기록 없음",
        conditions.length
          ? `주의 정보: ${activeConditions.map((item) => item.name).join(", ")}`
          : "등록된 알레르기/기저질환 없음",
      ],
    ),
    renderSection(
      "최근 방문",
      recentVisits.length
        ? recentVisits.slice(0, 5).map((visit) => visit.label)
        : ["최근 병원 방문 기록 없음"],
    ),
    renderSection(
      "누락/확인 필요 기록",
      missingRecords.map((item) => `${item.title}: ${item.reason}`),
    ),
    visitReportNotice,
  ].join("\n\n");

  return tx.catVisitReport.create({
    data: {
      catId,
      title,
      summaryJson: summary,
      renderedText,
      generatedBy: userId,
    },
  });
}
