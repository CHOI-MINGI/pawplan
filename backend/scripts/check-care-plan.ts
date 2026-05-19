import assert from "node:assert/strict";
import {
  buildCarePlanMetadata,
  careReminderPolicy,
} from "../src/domain/carePlan.js";

function date(value: string) {
  return new Date(`${value}T00:00:00.000+09:00`);
}

function schedule(overrides: Record<string, unknown> = {}) {
  return {
    id: 1n,
    scheduleType: "checkup",
    title: "정기 건강검진",
    dueDate: date("2026-05-20"),
    repeatCycleDays: 180,
    priority: "high",
    status: "pending",
    reminderEnabled: true,
    createdBy: 7n,
    ...overrides,
  };
}

function main() {
  const checkupPolicy = careReminderPolicy("checkup", "high");
  assert.deepEqual(
    checkupPolicy.leadDays,
    [7, 1, 0],
    "high checkups should get advance reminders",
  );
  assert.equal(
    checkupPolicy.delivery,
    "push_candidate",
    "high checkups should be push candidates",
  );

  const dueSoon = buildCarePlanMetadata(
    schedule(),
    7n,
    new Date("2026-05-17T09:00:00.000+09:00"),
  );
  assert.equal(dueSoon.failureStatus, "due_soon");
  assert.equal(dueSoon.responsibleLabel, "나");
  assert.equal(dueSoon.delivery, "push_candidate");

  const missedRepeated = buildCarePlanMetadata(
    schedule({
      dueDate: date("2026-05-01"),
      scheduleType: "heartworm",
      repeatCycleDays: 30,
    }),
    8n,
    new Date("2026-05-17T09:00:00.000+09:00"),
  );
  assert.equal(missedRepeated.failureStatus, "missed_repeated");
  assert.equal(missedRepeated.responsibleLabel, "가족 구성원");
  assert.equal(missedRepeated.delivery, "push_candidate");

  console.log("Care plan checks passed");
}

main();
