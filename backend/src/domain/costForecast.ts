import type { Prisma, PrismaClient } from "@prisma/client";
import {
  resolveBreedProfile,
  sizeClassLabel,
} from "./costBreedProfiles.js";

type Tx = Prisma.TransactionClient | PrismaClient;

type ConfidenceLevel = "high" | "medium" | "low";

type DriverSection = "fixed" | "planned_care" | "risk_reserve";

type CostDriver = {
  section: DriverSection;
  label: string;
  monthlyImpact: number;
  reason: string;
};

type ForecastInsightKind = "attention" | "action" | "confidence";

type ForecastInsight = {
  kind: ForecastInsightKind;
  title: string;
  body: string;
  priority: number;
  monthlyImpact?: number;
};

type ExpenseRow = {
  expenseCategory: string;
  amount: Prisma.Decimal;
  expenseDate: Date;
};

type ForecastRow = {
  generatedAt: Date;
  monthlyEstimate: Prisma.Decimal;
};

type ExpenseStats = {
  count: number;
  monthsTracked: number;
  activeMonths: number;
  totalAmount: number;
  averageMonthly: number;
  positiveMedian: number;
  volatility: number;
};

type ForecastValidationDirection =
  | "none"
  | "matched"
  | "under_predicted"
  | "over_predicted"
  | "mixed";

type BiasCalibration = {
  factor: number;
  strength: number;
  evaluationCount: number;
  averagePredictedMonthly: number;
  averageActualMonthly: number;
  averageAbsoluteErrorPct: number;
  direction: ForecastValidationDirection;
};

type CostAxis =
  | "skin"
  | "dental"
  | "joint"
  | "cardiac"
  | "eye"
  | "airway"
  | "metabolic"
  | "weight"
  | "digestive"
  | "general";

type ExpenseGroup =
  | "fixed"
  | "routine_medical"
  | "event_medical"
  | "insurance"
  | "other";

type ExpenseRecurrence = "recurring" | "routine" | "event" | "optional";

type ExpenseCategoryMeta = {
  group: ExpenseGroup;
  label: string;
  recurrence: ExpenseRecurrence;
  outlierMultiplier: number;
  axis?: CostAxis;
};

type ClassifiedExpense = ExpenseRow & {
  amountNumber: number;
  meta: ExpenseCategoryMeta;
  isOutlier: boolean;
  isEventLike: boolean;
  axis: CostAxis | null;
};

type CategoryBreakdown = {
  category: string;
  label: string;
  group: ExpenseGroup;
  count: number;
  totalAmount: number;
  averageMonthly: number;
  outlierCount: number;
};

type ExpenseClassification = {
  classified: ClassifiedExpense[];
  fixedExpenses: ExpenseRow[];
  coreFixedExpenses: ExpenseRow[];
  insuranceExpenses: ExpenseRow[];
  routineMedicalExpenses: ExpenseRow[];
  eventMedicalExpenses: ExpenseRow[];
  medicalExpenses: ExpenseRow[];
  outlierExpenses: ClassifiedExpense[];
  categoryBreakdown: CategoryBreakdown[];
  axisExpenseMonthly: RiskAxisSummary[];
};

type RiskVectorEntry = {
  axis: CostAxis;
  label: string;
  plannedMonthly: number;
  reserveMonthly: number;
  source: "breed" | "condition" | "medication" | "expense_history" | "weight";
};

type RiskAxisSummary = {
  axis: CostAxis;
  label: string;
  plannedMonthly: number;
  reserveMonthly: number;
  totalMonthly: number;
  sources: string[];
};

type InsuranceModel = {
  status: string;
  enrolled: boolean;
  monthlyPremium: number;
  premiumSource: "observed_expense" | "status_default" | "none";
  annualObservedPremium: number;
  estimatedCoverageRate: number;
  reserveOffset: number;
  note: string;
};

const dayMs = 24 * 60 * 60 * 1000;
const monthMs = 30.4375 * dayMs;

const riskAxisLabels: Record<CostAxis, string> = {
  skin: "피부·귀",
  dental: "치과",
  joint: "관절",
  cardiac: "심장",
  eye: "안과",
  airway: "호흡기",
  metabolic: "대사·내분비",
  weight: "체중",
  digestive: "소화기",
  general: "일반 건강",
};

const expenseCategoryCatalog: Record<string, ExpenseCategoryMeta> = {
  food: {
    group: "fixed",
    label: "사료",
    recurrence: "recurring",
    outlierMultiplier: 4.5,
  },
  snack: {
    group: "fixed",
    label: "간식",
    recurrence: "recurring",
    outlierMultiplier: 4,
  },
  grooming: {
    group: "fixed",
    label: "미용",
    recurrence: "recurring",
    outlierMultiplier: 3.5,
    axis: "skin",
  },
  supplies: {
    group: "fixed",
    label: "용품",
    recurrence: "optional",
    outlierMultiplier: 4,
  },
  insurance: {
    group: "insurance",
    label: "보험",
    recurrence: "recurring",
    outlierMultiplier: 12,
  },
  medication: {
    group: "routine_medical",
    label: "복약",
    recurrence: "routine",
    outlierMultiplier: 3,
    axis: "general",
  },
  checkup: {
    group: "routine_medical",
    label: "검진",
    recurrence: "routine",
    outlierMultiplier: 3,
    axis: "general",
  },
  vaccine: {
    group: "routine_medical",
    label: "예방접종",
    recurrence: "routine",
    outlierMultiplier: 3,
    axis: "general",
  },
  prevention: {
    group: "routine_medical",
    label: "예방약",
    recurrence: "routine",
    outlierMultiplier: 3,
    axis: "general",
  },
  dental_care: {
    group: "routine_medical",
    label: "치과관리",
    recurrence: "routine",
    outlierMultiplier: 3,
    axis: "dental",
  },
  hospital: {
    group: "event_medical",
    label: "병원",
    recurrence: "event",
    outlierMultiplier: 2.5,
    axis: "general",
  },
  emergency: {
    group: "event_medical",
    label: "응급",
    recurrence: "event",
    outlierMultiplier: 2,
    axis: "general",
  },
  surgery: {
    group: "event_medical",
    label: "수술",
    recurrence: "event",
    outlierMultiplier: 1.8,
    axis: "general",
  },
  dental_treatment: {
    group: "event_medical",
    label: "치과치료",
    recurrence: "event",
    outlierMultiplier: 2,
    axis: "dental",
  },
  skin_treatment: {
    group: "event_medical",
    label: "피부·귀 치료",
    recurrence: "event",
    outlierMultiplier: 2.2,
    axis: "skin",
  },
  eye_treatment: {
    group: "event_medical",
    label: "안과치료",
    recurrence: "event",
    outlierMultiplier: 2.2,
    axis: "eye",
  },
  joint_treatment: {
    group: "event_medical",
    label: "관절치료",
    recurrence: "event",
    outlierMultiplier: 2.2,
    axis: "joint",
  },
  digestive_treatment: {
    group: "event_medical",
    label: "소화기치료",
    recurrence: "event",
    outlierMultiplier: 2.2,
    axis: "digestive",
  },
  other: {
    group: "other",
    label: "기타",
    recurrence: "optional",
    outlierMultiplier: 3,
  },
};

const recurringCostReference = {
  monthlyTotal: 161000,
  foodShare: 0.576,
  suppliesShare: 0.106,
  groomingShare: 0.087,
  source: {
    label: "KB 2025 반려동물 보고서 6화",
    url: "https://kbthink.com/investment/deepdive/research/250629-1.html",
  },
};

const treatmentCostReference = {
  averageTwoYearCost: 1027000,
  monthlyReserve: 1027000 / 24,
  source: {
    label: "KB 2025 반려동물 보고서 6화",
    url: "https://kbthink.com/investment/deepdive/research/250629-1.html",
  },
};

const internationalLongevityReference = {
  label: "Scientific Reports 2024 breed longevity",
  url: "https://www.nature.com/articles/s41598-023-50458-w",
};

const internationalLifeTableReference = {
  label: "Scientific Reports 2022 UK life tables",
  url: "https://www.nature.com/articles/s41598-022-10341-6",
};

const internationalInsuranceReference = {
  label: "Agria Breed Profiles",
  url: "https://www.agria.se/pressrum/statistik-om-djur-djurvard-och-djurhalsa/",
};

const weightHealthReference = {
  label: "AKC 체중 관리와 기대수명 가이드",
  url: "https://www.akc.org/expert-advice/health/general-health/how-long-do-dogs-live/",
};

function roundMoney(value: number) {
  return Math.max(0, Math.round(value / 1000) * 1000);
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function ageYears(birthDate: Date | null, now: Date) {
  if (!birthDate) return 3;
  return Math.max(0, (now.getTime() - birthDate.getTime()) / (365.25 * dayMs));
}

function averageRange([min, max]: readonly [number, number]) {
  return (min + max) / 2;
}

function ageStage(age: number) {
  if (age < 1) return "puppy";
  if (age >= 10) return "senior_plus";
  if (age >= 7) return "senior";
  return "adult";
}

function ageStageLabel(age: number) {
  return (
    {
      puppy: "성장기",
      adult: "성견기",
      senior: "시니어",
      senior_plus: "고령견",
    } as const
  )[ageStage(age)];
}

function agePlannedCareCost(age: number) {
  switch (ageStage(age)) {
    case "puppy":
      return 25000;
    case "senior_plus":
      return 22000;
    case "senior":
      return 14000;
    default:
      return 0;
  }
}

function ageRiskMultiplier(age: number) {
  switch (ageStage(age)) {
    case "puppy":
      return 1.05;
    case "senior_plus":
      return 1.35;
    case "senior":
      return 1.15;
    default:
      return 1.0;
  }
}

function recurringSizeMultiplier(weightKg: number) {
  if (weightKg <= 4) return 0.9;
  if (weightKg <= 8) return 1.0;
  if (weightKg <= 15) return 1.08;
  if (weightKg <= 25) return 1.18;
  return 1.32;
}

function monthKey(date: Date) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

function monthSpan(from: Date, to: Date) {
  return Math.max(
    1,
    (to.getUTCFullYear() - from.getUTCFullYear()) * 12 +
      (to.getUTCMonth() - from.getUTCMonth()) +
      1,
  );
}

function median(values: readonly number[]) {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) return sorted[middle] ?? 0;
  return ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2;
}

function stdDev(values: readonly number[]) {
  if (values.length <= 1) return 0;
  const mean = values.reduce((sum, value) => sum + value, 0) / values.length;
  const variance =
    values.reduce((sum, value) => sum + (value - mean) ** 2, 0) /
    values.length;
  return Math.sqrt(variance);
}

function categoryMeta(category: string): ExpenseCategoryMeta {
  return (
    expenseCategoryCatalog[category] ?? {
      group: "event_medical",
      label: category || "기타 진료",
      recurrence: "event",
      outlierMultiplier: 2.5,
      axis: "general",
    }
  );
}

function isFixedMeta(meta: ExpenseCategoryMeta) {
  return meta.group === "fixed" || meta.group === "insurance";
}

function isMedicalMeta(meta: ExpenseCategoryMeta) {
  return meta.group === "routine_medical" || meta.group === "event_medical";
}

function buildCategoryBreakdown(
  classified: readonly ClassifiedExpense[],
  now: Date,
): CategoryBreakdown[] {
  const oldest = classified.reduce<Date | null>(
    (currentOldest, expense) =>
      !currentOldest || expense.expenseDate < currentOldest
        ? expense.expenseDate
        : currentOldest,
    null,
  );
  const monthsTracked = oldest ? monthSpan(oldest, now) : 1;
  const byCategory = new Map<string, CategoryBreakdown>();

  for (const expense of classified) {
    const current =
      byCategory.get(expense.expenseCategory) ??
      ({
        category: expense.expenseCategory,
        label: expense.meta.label,
        group: expense.meta.group,
        count: 0,
        totalAmount: 0,
        averageMonthly: 0,
        outlierCount: 0,
      } satisfies CategoryBreakdown);
    current.count += 1;
    current.totalAmount += expense.amountNumber;
    if (expense.isOutlier) current.outlierCount += 1;
    byCategory.set(expense.expenseCategory, current);
  }

  return [...byCategory.values()]
    .map((item) => ({
      ...item,
      totalAmount: roundMoney(item.totalAmount),
      averageMonthly: roundMoney(item.totalAmount / monthsTracked),
    }))
    .sort((left, right) => right.totalAmount - left.totalAmount);
}

function summarizeAxisExpenses(
  classified: readonly ClassifiedExpense[],
  now: Date,
): RiskAxisSummary[] {
  const oldest = classified.reduce<Date | null>(
    (currentOldest, expense) =>
      !currentOldest || expense.expenseDate < currentOldest
        ? expense.expenseDate
        : currentOldest,
    null,
  );
  const monthsTracked = oldest ? monthSpan(oldest, now) : 1;
  const byAxis = new Map<CostAxis, RiskAxisSummary>();

  for (const expense of classified) {
    if (!expense.axis || !isMedicalMeta(expense.meta)) continue;
    const current =
      byAxis.get(expense.axis) ??
      ({
        axis: expense.axis,
        label: riskAxisLabels[expense.axis],
        plannedMonthly: 0,
        reserveMonthly: 0,
        totalMonthly: 0,
        sources: [],
      } satisfies RiskAxisSummary);
    const monthly = expense.amountNumber / monthsTracked;
    if (expense.meta.group === "routine_medical" && !expense.isOutlier) {
      current.plannedMonthly += monthly;
    } else {
      current.reserveMonthly += monthly;
    }
    if (!current.sources.includes("expense_history")) {
      current.sources.push("expense_history");
    }
    byAxis.set(expense.axis, current);
  }

  return [...byAxis.values()]
    .map((item) => ({
      ...item,
      plannedMonthly: roundMoney(item.plannedMonthly),
      reserveMonthly: roundMoney(item.reserveMonthly),
      totalMonthly: roundMoney(item.plannedMonthly + item.reserveMonthly),
    }))
    .filter((item) => item.totalMonthly > 0)
    .sort((left, right) => right.totalMonthly - left.totalMonthly);
}

function classifyExpenses(
  expenses: readonly ExpenseRow[],
  now: Date,
): ExpenseClassification {
  const positiveAmountsByCategory = new Map<string, number[]>();
  for (const expense of expenses) {
    const amount = Number(expense.amount);
    if (amount <= 0) continue;
    const values = positiveAmountsByCategory.get(expense.expenseCategory) ?? [];
    values.push(amount);
    positiveAmountsByCategory.set(expense.expenseCategory, values);
  }

  const classified = expenses.map((expense): ClassifiedExpense => {
    const amountNumber = Number(expense.amount);
    const meta = categoryMeta(expense.expenseCategory);
    const categoryAmounts =
      positiveAmountsByCategory.get(expense.expenseCategory) ?? [];
    const categoryMedian = median(categoryAmounts);
    const minimumThreshold =
      meta.group === "insurance"
        ? 360000
        : meta.group === "event_medical"
          ? 180000
          : 150000;
    const outlierThreshold =
      categoryAmounts.length >= 3 && categoryMedian > 0
        ? Math.max(
            minimumThreshold,
            categoryMedian * meta.outlierMultiplier,
          )
        : minimumThreshold;
    const isOutlier =
      amountNumber > 0 &&
      amountNumber > outlierThreshold &&
      meta.group !== "insurance";
    const isEventLike = meta.group === "event_medical" || isOutlier;

    return {
      ...expense,
      amountNumber,
      meta,
      isOutlier,
      isEventLike,
      axis: meta.axis ?? null,
    };
  });

  const fixedExpenses = classified
    .filter((expense) => isFixedMeta(expense.meta) && !expense.isOutlier)
    .map((expense) => expense as ExpenseRow);
  const coreFixedExpenses = classified
    .filter(
      (expense) => expense.meta.group === "fixed" && !expense.isOutlier,
    )
    .map((expense) => expense as ExpenseRow);
  const insuranceExpenses = classified
    .filter((expense) => expense.meta.group === "insurance")
    .map((expense) => expense as ExpenseRow);
  const routineMedicalExpenses = classified
    .filter(
      (expense) =>
        expense.meta.group === "routine_medical" && !expense.isOutlier,
    )
    .map((expense) => expense as ExpenseRow);
  const eventMedicalExpenses = classified
    .filter(
      (expense) =>
        isMedicalMeta(expense.meta) &&
        (expense.meta.group === "event_medical" || expense.isOutlier),
    )
    .map((expense) => expense as ExpenseRow);
  const medicalExpenses = classified
    .filter((expense) => isMedicalMeta(expense.meta))
    .map((expense) => expense as ExpenseRow);
  const outlierExpenses = classified.filter((expense) => expense.isOutlier);

  return {
    classified,
    fixedExpenses,
    coreFixedExpenses,
    insuranceExpenses,
    routineMedicalExpenses,
    eventMedicalExpenses,
    medicalExpenses,
    outlierExpenses,
    categoryBreakdown: buildCategoryBreakdown(classified, now),
    axisExpenseMonthly: summarizeAxisExpenses(classified, now),
  };
}

function buildExpenseStats(
  expenses: readonly ExpenseRow[],
  now: Date,
  lookbackDays: number,
): ExpenseStats {
  const since = new Date(now.getTime() - lookbackDays * dayMs);
  const scoped = expenses.filter((expense) => expense.expenseDate >= since);
  if (scoped.length === 0) {
    return {
      count: 0,
      monthsTracked: 0,
      activeMonths: 0,
      totalAmount: 0,
      averageMonthly: 0,
      positiveMedian: 0,
      volatility: 0,
    };
  }

  const totalsByMonth = new Map<string, number>();
  let oldest = scoped[0]!.expenseDate;
  let totalAmount = 0;
  for (const expense of scoped) {
    const amount = Number(expense.amount);
    const key = monthKey(expense.expenseDate);
    totalsByMonth.set(key, (totalsByMonth.get(key) ?? 0) + amount);
    totalAmount += amount;
    if (expense.expenseDate < oldest) oldest = expense.expenseDate;
  }

  const monthsTracked = Math.min(
    Math.ceil(lookbackDays / 30),
    monthSpan(oldest, now),
  );
  const monthTotals = [...totalsByMonth.values()];
  const averageMonthly = totalAmount / Math.max(1, monthsTracked);
  const positiveMonths = monthTotals.filter((value) => value > 0);

  return {
    count: scoped.length,
    monthsTracked,
    activeMonths: totalsByMonth.size,
    totalAmount,
    averageMonthly,
    positiveMedian: median(positiveMonths),
    volatility:
      averageMonthly > 0 ? stdDev(monthTotals) / averageMonthly : 0,
  };
}

function weightedRecentAverage(
  recentValue: number,
  baselineValue: number,
  recentWeight: number,
) {
  if (recentValue > 0 && baselineValue > 0) {
    return recentValue * recentWeight + baselineValue * (1 - recentWeight);
  }
  if (recentValue > 0) return recentValue;
  return baselineValue;
}

function historyBlendWeight(args: {
  stats: ExpenseStats;
  transactionCount: number;
  targetActiveMonths: number;
  maxWeight: number;
}) {
  const { stats, transactionCount, targetActiveMonths, maxWeight } = args;
  if (stats.count === 0) return 0;
  const activeMonthScore = clamp(
    stats.activeMonths / targetActiveMonths,
    0,
    1,
  );
  const trackedMonthScore = clamp(
    stats.monthsTracked / targetActiveMonths,
    0,
    1,
  );
  const transactionScore = clamp(
    transactionCount / (targetActiveMonths * 1.5),
    0,
    1,
  );
  return clamp(
    (activeMonthScore * 0.45 +
      trackedMonthScore * 0.2 +
      transactionScore * 0.35) *
      maxWeight,
    0,
    maxWeight,
  );
}

function medicalRoutineShare(
  volatility: number,
  activeMonths: number,
  recentVisitCount: number,
) {
  let share = 0.7;
  if (volatility >= 1.2) {
    share = 0.38;
  } else if (volatility > 0.35) {
    const progress = (volatility - 0.35) / (1.2 - 0.35);
    share = 0.7 - progress * 0.32;
  }
  if (activeMonths <= 1) share -= 0.08;
  if (recentVisitCount >= 2) share -= 0.05;
  return clamp(share, 0.35, 0.75);
}

function blendModeledWithHistory(args: {
  modeled: number;
  actual: number;
  weight: number;
  minRatio: number;
  maxRatio: number;
}) {
  const { modeled, actual, weight, minRatio, maxRatio } = args;
  if (modeled <= 0 || actual <= 0 || weight <= 0) return roundMoney(modeled);
  const clampedActual = clamp(actual, modeled * minRatio, modeled * maxRatio);
  return roundMoney(modeled * (1 - weight) + clampedActual * weight);
}

function dedupeSources(
  sources: readonly { label: string; url: string }[],
) {
  const unique = new Map<string, { label: string; url: string }>();
  for (const source of sources) {
    if (!unique.has(source.url)) {
      unique.set(source.url, { label: source.label, url: source.url });
    }
  }
  return [...unique.values()];
}

function axisForText(value: string | null | undefined): CostAxis {
  const text = (value ?? "").toLowerCase();
  if (
    text.includes("skin") ||
    text.includes("ear") ||
    text.includes("coat") ||
    text.includes("allergy") ||
    text.includes("피부") ||
    text.includes("귀") ||
    text.includes("알레르")
  ) {
    return "skin";
  }
  if (text.includes("dental") || text.includes("tooth") || text.includes("치")) {
    return "dental";
  }
  if (
    text.includes("orthopedic") ||
    text.includes("patella") ||
    text.includes("joint") ||
    text.includes("관절") ||
    text.includes("슬개")
  ) {
    return "joint";
  }
  if (text.includes("cardiac") || text.includes("heart") || text.includes("심장")) {
    return "cardiac";
  }
  if (text.includes("eye") || text.includes("안과") || text.includes("눈")) {
    return "eye";
  }
  if (
    text.includes("airway") ||
    text.includes("trachea") ||
    text.includes("breath") ||
    text.includes("호흡") ||
    text.includes("기관")
  ) {
    return "airway";
  }
  if (
    text.includes("liver") ||
    text.includes("thyroid") ||
    text.includes("endocrine") ||
    text.includes("metabolic") ||
    text.includes("간") ||
    text.includes("갑상선") ||
    text.includes("대사") ||
    text.includes("내분비")
  ) {
    return "metabolic";
  }
  if (
    text.includes("weight") ||
    text.includes("obesity") ||
    text.includes("비만") ||
    text.includes("체중")
  ) {
    return "weight";
  }
  if (
    text.includes("digest") ||
    text.includes("gi") ||
    text.includes("stomach") ||
    text.includes("소화") ||
    text.includes("위장")
  ) {
    return "digestive";
  }
  return "general";
}

function conditionRiskWeight(condition: {
  conditionType: string;
  severity?: string | null;
}) {
  const severity = (condition.severity ?? "").toLowerCase();
  const type = condition.conditionType.toLowerCase();
  let multiplier = 1;
  if (severity === "high" || severity === "severe") multiplier += 0.35;
  if (severity === "low" || severity === "mild") multiplier -= 0.15;
  if (type === "chronic") multiplier += 0.35;
  if (type === "allergy") multiplier += 0.1;
  return clamp(multiplier, 0.75, 1.6);
}

function addRiskEntry(
  entries: RiskVectorEntry[],
  entry: RiskVectorEntry,
) {
  entries.push({
    ...entry,
    plannedMonthly: roundMoney(entry.plannedMonthly),
    reserveMonthly: roundMoney(entry.reserveMonthly),
  });
}

function summarizeRiskVector(
  entries: readonly RiskVectorEntry[],
): RiskAxisSummary[] {
  const byAxis = new Map<CostAxis, RiskAxisSummary>();
  for (const entry of entries) {
    const current =
      byAxis.get(entry.axis) ??
      ({
        axis: entry.axis,
        label: riskAxisLabels[entry.axis],
        plannedMonthly: 0,
        reserveMonthly: 0,
        totalMonthly: 0,
        sources: [],
      } satisfies RiskAxisSummary);
    current.plannedMonthly += entry.plannedMonthly;
    current.reserveMonthly += entry.reserveMonthly;
    if (!current.sources.includes(entry.source)) {
      current.sources.push(entry.source);
    }
    byAxis.set(entry.axis, current);
  }

  return [...byAxis.values()]
    .map((item) => ({
      ...item,
      plannedMonthly: roundMoney(item.plannedMonthly),
      reserveMonthly: roundMoney(item.reserveMonthly),
      totalMonthly: roundMoney(item.plannedMonthly + item.reserveMonthly),
    }))
    .filter((item) => item.totalMonthly > 0)
    .sort((left, right) => right.totalMonthly - left.totalMonthly);
}

function buildRiskVector(args: {
  breedRiskFactors: readonly {
    key: string;
    label: string;
    plannedCareMonthly: number;
    reserveMonthly: number;
  }[];
  conditions: readonly {
    conditionType: string;
    conditionName?: string | null;
    severity?: string | null;
  }[];
  medications: readonly { medicationName: string }[];
  axisExpenseMonthly: readonly RiskAxisSummary[];
  isOverweight: boolean;
}) {
  const entries: RiskVectorEntry[] = [];

  for (const factor of args.breedRiskFactors) {
    addRiskEntry(entries, {
      axis: axisForText(`${factor.key} ${factor.label}`),
      label: factor.label,
      plannedMonthly: factor.plannedCareMonthly,
      reserveMonthly: factor.reserveMonthly,
      source: "breed",
    });
  }

  for (const condition of args.conditions) {
    const weight = conditionRiskWeight(condition);
    addRiskEntry(entries, {
      axis: axisForText(
        `${condition.conditionType} ${condition.conditionName ?? ""}`,
      ),
      label: condition.conditionName ?? condition.conditionType,
      plannedMonthly: 5000 * weight,
      reserveMonthly: 6500 * weight,
      source: "condition",
    });
  }

  for (const medication of args.medications) {
    addRiskEntry(entries, {
      axis: axisForText(medication.medicationName),
      label: medication.medicationName,
      plannedMonthly: 4000,
      reserveMonthly: 2500,
      source: "medication",
    });
  }

  for (const axisExpense of args.axisExpenseMonthly) {
    addRiskEntry(entries, {
      axis: axisExpense.axis,
      label: `${axisExpense.label} 지출 이력`,
      plannedMonthly: clamp(axisExpense.plannedMonthly * 0.25, 0, 18000),
      reserveMonthly: clamp(axisExpense.reserveMonthly * 0.35, 0, 26000),
      source: "expense_history",
    });
  }

  if (args.isOverweight) {
    addRiskEntry(entries, {
      axis: "weight",
      label: "현재 체중 초과",
      plannedMonthly: 10000,
      reserveMonthly: 12000,
      source: "weight",
    });
  }

  const topAxes = summarizeRiskVector(entries).slice(0, 5);
  return { entries, topAxes };
}

function hasInsuranceStatus(status: string | null | undefined) {
  return ["enrolled", "covered", "active", "insured", "yes"].includes(
    (status ?? "").toLowerCase(),
  );
}

function buildInsuranceModel(args: {
  status: string | null | undefined;
  insuranceExpenses: readonly ExpenseRow[];
  riskReserveBeforeInsurance: number;
}): InsuranceModel {
  const annualObservedPremium = args.insuranceExpenses.reduce(
    (sum, expense) => sum + Number(expense.amount),
    0,
  );
  const observedMonthlyPremium =
    annualObservedPremium > 0 ? roundMoney(annualObservedPremium / 12) : 0;
  const enrolled =
    hasInsuranceStatus(args.status) || observedMonthlyPremium > 0;
  const premiumSource =
    observedMonthlyPremium > 0
      ? "observed_expense"
      : enrolled
        ? "status_default"
        : "none";
  const monthlyPremium =
    premiumSource === "observed_expense"
      ? roundMoney(clamp(observedMonthlyPremium, 10000, 120000))
      : enrolled
        ? 40000
        : 0;
  const estimatedCoverageRate = enrolled ? 0.45 : 0;
  const reserveOffset =
    enrolled && args.riskReserveBeforeInsurance > 0
      ? -roundMoney(
          clamp(args.riskReserveBeforeInsurance * 0.12, 5000, 18000),
        )
      : 0;

  return {
    status: args.status ?? "none",
    enrolled,
    monthlyPremium,
    premiumSource,
    annualObservedPremium: roundMoney(annualObservedPremium),
    estimatedCoverageRate,
    reserveOffset,
    note: enrolled
      ? "보험료는 고정비에 넣고, 보장 효과는 돌발진료 예비비를 완만하게 낮추는 정도로만 반영합니다."
      : "보험 미가입 또는 보험료 기록 없음으로 보장 효과를 예비비에서 차감하지 않습니다.",
  };
}

function sortDrivers(drivers: readonly CostDriver[]) {
  return [...drivers]
    .filter((driver) => driver.monthlyImpact > 0)
    .sort((left, right) => right.monthlyImpact - left.monthlyImpact);
}

function driverSectionLabel(section: DriverSection) {
  switch (section) {
    case "fixed":
      return "고정비";
    case "planned_care":
      return "예방관리비";
    case "risk_reserve":
      return "돌발진료 예비비";
  }
}

function buildForecastInsights(args: {
  drivers: readonly CostDriver[];
  confidenceLevel: ConfidenceLevel;
  fixedHistoryWeight: number;
  medicalHistoryWeight: number;
  forecastBias: BiasCalibration;
  isOverweight: boolean;
  activeConditionCount: number;
  activeMedicationCount: number;
  recentVisitCount: number;
  recentExpenseCount: number;
  medicalVolatility: number;
  riskVectorTopAxes: readonly RiskAxisSummary[];
  outlierCount: number;
  outlierReserveMonthly: number;
  insuranceModel: InsuranceModel;
}): ForecastInsight[] {
  const insights: ForecastInsight[] = [];
  const topDriver = args.drivers[0];

  if (topDriver) {
    insights.push({
      kind: "attention",
      title: `가장 큰 비용 요인은 ${topDriver.label}입니다`,
      body: `${driverSectionLabel(topDriver.section)}에서 월 ${roundMoney(topDriver.monthlyImpact).toLocaleString("ko-KR")}원 정도 영향을 줍니다. ${topDriver.reason}`,
      priority: 1,
      monthlyImpact: roundMoney(topDriver.monthlyImpact),
    });
  }

  if (
    args.confidenceLevel === "low" ||
    (args.fixedHistoryWeight < 0.28 && args.medicalHistoryWeight < 0.22)
  ) {
    insights.push({
      kind: "confidence",
      title: "지출 기록이 더 쌓이면 예측 정확도가 올라갑니다",
      body:
        args.recentExpenseCount < 6
          ? "최근 1년 지출 기록이 아직 적어 견종 기본값 비중이 큽니다. 사료, 병원, 미용, 용품 지출을 몇 번 더 입력하면 개인화 비중이 높아집니다."
          : "기록은 있지만 반복 패턴이 아직 뚜렷하지 않습니다. 같은 카테고리를 꾸준히 입력하면 월별 예측 폭이 줄어듭니다.",
      priority: 2,
    });
  } else if (args.forecastBias.evaluationCount > 0) {
    insights.push({
      kind: "confidence",
      title: "이전 예측과 실제 지출 차이를 보정했습니다",
      body: `비교 가능한 이전 예측 ${args.forecastBias.evaluationCount}건을 실제 지출과 대조해 현재 변수비용에 약 ${Math.round(args.forecastBias.factor * 100)}% 보정 계수를 반영했습니다. 평균 오차는 약 ${Math.round(args.forecastBias.averageAbsoluteErrorPct)}%입니다.`,
      priority: 2,
    });
  }

  if (args.isOverweight) {
    insights.push({
      kind: "action",
      title: "체중 관리 기록을 우선 확인하세요",
      body: "현재 체중이 목표 체중보다 높아 예방관리비와 돌발진료 예비비가 함께 올라갔습니다. 체중 기록과 식이 관련 지출을 같이 남기면 다음 예측이 더 현실적으로 조정됩니다.",
      priority: 3,
    });
  } else if (args.activeConditionCount > 0 || args.activeMedicationCount > 0) {
    insights.push({
      kind: "action",
      title: "질환과 복약 기록이 예측을 움직이고 있습니다",
      body: `활성 질환 ${args.activeConditionCount}건, 복약 ${args.activeMedicationCount}건이 예방관리비와 예비비에 반영됐습니다. 증상 변화와 복약 종료 여부를 최신 상태로 유지하는 것이 중요합니다.`,
      priority: 3,
    });
  } else if (args.recentVisitCount >= 2 || args.medicalVolatility >= 1) {
    insights.push({
      kind: "action",
      title: "병원비 변동성을 따로 봐야 합니다",
      body: "최근 병원 방문이나 의료비 변동성이 높아 돌발진료 예비비가 커졌습니다. 반복 검진인지 일회성 치료인지 구분해 기록하면 예비비가 과하게 유지되는 것을 줄일 수 있습니다.",
      priority: 3,
    });
  }

  if (args.outlierCount > 0) {
    insights.push({
      kind: "attention",
      title: "큰 일회성 지출은 반복비에서 분리했습니다",
      body: `수술·응급·고액 진료처럼 반복 지출로 보기 어려운 항목 ${args.outlierCount}건은 월 고정 패턴을 왜곡하지 않도록 예비비 쪽으로 완만하게 나눠 반영했습니다.`,
      priority: 3,
      monthlyImpact: roundMoney(args.outlierReserveMonthly),
    });
  }

  const topRiskAxis = args.riskVectorTopAxes[0];
  if (topRiskAxis && topRiskAxis.totalMonthly >= 12000) {
    insights.push({
      kind: "action",
      title: `${topRiskAxis.label} 리스크 축을 우선 관리하세요`,
      body: `견종, 질환, 복약, 지출 이력을 같은 축으로 묶어 보면 ${topRiskAxis.label} 항목이 월 ${topRiskAxis.totalMonthly.toLocaleString("ko-KR")}원 규모로 가장 큽니다.`,
      priority: 4,
      monthlyImpact: topRiskAxis.totalMonthly,
    });
  }

  if (args.insuranceModel.enrolled) {
    insights.push({
      kind: "confidence",
      title: "보험료와 보장 효과를 분리해서 반영했습니다",
      body: `보험료 월 ${args.insuranceModel.monthlyPremium.toLocaleString("ko-KR")}원은 고정비에 넣고, 보장 효과는 돌발진료 예비비에서 ${Math.abs(args.insuranceModel.reserveOffset).toLocaleString("ko-KR")}원만 완만하게 차감했습니다.`,
      priority: 4,
    });
  } else if (topRiskAxis && topRiskAxis.reserveMonthly >= 25000) {
    insights.push({
      kind: "action",
      title: "보험 여부를 입력하면 병원비 해석이 더 선명해집니다",
      body: "현재는 보험 보장 효과 없이 돌발진료 예비비를 계산했습니다. 보험 상태와 실제 보험료를 기록하면 고정비와 위험 예비비를 분리해 볼 수 있습니다.",
      priority: 4,
    });
  }

  if (insights.length < 3) {
    insights.push({
      kind: "action",
      title: "다음 입력은 지출 카테고리를 정확히 나누는 것이 좋습니다",
      body: "사료·간식·미용·보험·용품은 고정비로, 검진·복약은 반복 의료비로, 응급·수술·치료는 돌발 예비비로 분리됩니다. 카테고리가 정확할수록 비용 해석이 선명해집니다.",
      priority: 4,
    });
  }

  return insights
    .sort((left, right) => left.priority - right.priority)
    .slice(0, 3);
}

function pickSpacedForecasts(rows: readonly ForecastRow[]) {
  const selected: ForecastRow[] = [];
  for (const row of rows) {
    const latest = selected[selected.length - 1];
    if (
      latest &&
      latest.generatedAt.getTime() - row.generatedAt.getTime() < 21 * dayMs
    ) {
      continue;
    }
    selected.push(row);
    if (selected.length >= 5) break;
  }
  return selected;
}

function evaluateForecastBias(args: {
  forecasts: readonly ForecastRow[];
  expenses: readonly ExpenseRow[];
  now: Date;
}) {
  const { forecasts, expenses, now } = args;
  const eligible = forecasts.filter(
    (row) => now.getTime() - row.generatedAt.getTime() >= 30 * dayMs,
  );
  const selected = pickSpacedForecasts(eligible);
  if (selected.length === 0) {
    return {
      factor: 1,
      strength: 0,
      evaluationCount: 0,
      averagePredictedMonthly: 0,
      averageActualMonthly: 0,
      averageAbsoluteErrorPct: 0,
      direction: "none",
    } satisfies BiasCalibration;
  }

  const ratios: number[] = [];
  const absoluteErrors: number[] = [];
  const directions: ForecastValidationDirection[] = [];
  const predictedMonthlyValues: number[] = [];
  const actualMonthlyValues: number[] = [];

  for (const forecast of selected) {
    const windowStart = forecast.generatedAt;
    const windowEnd = new Date(
      Math.min(now.getTime(), forecast.generatedAt.getTime() + 60 * dayMs),
    );
    const windowExpenses = expenses.filter(
      (expense) =>
        expense.expenseDate >= windowStart && expense.expenseDate < windowEnd,
    );
    if (windowExpenses.length === 0) continue;

    const daysObserved = Math.max(
      1,
      (windowEnd.getTime() - windowStart.getTime()) / dayMs,
    );
    const actualMonthly =
      windowExpenses.reduce((sum, expense) => sum + Number(expense.amount), 0) /
      (daysObserved / 30.4375);
    const predictedMonthly = Number(forecast.monthlyEstimate);
    if (actualMonthly <= 0 || predictedMonthly <= 0) continue;

    const actualToPredicted = actualMonthly / predictedMonthly;
    ratios.push(clamp(actualToPredicted, 0.72, 1.35));
    absoluteErrors.push(
      Math.abs(actualMonthly - predictedMonthly) / predictedMonthly,
    );
    if (actualToPredicted > 1.08) {
      directions.push("under_predicted");
    } else if (actualToPredicted < 0.92) {
      directions.push("over_predicted");
    } else {
      directions.push("matched");
    }
    predictedMonthlyValues.push(predictedMonthly);
    actualMonthlyValues.push(actualMonthly);
  }

  if (ratios.length === 0) {
    return {
      factor: 1,
      strength: 0,
      evaluationCount: 0,
      averagePredictedMonthly: 0,
      averageActualMonthly: 0,
      averageAbsoluteErrorPct: 0,
      direction: "none",
    } satisfies BiasCalibration;
  }

  const meaningfulDirections = directions.filter(
    (direction) => direction !== "matched",
  );
  const uniqueDirections = new Set(meaningfulDirections);
  const direction =
    uniqueDirections.size > 1
      ? "mixed"
      : (meaningfulDirections[0] ?? "matched");

  return {
    factor: median(ratios),
    strength: Math.min(0.28, ratios.length * 0.07),
    evaluationCount: ratios.length,
    averagePredictedMonthly:
      predictedMonthlyValues.reduce((sum, value) => sum + value, 0) /
      predictedMonthlyValues.length,
    averageActualMonthly:
      actualMonthlyValues.reduce((sum, value) => sum + value, 0) /
      actualMonthlyValues.length,
    averageAbsoluteErrorPct:
      (absoluteErrors.reduce((sum, value) => sum + value, 0) /
        absoluteErrors.length) *
      100,
    direction,
  } satisfies BiasCalibration;
}

function confidenceLevelFor(args: {
  fixedHistoryWeight: number;
  medicalHistoryWeight: number;
  biasEvaluationCount: number;
  breedMatchedExactly: boolean;
}) {
  const {
    fixedHistoryWeight,
    medicalHistoryWeight,
    biasEvaluationCount,
    breedMatchedExactly,
  } = args;
  if (
    fixedHistoryWeight >= 0.55 &&
    medicalHistoryWeight >= 0.45 &&
    (biasEvaluationCount >= 2 || breedMatchedExactly)
  ) {
    return "high" satisfies ConfidenceLevel;
  }
  if (
    fixedHistoryWeight >= 0.28 ||
    medicalHistoryWeight >= 0.22 ||
    biasEvaluationCount >= 1
  ) {
    return "medium" satisfies ConfidenceLevel;
  }
  return "low" satisfies ConfidenceLevel;
}

function rangeSpread(args: {
  confidenceLevel: ConfidenceLevel;
  medicalVolatility: number;
  biasEvaluationCount: number;
}) {
  const { confidenceLevel, medicalVolatility, biasEvaluationCount } = args;
  const base =
    confidenceLevel === "high"
      ? 0.1
      : confidenceLevel === "medium"
        ? 0.14
        : 0.18;
  const volatilityAdjustment = medicalVolatility >= 1.1 ? 0.02 : 0;
  const calibrationReduction = biasEvaluationCount >= 2 ? 0.01 : 0;
  return clamp(base + volatilityAdjustment - calibrationReduction, 0.08, 0.22);
}

export async function recalculateCostForecasts(tx: Tx, dogId: bigint) {
  const now = new Date();
  const recentSince = new Date(now.getTime() - 90 * dayMs);
  const annualSince = new Date(now.getTime() - 365 * dayMs);

  const [dog, conditions, medications, expenses, visits, priorForecasts] =
    await Promise.all([
      tx.dog.findUniqueOrThrow({ where: { id: dogId } }),
      tx.dogCondition.findMany({
        where: { dogId, status: { in: ["active", "monitoring"] } },
      }),
      tx.dogMedication.findMany({ where: { dogId, isActive: true } }),
      tx.expense.findMany({
        where: { dogId, expenseDate: { gte: annualSince } },
        orderBy: { expenseDate: "asc" },
      }),
      tx.medicalVisit.findMany({
        where: { dogId, visitDate: { gte: annualSince } },
        orderBy: { visitDate: "asc" },
        select: { visitDate: true },
      }),
      tx.costForecast.findMany({
        where: {
          dogId,
          scenario: "basic",
          generatedAt: { lt: now },
        },
        orderBy: { generatedAt: "desc" },
        take: 18,
        select: {
          generatedAt: true,
          monthlyEstimate: true,
        },
      }),
    ]);

  const dogAge = ageYears(dog.birthDate, now);
  const weightKg = Number(dog.currentWeightKg ?? 5);
  const targetWeightKg = Number(dog.targetWeightKg ?? dog.currentWeightKg ?? 0);
  const isOverweight =
    targetWeightKg > 0 && weightKg > targetWeightKg * 1.08;

  const breed = resolveBreedProfile(dog.breed, weightKg);
  const breedMatchedExactly = breed.matchType === "exact";
  const lifespanYears = averageRange(breed.profile.expectedLifespanYears);
  const remainingLifetimeYears = Math.max(1, lifespanYears - dogAge);

  const recentVisitCount = visits.filter(
    (visit) => visit.visitDate >= recentSince,
  ).length;
  const annualVisitCount = visits.length;

  const expenseClassification = classifyExpenses(expenses, now);
  const fixedExpenses = expenseClassification.coreFixedExpenses;
  const insuranceExpenses = expenseClassification.insuranceExpenses;
  const routineMedicalExpenses =
    expenseClassification.routineMedicalExpenses;
  const eventMedicalExpenses = expenseClassification.eventMedicalExpenses;
  const medicalExpenses = expenseClassification.medicalExpenses;
  const baselineExpenses = expenseClassification.classified
    .filter((expense) => !expense.isOutlier)
    .map((expense) => expense as ExpenseRow);

  const fixedStats90 = buildExpenseStats(fixedExpenses, now, 90);
  const fixedStats365 = buildExpenseStats(fixedExpenses, now, 365);
  const routineMedicalStats90 = buildExpenseStats(
    routineMedicalExpenses,
    now,
    90,
  );
  const routineMedicalStats365 = buildExpenseStats(
    routineMedicalExpenses,
    now,
    365,
  );
  const eventMedicalStats90 = buildExpenseStats(eventMedicalExpenses, now, 90);
  const eventMedicalStats365 = buildExpenseStats(
    eventMedicalExpenses,
    now,
    365,
  );
  const medicalStats90 = buildExpenseStats(medicalExpenses, now, 90);
  const medicalStats365 = buildExpenseStats(medicalExpenses, now, 365);
  const totalStats365 = buildExpenseStats(baselineExpenses, now, 365);

  const insuranceModelForPremium = buildInsuranceModel({
    status: dog.insuranceStatus,
    insuranceExpenses,
    riskReserveBeforeInsurance: 0,
  });
  const historicalCoreFixedMonthly = weightedRecentAverage(
    fixedStats90.averageMonthly,
    fixedStats365.averageMonthly,
    0.65,
  );
  const historicalFixedMonthly =
    historicalCoreFixedMonthly + insuranceModelForPremium.monthlyPremium;
  const historicalRoutineMedicalMonthly = weightedRecentAverage(
    routineMedicalStats90.averageMonthly,
    routineMedicalStats365.averageMonthly,
    0.6,
  );
  const historicalEventMedicalMonthly = weightedRecentAverage(
    eventMedicalStats90.averageMonthly,
    eventMedicalStats365.averageMonthly,
    0.5,
  );
  const rawOutlierReserveMonthly =
    expenseClassification.outlierExpenses.reduce(
      (sum, expense) => sum + expense.amountNumber,
      0,
    ) / 12;
  const historicalMedicalMonthly =
    historicalRoutineMedicalMonthly + historicalEventMedicalMonthly;
  const historicalTotalMonthly = weightedRecentAverage(
    buildExpenseStats(baselineExpenses, now, 90).averageMonthly,
    totalStats365.averageMonthly,
    0.6,
  );

  const fixedHistoryWeight = historyBlendWeight({
    stats: fixedStats365.count > 0 ? fixedStats365 : fixedStats90,
    transactionCount: fixedExpenses.length,
    targetActiveMonths: 4,
    maxWeight: 0.82,
  });
  const medicalHistoryWeight = historyBlendWeight({
    stats: medicalStats365.count > 0 ? medicalStats365 : medicalStats90,
    transactionCount: medicalExpenses.length + annualVisitCount,
    targetActiveMonths: 4,
    maxWeight: 0.72,
  });

  const medicalVolatility =
    medicalStats365.volatility || medicalStats90.volatility || 0;
  const routineShare = medicalRoutineShare(
    medicalVolatility,
    medicalStats365.activeMonths || medicalStats90.activeMonths,
    recentVisitCount,
  );
  const historicalRoutineMedical = roundMoney(
    historicalRoutineMedicalMonthly > 0
      ? historicalRoutineMedicalMonthly
      : historicalMedicalMonthly * routineShare,
  );
  const historicalReserveMedical = roundMoney(
    Math.max(0, historicalMedicalMonthly - historicalRoutineMedical),
  );

  const forecastBias = evaluateForecastBias({
    forecasts: priorForecasts,
    expenses,
    now,
  });

  const sizeMultiplier = recurringSizeMultiplier(weightKg);
  const baseFoodCost =
    recurringCostReference.monthlyTotal * recurringCostReference.foodShare;
  const baseSuppliesCost =
    recurringCostReference.monthlyTotal * recurringCostReference.suppliesShare;
  const basePlannedCareCost =
    recurringCostReference.monthlyTotal -
    baseFoodCost -
    baseSuppliesCost -
    recurringCostReference.monthlyTotal *
      recurringCostReference.groomingShare;

  const modeledFoodCost = baseFoodCost * sizeMultiplier;
  const modeledSuppliesCost =
    baseSuppliesCost * Math.max(0.9, sizeMultiplier - 0.05);
  const modeledGroomingCost = breed.profile.groomingMonthly;
  const insurancePremium = insuranceModelForPremium.monthlyPremium;
  const modeledFixedCost =
    modeledFoodCost +
    modeledSuppliesCost +
    modeledGroomingCost +
    insurancePremium;

  const fixedCost = blendModeledWithHistory({
    modeled: modeledFixedCost,
    actual: historicalFixedMonthly,
    weight: fixedHistoryWeight,
    minRatio: 0.7,
    maxRatio: 1.4,
  });

  const hasChronic = conditions.some(
    (condition) => condition.conditionType === "chronic",
  );
  const conditionCareCost =
    conditions.length * 7000 +
    medications.length * 5000 +
    (hasChronic ? 12000 : 0);
  const obesityCareCost =
    isOverweight
      ? 10000
      : (breed.profile.obesityRatePct ?? 0) >= 20
        ? 4000
        : 0;
  const riskVector = buildRiskVector({
    breedRiskFactors: breed.profile.riskFactors,
    conditions,
    medications,
    axisExpenseMonthly: expenseClassification.axisExpenseMonthly,
    isOverweight,
  });

  const modeledPlannedCareCost = roundMoney(
    basePlannedCareCost +
      agePlannedCareCost(dogAge) +
      breed.profile.riskFactors.reduce(
        (sum, factor) => sum + factor.plannedCareMonthly,
        0,
      ) +
      conditionCareCost +
      obesityCareCost,
  );

  const plannedHistoryAnchor = Math.max(
    basePlannedCareCost * 0.8,
    basePlannedCareCost * 0.45 + historicalRoutineMedical,
  );
  let plannedCareCost = blendModeledWithHistory({
    modeled: modeledPlannedCareCost,
    actual: plannedHistoryAnchor,
    weight: medicalHistoryWeight * 0.7,
    minRatio: 0.72,
    maxRatio: 1.28,
  });

  const conditionReserveCost =
    conditions.length * 7000 +
    medications.length * 5000 +
    (hasChronic ? 15000 : 0);
  const visitReserveCost =
    recentVisitCount >= 2 ? 18000 : recentVisitCount === 1 ? 9000 : 0;
  const annualVisitPressure =
    annualVisitCount >= 4 ? 12000 : annualVisitCount >= 2 ? 7000 : 0;
  const obesityReserveCost =
    isOverweight
      ? 12000
      : (breed.profile.obesityRatePct ?? 0) >= 20
        ? 6000
        : 0;
  const riskReserveBeforeInsurance = roundMoney(
    treatmentCostReference.monthlyReserve * ageRiskMultiplier(dogAge) +
      breed.profile.riskFactors.reduce(
        (sum, factor) => sum + factor.reserveMonthly,
        0,
      ) +
      conditionReserveCost +
      visitReserveCost +
      annualVisitPressure +
      obesityReserveCost,
  );
  const insuranceModel = buildInsuranceModel({
    status: dog.insuranceStatus,
    insuranceExpenses,
    riskReserveBeforeInsurance,
  });
  const insuranceReserveOffset = insuranceModel.reserveOffset;

  const modeledRiskAdjustedCost = roundMoney(
    riskReserveBeforeInsurance + insuranceReserveOffset,
  );
  const outlierReserveMonthly = roundMoney(
    clamp(rawOutlierReserveMonthly, 0, modeledRiskAdjustedCost * 0.45),
  );

  const riskHistoryAnchor = Math.max(
    modeledRiskAdjustedCost * 0.58,
    historicalReserveMedical + visitReserveCost + annualVisitPressure,
  );
  let riskAdjustedCost = blendModeledWithHistory({
    modeled: modeledRiskAdjustedCost,
    actual: riskHistoryAnchor,
    weight: medicalHistoryWeight,
    minRatio: 0.7,
    maxRatio: 1.34,
  });

  const variableHistoryBiasFactor =
    1 + (forecastBias.factor - 1) * forecastBias.strength;
  if (Math.abs(variableHistoryBiasFactor - 1) >= 0.02) {
    plannedCareCost = roundMoney(plannedCareCost * variableHistoryBiasFactor);
    riskAdjustedCost = roundMoney(riskAdjustedCost * variableHistoryBiasFactor);
  }

  const currentVariableMonthly = plannedCareCost + riskAdjustedCost;
  const targetVariableFromExperience = Math.max(
    currentVariableMonthly * 0.7,
    historicalTotalMonthly > 0 ? historicalTotalMonthly - fixedCost : 0,
  );
  const totalAnchorFactor =
    currentVariableMonthly > 0
      ? clamp(targetVariableFromExperience / currentVariableMonthly, 0.88, 1.12)
      : 1;
  const totalAnchorStrength = clamp(
    fixedHistoryWeight * 0.1 + medicalHistoryWeight * 0.14,
    0,
    0.22,
  );
  const experienceAlignmentFactor =
    1 + (totalAnchorFactor - 1) * totalAnchorStrength;
  if (Math.abs(experienceAlignmentFactor - 1) >= 0.015) {
    plannedCareCost = roundMoney(plannedCareCost * experienceAlignmentFactor);
    riskAdjustedCost = roundMoney(riskAdjustedCost * experienceAlignmentFactor);
  }

  const confidenceLevel = confidenceLevelFor({
    fixedHistoryWeight,
    medicalHistoryWeight,
    biasEvaluationCount: forecastBias.evaluationCount,
    breedMatchedExactly,
  });
  const forecastRangeSpread = rangeSpread({
    confidenceLevel,
    medicalVolatility,
    biasEvaluationCount: forecastBias.evaluationCount,
  });

  const fixedDrivers: CostDriver[] = [
    {
      section: "fixed",
      label: `기본 식비 (${sizeClassLabel(breed.profile.sizeClass)} 체급)`,
      monthlyImpact: roundMoney(modeledFoodCost),
      reason:
        "국내 평균 양육비의 식비 비중을 체급에 맞춰 조정했습니다.",
    },
    {
      section: "fixed",
      label: `${breed.profile.displayName} 미용·코트 관리`,
      monthlyImpact: roundMoney(modeledGroomingCost),
      reason:
        "견종별 코트 관리 강도를 반영해 미용비 기본값을 설정했습니다.",
    },
    {
      section: "fixed",
      label: "최근 고정지출 패턴 반영",
      monthlyImpact: roundMoney(historicalFixedMonthly * fixedHistoryWeight),
      reason:
        fixedHistoryWeight > 0
          ? `최근 ${Math.max(fixedStats365.monthsTracked, fixedStats90.monthsTracked)}개월 고정지출 월평균 ${roundMoney(historicalFixedMonthly).toLocaleString("ko-KR")}원을 ${Math.round(fixedHistoryWeight * 100)}% 비중으로 반영했습니다.`
          : "고정지출 기록이 적어 견종 기본값 위주로 계산했습니다.",
    },
    {
      section: "fixed",
      label: "반려동물 보험료",
      monthlyImpact: insurancePremium,
      reason:
        insuranceModel.enrolled
          ? insuranceModel.premiumSource === "observed_expense"
            ? "보험 지출 기록을 연간 기준으로 월 환산해 고정비에 포함했습니다."
            : "보험 가입 상태라 기본 월 보험료를 고정비에 포함했습니다."
          : "보험 미가입 상태라 보험료는 반영하지 않았습니다.",
    },
  ];

  const plannedDrivers: CostDriver[] = [
    {
      section: "planned_care",
      label: "기본 예방관리 기준치",
      monthlyImpact: roundMoney(basePlannedCareCost),
      reason:
        "국내 평균 월 양육비에서 사료·용품·미용을 제외한 나머지를 기본 예방관리 예산으로 사용했습니다.",
    },
    {
      section: "planned_care",
      label: `${ageStageLabel(dogAge)} 추가 검진`,
      monthlyImpact: agePlannedCareCost(dogAge),
      reason:
        dogAge < 1
          ? "성장기라 백신과 초기 검진 비중을 높였습니다."
          : dogAge >= 7
            ? "시니어 구간부터 혈액·치과·만성질환 추적 비용을 더 반영했습니다."
            : "성견기 기본 검진 수준으로 계산했습니다.",
    },
    ...breed.profile.riskFactors.map((factor) => ({
      section: "planned_care" as const,
      label: factor.label,
      monthlyImpact: factor.plannedCareMonthly,
      reason: factor.reason,
    })),
    {
      section: "planned_care",
      label: "반복 의료비 패턴",
      monthlyImpact: roundMoney(historicalRoutineMedical),
      reason:
        historicalRoutineMedical > 0
          ? `최근 의료비 변동성을 분석해 월평균 의료지출 중 약 ${Math.round(routineShare * 100)}%를 반복 관리비로 분류했습니다.`
          : "반복 의료비 데이터가 충분하지 않아 모델 기본값을 유지했습니다.",
    },
    {
      section: "planned_care",
      label: "현재 질환·복약 관리",
      monthlyImpact: roundMoney(conditionCareCost),
      reason:
        conditions.length > 0 || medications.length > 0
          ? `활성 질환 ${conditions.length}건, 복약 ${medications.length}건을 반영해 예방관리 예산을 높였습니다.`
          : "현재 활성 질환과 복약 기록이 없어 추가 관리비는 크게 잡지 않았습니다.",
    },
    {
      section: "planned_care",
      label: "체중 관리 여유분",
      monthlyImpact: roundMoney(obesityCareCost),
      reason:
        isOverweight
          ? "현재 체중이 목표 체중보다 높아 식이·모니터링 비용을 추가했습니다."
          : (breed.profile.obesityRatePct ?? 0) >= 20
            ? "이 견종은 비만 위험이 상대적으로 높아 체중 관리 여유분을 소폭 추가했습니다."
            : "체중 관련 추가 관리비는 크게 잡지 않았습니다.",
    },
  ];

  const riskDrivers: CostDriver[] = [
    {
      section: "risk_reserve",
      label: "기본 돌발진료 예비비",
      monthlyImpact: roundMoney(
        treatmentCostReference.monthlyReserve * ageRiskMultiplier(dogAge),
      ),
      reason:
        "국내 2년 평균 치료비를 월 예비비로 환산하고, 연령대별 위험도를 곱했습니다.",
    },
    ...breed.profile.riskFactors.map((factor) => ({
      section: "risk_reserve" as const,
      label: `${factor.label} 리스크`,
      monthlyImpact: factor.reserveMonthly,
      reason: factor.reason,
    })),
    {
      section: "risk_reserve",
      label: "변동성 높은 의료비 패턴",
      monthlyImpact: roundMoney(historicalReserveMedical),
      reason:
        historicalReserveMedical > 0
          ? `최근 의료지출의 변동분을 돌발진료 예비비로 분리해 과거 체감 비용과 비슷하게 맞췄습니다.`
          : "돌발성 의료비 패턴이 아직 충분히 쌓이지 않았습니다.",
    },
    {
      section: "risk_reserve",
      label: "최근 병원 방문 패턴",
      monthlyImpact: roundMoney(visitReserveCost + annualVisitPressure),
      reason:
        annualVisitCount > 0
          ? `최근 1년 병원 방문 ${annualVisitCount}회를 반영해 단기 예비비를 조정했습니다.`
          : "최근 1년 병원 방문 기록이 없어 방문 빈도 가산은 적용하지 않았습니다.",
    },
    {
      section: "risk_reserve",
      label: "현재 질환 지속 리스크",
      monthlyImpact: roundMoney(conditionReserveCost),
      reason:
        conditions.length > 0 || medications.length > 0
          ? "현재 질환과 복약이 있으면 추가 진료 가능성이 높아져 예비비를 더 둡니다."
          : "현재 지속 질환 데이터가 없어 추가 예비비는 크게 반영하지 않았습니다.",
    },
    {
      section: "risk_reserve",
      label: "체중 관련 리스크",
      monthlyImpact: roundMoney(obesityReserveCost),
      reason:
        isOverweight
          ? "과체중은 관절·심혈관 부담을 높일 수 있어 예비비를 더 둡니다."
          : (breed.profile.obesityRatePct ?? 0) >= 20
            ? "이 견종은 비만 관련 리스크가 높아 체중 관련 돌발비를 소폭 반영했습니다."
            : "체중 관련 리스크 가산을 크게 두지 않았습니다.",
    },
  ];

  const sources = dedupeSources([
    recurringCostReference.source,
    treatmentCostReference.source,
    internationalLongevityReference,
    internationalLifeTableReference,
    internationalInsuranceReference,
    weightHealthReference,
    ...breed.profile.sources,
  ]);
  const sortedDrivers = sortDrivers([
    ...fixedDrivers,
    ...plannedDrivers,
    ...riskDrivers,
  ]);
  const insights = buildForecastInsights({
    drivers: sortedDrivers,
    confidenceLevel,
    fixedHistoryWeight,
    medicalHistoryWeight,
    forecastBias,
    isOverweight,
    activeConditionCount: conditions.length,
    activeMedicationCount: medications.length,
    recentVisitCount,
    recentExpenseCount: expenses.length,
    medicalVolatility,
    riskVectorTopAxes: riskVector.topAxes,
    outlierCount: expenseClassification.outlierExpenses.length,
    outlierReserveMonthly,
    insuranceModel,
  });

  const matchSummary =
    breed.matchType === "exact"
      ? `${dog.breed} 입력값을 ${breed.profile.displayName} 프로필에 직접 매칭했습니다.`
      : breed.matchType === "mixed"
        ? `${dog.breed || "믹스견"} 입력값을 믹스/혼합견 규칙으로 해석했습니다.`
        : breed.matchType === "size_fallback"
          ? `${dog.breed}는 등록된 대표 견종 목록에 없어 체중 기준 ${sizeClassLabel(breed.profile.sizeClass)} 프로필로 계산했습니다.`
          : `견종 입력이 없어 체중 기준 ${sizeClassLabel(breed.profile.sizeClass)} 프로필로 계산했습니다.`;

  const summary = [
    matchSummary,
    `기대수명 ${breed.profile.expectedLifespanYears[0]}~${breed.profile.expectedLifespanYears[1]}세 기준으로 현재 나이 ${dogAge.toFixed(1)}세를 반영했습니다.`,
    `최근 기록 기준 월 고정지출은 ${roundMoney(historicalFixedMonthly).toLocaleString("ko-KR")}원, 월 의료지출은 ${roundMoney(historicalMedicalMonthly).toLocaleString("ko-KR")}원으로 계산됐고 현재 예측에 각각 ${Math.round(fixedHistoryWeight * 100)}%, ${Math.round(medicalHistoryWeight * 100)}% 반영했습니다.`,
    `의료비 변동성 ${medicalVolatility.toFixed(2)}를 기준으로 반복 관리비 ${Math.round(routineShare * 100)}%, 돌발 예비비 ${Math.round((1 - routineShare) * 100)}%로 분리했습니다.`,
    `지출 카테고리는 고정비 ${expenseClassification.coreFixedExpenses.length}건, 반복 의료비 ${routineMedicalExpenses.length}건, 돌발 의료비 ${eventMedicalExpenses.length}건으로 나눠 계산했습니다.`,
  ];
  const topRiskAxis = riskVector.topAxes[0];
  if (topRiskAxis) {
    summary.push(
      `질병 리스크 벡터에서는 ${topRiskAxis.label} 축이 월 ${topRiskAxis.totalMonthly.toLocaleString("ko-KR")}원 규모로 가장 크게 잡혔습니다.`,
    );
  }
  if (expenseClassification.outlierExpenses.length > 0) {
    summary.push(
      `고액 또는 일회성 지출 ${expenseClassification.outlierExpenses.length}건은 반복 월지출을 부풀리지 않도록 이상치로 분리했습니다.`,
    );
  }
  if (forecastBias.evaluationCount > 0) {
    summary.push(
      `이전 예측 ${forecastBias.evaluationCount}건과 실제 지출을 비교한 결과, 실제 월지출이 예측의 약 ${Math.round(forecastBias.factor * 100)}% 수준이고 평균 오차는 약 ${Math.round(forecastBias.averageAbsoluteErrorPct)}%로 나타나 현재 변수비용에 보정했습니다.`,
    );
  }
  if (Math.abs(experienceAlignmentFactor - 1) >= 0.015) {
    summary.push(
      `최근 체감 월지출과 더 비슷해지도록 최종 변수비용에 ${Math.round(experienceAlignmentFactor * 100)}% 정렬 보정을 적용했습니다.`,
    );
  }

  const assumptions = {
    engineVersion: "breed_profile_v3",
    calculatedAt: now.toISOString(),
    ageYears: Number(dogAge.toFixed(1)),
    ageStage: ageStageLabel(dogAge),
    weightKg,
    targetWeightKg: targetWeightKg > 0 ? targetWeightKg : null,
    isOverweight,
    recentVisitCount,
    annualVisitCount,
    recentExpenseCount: expenses.length,
    activeConditionCount: conditions.length,
    activeMedicationCount: medications.length,
    confidenceLevel,
    breedProfile: {
      key: breed.profile.key,
      displayName: breed.profile.displayName,
      inputBreed: breed.inputBreed,
      matchType: breed.matchType,
      sizeClass: breed.profile.sizeClass,
      sizeLabel: sizeClassLabel(breed.profile.sizeClass),
      expectedLifespanYears: breed.profile.expectedLifespanYears,
      obesityRatePct: breed.profile.obesityRatePct ?? null,
      notes: breed.profile.notes,
    },
    historyModel: {
      fixedMonthlyAverage: roundMoney(historicalFixedMonthly),
      coreFixedMonthlyAverage: roundMoney(historicalCoreFixedMonthly),
      medicalMonthlyAverage: roundMoney(historicalMedicalMonthly),
      routineMedicalMonthlyAverage: roundMoney(
        historicalRoutineMedicalMonthly,
      ),
      eventMedicalMonthlyAverage: roundMoney(historicalEventMedicalMonthly),
      totalMonthlyAverage: roundMoney(historicalTotalMonthly),
      fixedHistoryWeight: Number(fixedHistoryWeight.toFixed(2)),
      medicalHistoryWeight: Number(medicalHistoryWeight.toFixed(2)),
      medicalRoutineShare: Number(routineShare.toFixed(2)),
      medicalVolatility: Number(medicalVolatility.toFixed(2)),
      fixedTrackedMonths: Math.max(fixedStats365.monthsTracked, fixedStats90.monthsTracked),
      medicalTrackedMonths: Math.max(
        medicalStats365.monthsTracked,
        medicalStats90.monthsTracked,
      ),
      forecastBiasFactor: Number(forecastBias.factor.toFixed(2)),
      forecastBiasEvaluations: forecastBias.evaluationCount,
      forecastBiasDirection: forecastBias.direction,
      forecastBiasAverageAbsoluteErrorPct: Number(
        forecastBias.averageAbsoluteErrorPct.toFixed(1),
      ),
      variableHistoryBiasFactor: Number(
        variableHistoryBiasFactor.toFixed(2),
      ),
      experienceAlignmentFactor: Number(
        experienceAlignmentFactor.toFixed(2),
      ),
    },
    categoryModel: {
      fixedCount: expenseClassification.coreFixedExpenses.length,
      insuranceCount: insuranceExpenses.length,
      routineMedicalCount: routineMedicalExpenses.length,
      eventMedicalCount: eventMedicalExpenses.length,
      medicalCount: medicalExpenses.length,
      categoryBreakdown: expenseClassification.categoryBreakdown,
    },
    personalBaseline: {
      fixedMonthly: roundMoney(historicalFixedMonthly),
      coreFixedMonthly: roundMoney(historicalCoreFixedMonthly),
      routineMedicalMonthly: historicalRoutineMedical,
      eventReserveMonthly: historicalReserveMedical,
      totalObservedMonthly: roundMoney(historicalTotalMonthly),
      activeMonths: totalStats365.activeMonths,
      trackedMonths: totalStats365.monthsTracked,
    },
    riskVector: {
      topAxes: riskVector.topAxes,
      entries: riskVector.entries.slice(0, 12),
    },
    outlierModel: {
      outlierCount: expenseClassification.outlierExpenses.length,
      outlierReserveMonthly,
      categories: expenseClassification.outlierExpenses.map((expense) => ({
        category: expense.expenseCategory,
        label: expense.meta.label,
        amount: roundMoney(expense.amountNumber),
        date: expense.expenseDate.toISOString().slice(0, 10),
      })),
    },
    insuranceModel,
    validation: {
      forecastBiasFactor: Number(forecastBias.factor.toFixed(2)),
      forecastBiasEvaluations: forecastBias.evaluationCount,
      direction: forecastBias.direction,
      averagePredictedMonthly: roundMoney(
        forecastBias.averagePredictedMonthly,
      ),
      averageActualMonthly: roundMoney(forecastBias.averageActualMonthly),
      averageAbsoluteErrorPct: Number(
        forecastBias.averageAbsoluteErrorPct.toFixed(1),
      ),
    },
    methodology: {
      recurringMonthlyReference: recurringCostReference.monthlyTotal,
      treatmentMonthlyReserveReference: roundMoney(
        treatmentCostReference.monthlyReserve,
      ),
      remainingLifetimeYears: Number(remainingLifetimeYears.toFixed(1)),
      matchSummary,
    },
    explanation: {
      title: `${breed.profile.displayName} 기준 비용 추정`,
      summary,
      breedProfile: {
        displayName: breed.profile.displayName,
        inputBreed: breed.inputBreed,
        matchType: breed.matchType,
        sizeLabel: sizeClassLabel(breed.profile.sizeClass),
        expectedLifespanYears: breed.profile.expectedLifespanYears,
        obesityRatePct: breed.profile.obesityRatePct ?? null,
        notes: breed.profile.notes,
      },
      insights,
      drivers: sortedDrivers.slice(0, 8),
      sources,
    },
  };

  const scenarioBasePlanned = plannedCareCost;
  const scenarioBaseRisk = riskAdjustedCost;

  const volatilityStep = clamp(medicalVolatility, 0, 1.4);
  const scenarios = [
    {
      scenario: "basic",
      plannedMultiplier: 1.0,
      riskMultiplier: 1.0,
    },
    {
      scenario: "caution",
      plannedMultiplier: 1.08,
      riskMultiplier: 1.2 + volatilityStep * 0.06,
    },
    {
      scenario: "high_risk",
      plannedMultiplier: 1.15,
      riskMultiplier: 1.42 + volatilityStep * 0.1,
    },
  ] as const;

  await tx.costForecast.createMany({
    data: scenarios.map(({ scenario, plannedMultiplier, riskMultiplier }) => {
      const scenarioPlannedCare = roundMoney(
        scenarioBasePlanned * plannedMultiplier,
      );
      const scenarioRiskReserve = roundMoney(
        scenarioBaseRisk * riskMultiplier,
      );
      const monthlyEstimate = roundMoney(
        fixedCost + scenarioPlannedCare + scenarioRiskReserve,
      );
      return {
        dogId,
        scenario,
        monthlyEstimate,
        rangeMin: roundMoney(monthlyEstimate * (1 - forecastRangeSpread)),
        rangeMax: roundMoney(monthlyEstimate * (1 + forecastRangeSpread)),
        yearlyEstimate: roundMoney(monthlyEstimate * 12),
        sixMonthEstimate: roundMoney(monthlyEstimate * 6),
        lifetimeEstimate: roundMoney(
          monthlyEstimate * 12 * remainingLifetimeYears,
        ),
        confidenceLevel,
        breakdown: {
          fixedCost,
          foodCost: roundMoney(modeledFoodCost),
          suppliesCost: roundMoney(modeledSuppliesCost),
          groomingCost: roundMoney(modeledGroomingCost),
          insurancePremium,
          insuranceReserveOffset,
          historicalFixedMonthly: roundMoney(historicalFixedMonthly),
          historicalCoreFixedMonthly: roundMoney(historicalCoreFixedMonthly),
          fixedHistoryWeight: Number(fixedHistoryWeight.toFixed(2)),
          plannedCareCost: scenarioPlannedCare,
          plannedCareBase: roundMoney(basePlannedCareCost),
          plannedCareConditionCost: roundMoney(conditionCareCost),
          plannedCareObesityCost: roundMoney(obesityCareCost),
          historicalRoutineMedical,
          riskAdjustedCost: scenarioRiskReserve,
          riskReserveBase: roundMoney(
            treatmentCostReference.monthlyReserve * ageRiskMultiplier(dogAge),
          ),
          riskReserveBeforeInsurance,
          riskConditionCost: roundMoney(conditionReserveCost),
          riskVisitCost: roundMoney(visitReserveCost + annualVisitPressure),
          riskObesityCost: roundMoney(obesityReserveCost),
          historicalReserveMedical,
          outlierReserveMonthly,
          categoryFixedCount: expenseClassification.coreFixedExpenses.length,
          categoryRoutineMedicalCount: routineMedicalExpenses.length,
          categoryEventMedicalCount: eventMedicalExpenses.length,
          forecastBiasFactor: Number(variableHistoryBiasFactor.toFixed(2)),
          experienceAlignmentFactor: Number(
            experienceAlignmentFactor.toFixed(2),
          ),
        },
        assumptions,
      };
    }),
  });

  return scenarios.length;
}

export async function latestForecasts(tx: Tx, dogId: bigint) {
  const rows = await tx.costForecast.findMany({
    where: { dogId },
    orderBy: [{ generatedAt: "desc" }, { id: "desc" }],
  });

  const latest = new Map<string, (typeof rows)[number]>();
  for (const row of rows) {
    if (!latest.has(row.scenario)) latest.set(row.scenario, row);
  }

  return {
    basic: latest.get("basic") ?? null,
    caution: latest.get("caution") ?? null,
    highRisk: latest.get("high_risk") ?? null,
    generatedAt: rows[0]?.generatedAt ?? null,
  };
}
