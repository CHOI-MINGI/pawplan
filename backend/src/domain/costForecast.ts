import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

const fixedCategories = new Set(["food", "snack", "grooming", "insurance", "supplies"]);
const dayMs = 24 * 60 * 60 * 1000;

function roundMoney(value: number) {
  return Math.max(0, Math.round(value / 1000) * 1000);
}

function ageYears(birthDate: Date | null, now: Date) {
  if (!birthDate) return 3;
  return Math.max(0, (now.getTime() - birthDate.getTime()) / (365.25 * dayMs));
}

function ageWeight(age: number) {
  if (age < 1) return 0.9;
  if (age >= 10) return 1.35;
  if (age >= 7) return 1.2;
  return 1.0;
}

export async function recalculateCostForecasts(tx: Tx, dogId: bigint) {
  const now = new Date();
  const since = new Date(now.getTime() - 90 * dayMs);
  const [dog, conditions, medications, expenses, recentVisits] = await Promise.all([
    tx.dog.findUniqueOrThrow({ where: { id: dogId } }),
    tx.dogCondition.findMany({ where: { dogId, status: { in: ["active", "monitoring"] } } }),
    tx.dogMedication.findMany({ where: { dogId, isActive: true } }),
    tx.expense.findMany({ where: { dogId, expenseDate: { gte: since } } }),
    tx.medicalVisit.count({ where: { dogId, visitDate: { gte: since } } }),
  ]);

  const dogAge = ageYears(dog.birthDate, now);
  const weightKg = Number(dog.currentWeightKg ?? 5);
  const systemFixed = 80000 + Math.min(50000, weightKg * 5000) + (dog.insuranceStatus === "enrolled" ? 40000 : 0);
  const recentFixedTotal = expenses
    .filter((expense) => fixedCategories.has(expense.expenseCategory))
    .reduce((sum, expense) => sum + Number(expense.amount), 0);
  const recentFixedMonthly = recentFixedTotal / 3;
  const hasRecentExpense = recentFixedTotal > 0;
  const fixedCost = hasRecentExpense ? systemFixed * 0.4 + recentFixedMonthly * 0.6 : systemFixed;

  const plannedCareCost = dogAge >= 7 ? 60000 : dogAge < 1 ? 70000 : 45000;
  const healthMultiplier = (() => {
    const hasChronic = conditions.some((condition) => condition.conditionType === "chronic");
    if (hasChronic && medications.length > 0) return 1.4;
    if (hasChronic) return 1.25;
    if (conditions.length > 0) return 1.1;
    return 1.0;
  })();
  const visitMultiplier = recentVisits >= 2 ? 1.25 : recentVisits === 1 ? 1.1 : 1.0;
  const riskAdjustedCost = 30000 * ageWeight(dogAge) * healthMultiplier * visitMultiplier;

  const baseMonthly = roundMoney(fixedCost + plannedCareCost + riskAdjustedCost);
  const confidenceLevel = expenses.length >= 6 && recentVisits > 0 ? "high" : expenses.length >= 2 || conditions.length > 0 ? "medium" : "low";
  const baseBreakdown = {
    fixedCost: roundMoney(fixedCost),
    plannedCareCost: roundMoney(plannedCareCost),
    riskAdjustedCost: roundMoney(riskAdjustedCost),
  };
  const assumptions = {
    ageYears: Number(dogAge.toFixed(1)),
    weightKg,
    activeConditionCount: conditions.length,
    activeMedicationCount: medications.length,
    recentVisitCount: recentVisits,
    recentExpenseCount: expenses.length,
  };

  const scenarios = [
    { scenario: "basic", multiplier: 1.0 },
    { scenario: "caution", multiplier: 1.2 },
    { scenario: "high_risk", multiplier: 1.5 },
  ];

  await tx.costForecast.createMany({
    data: scenarios.map(({ scenario, multiplier }) => {
      const monthlyEstimate = roundMoney(baseMonthly * multiplier);
      return {
        dogId,
        scenario,
        monthlyEstimate,
        rangeMin: roundMoney(monthlyEstimate * 0.85),
        rangeMax: roundMoney(monthlyEstimate * 1.15),
        yearlyEstimate: roundMoney(monthlyEstimate * 12),
        sixMonthEstimate: roundMoney(monthlyEstimate * 6),
        lifetimeEstimate: roundMoney(monthlyEstimate * 12 * Math.max(1, 14 - dogAge)),
        confidenceLevel,
        breakdown: {
          fixedCost: baseBreakdown.fixedCost,
          plannedCareCost: roundMoney(baseBreakdown.plannedCareCost * multiplier),
          riskAdjustedCost: roundMoney(baseBreakdown.riskAdjustedCost * multiplier),
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
