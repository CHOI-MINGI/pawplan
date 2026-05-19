import assert from "node:assert/strict";
import { recalculateCostForecasts } from "../src/domain/costForecast.js";

type ExpenseSeed = {
  category: string;
  amount: number;
  daysAgo: number;
};

type ScenarioSeed = {
  expenses?: ExpenseSeed[];
  visitDaysAgo?: number[];
  conditions?: unknown[];
  medications?: unknown[];
  priorForecasts?: { generatedAt: Date; monthlyEstimate: number }[];
  dog?: Record<string, unknown>;
};

function daysAgo(days: number) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

async function runForecast(seed: ScenarioSeed = {}) {
  const created: Record<string, any>[] = [];
  const dog = {
    id: 1n,
    breed: "푸들",
    birthDate: daysAgo(365 * 5),
    currentWeightKg: 5.4,
    targetWeightKg: 5.1,
    insuranceStatus: "none",
    ...seed.dog,
  };

  const tx = {
    dog: {
      findUniqueOrThrow: async () => dog,
    },
    dogCondition: {
      findMany: async () => seed.conditions ?? [],
    },
    dogMedication: {
      findMany: async () => seed.medications ?? [],
    },
    expense: {
      findMany: async () =>
        (seed.expenses ?? []).map((expense) => ({
          dogId: 1n,
          expenseCategory: expense.category,
          amount: expense.amount,
          expenseDate: daysAgo(expense.daysAgo),
        })),
    },
    medicalVisit: {
      findMany: async () =>
        (seed.visitDaysAgo ?? []).map((visitDaysAgo) => ({
          visitDate: daysAgo(visitDaysAgo),
        })),
    },
    costForecast: {
      findMany: async () => seed.priorForecasts ?? [],
      createMany: async ({ data }: { data: Record<string, any>[] }) => {
        created.push(...data);
        return { count: data.length };
      },
    },
  };

  await recalculateCostForecasts(tx as any, 1n);
  const byScenario = Object.fromEntries(
    created.map((row) => [row.scenario, row]),
  );
  return {
    rows: created,
    basic: byScenario.basic,
    caution: byScenario.caution,
    highRisk: byScenario.high_risk,
  };
}

function assertForecastShape(result: Awaited<ReturnType<typeof runForecast>>) {
  assert.equal(result.rows.length, 3, "forecast should create 3 scenarios");
  assert.ok(result.basic.monthlyEstimate > 0, "basic estimate should be > 0");
  assert.ok(
    result.caution.monthlyEstimate > result.basic.monthlyEstimate,
    "caution estimate should exceed basic",
  );
  assert.ok(
    result.highRisk.monthlyEstimate > result.caution.monthlyEstimate,
    "high-risk estimate should exceed caution",
  );
  assert.ok(
    result.basic.rangeMin < result.basic.monthlyEstimate &&
      result.basic.rangeMax > result.basic.monthlyEstimate,
    "range should wrap monthly estimate",
  );
  assert.equal(
    result.basic.breakdown.fixedCost +
      result.basic.breakdown.plannedCareCost +
      result.basic.breakdown.riskAdjustedCost,
    result.basic.monthlyEstimate,
    "basic breakdown should sum to monthly estimate",
  );
  const insights = result.basic.assumptions.explanation.insights;
  assert.ok(Array.isArray(insights), "insights should be an array");
  assert.ok(insights.length >= 2, "insights should include actionable items");
  assert.equal(
    result.basic.assumptions.engineVersion,
    "breed_profile_v3",
    "engine version should reflect the advanced forecast model",
  );
  assert.ok(
    Array.isArray(result.basic.assumptions.riskVector.topAxes),
    "risk vector top axes should be present",
  );
  assert.ok(
    result.basic.assumptions.categoryModel,
    "category model metadata should be present",
  );
  assert.ok(
    result.basic.assumptions.personalBaseline,
    "personal baseline should be present",
  );
  assert.ok(
    result.basic.assumptions.insuranceModel,
    "insurance model should be present",
  );
  assert.ok(
    result.basic.assumptions.validation,
    "forecast validation metadata should be present",
  );
  assert.ok(
    insights.some(
      (insight: Record<string, unknown>) => insight.kind === "attention",
    ),
    "insights should include the top cost attention item",
  );
}

async function main() {
  const baseline = await runForecast();
  assertForecastShape(baseline);
  assert.equal(
    baseline.basic.confidenceLevel,
    "low",
    "baseline without user history should stay low confidence",
  );

  const medicalPressure = await runForecast({
    expenses: [
      { category: "hospital", amount: 180000, daysAgo: 20 },
      { category: "hospital", amount: 120000, daysAgo: 45 },
      { category: "food", amount: 52000, daysAgo: 12 },
      { category: "grooming", amount: 60000, daysAgo: 50 },
    ],
    visitDaysAgo: [20, 45],
    conditions: [{ conditionType: "chronic" }],
    medications: [{ medicationName: "daily med" }],
  });
  assertForecastShape(medicalPressure);
  assert.ok(
    medicalPressure.basic.monthlyEstimate > baseline.basic.monthlyEstimate,
    "medical pressure should increase the monthly estimate",
  );
  assert.ok(
    medicalPressure.basic.breakdown.riskAdjustedCost >
      baseline.basic.breakdown.riskAdjustedCost,
    "medical pressure should increase risk reserve",
  );
  assert.ok(
    medicalPressure.basic.assumptions.riskVector.topAxes.length > 0,
    "medical pressure should produce risk vector axes",
  );
  assert.ok(
    medicalPressure.basic.assumptions.categoryModel.eventMedicalCount >= 2,
    "hospital expenses should be treated as event medical costs",
  );
  assert.ok(
    medicalPressure.basic.assumptions.explanation.insights.some(
      (insight: Record<string, unknown>) =>
        String(insight.title).includes("질환") ||
        String(insight.title).includes("병원비"),
    ),
    "medical pressure should produce a medical action insight",
  );

  const outlierHandled = await runForecast({
    expenses: [
      { category: "surgery", amount: 1500000, daysAgo: 18 },
      { category: "checkup", amount: 70000, daysAgo: 55 },
      { category: "food", amount: 52000, daysAgo: 10 },
    ],
    visitDaysAgo: [18],
  });
  assertForecastShape(outlierHandled);
  assert.equal(
    outlierHandled.basic.assumptions.outlierModel.outlierCount,
    1,
    "large surgery cost should be isolated as an outlier",
  );
  assert.ok(
    outlierHandled.basic.breakdown.outlierReserveMonthly > 0,
    "outlier reserve should be amortized into reserve metadata",
  );
  assert.ok(
    outlierHandled.basic.assumptions.explanation.insights.some(
      (insight: Record<string, unknown>) =>
        String(insight.title).includes("일회성"),
    ),
    "outlier handling should be visible in insights",
  );

  const insured = await runForecast({
    dog: { insuranceStatus: "enrolled" },
    expenses: [{ category: "insurance", amount: 480000, daysAgo: 30 }],
  });
  assertForecastShape(insured);
  assert.equal(
    insured.basic.assumptions.insuranceModel.monthlyPremium,
    40000,
    "annual insurance expense should be converted to a monthly premium",
  );
  assert.equal(
    insured.basic.assumptions.insuranceModel.premiumSource,
    "observed_expense",
    "observed insurance expense should override the default premium",
  );
  assert.ok(
    insured.basic.assumptions.insuranceModel.reserveOffset < 0,
    "insurance coverage should modestly reduce risk reserve",
  );

  const calibrated = await runForecast({
    expenses: [
      { category: "hospital", amount: 180000, daysAgo: 25 },
      { category: "food", amount: 50000, daysAgo: 18 },
    ],
    priorForecasts: [
      {
        generatedAt: daysAgo(45),
        monthlyEstimate: 100000,
      },
    ],
  });
  assertForecastShape(calibrated);
  assert.equal(
    calibrated.basic.assumptions.historyModel.forecastBiasEvaluations,
    1,
    "prior forecasts should be evaluated against actual expenses",
  );
  assert.ok(
    calibrated.basic.assumptions.validation.averageAbsoluteErrorPct > 0,
    "validation loop should expose average absolute error",
  );

  console.log("Forecast engine checks passed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
