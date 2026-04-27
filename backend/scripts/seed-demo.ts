import { PrismaClient } from "@prisma/client";
import { hashPassword } from "../src/auth.js";
import { generateDefaultCareSchedules } from "../src/domain/carePlan.js";
import { recalculateCostForecasts } from "../src/domain/costForecast.js";
import { buildVisitReport } from "../src/domain/visitReport.js";

const prisma = new PrismaClient();

const demoAccount = {
  email: "demo@pawplan.kr",
  password: "password123",
  name: "보호자",
};

async function main() {
  const passwordHash = await hashPassword(demoAccount.password);
  const existing = await prisma.user.findUnique({ where: { email: demoAccount.email }, select: { id: true } });

  if (existing) {
    await prisma.dog.deleteMany({ where: { primaryOwnerId: existing.id } });
  }

  const user = await prisma.user.upsert({
    where: { email: demoAccount.email },
    create: {
      email: demoAccount.email,
      passwordHash,
      name: demoAccount.name,
    },
    update: {
      passwordHash,
      name: demoAccount.name,
      status: "active",
    },
  });

  const dog = await prisma.dog.create({
    data: {
      primaryOwnerId: user.id,
      name: "초코",
      breed: "푸들",
      birthDate: new Date("2021-04-18"),
      sex: "female",
      neutered: true,
      currentWeightKg: 5.4,
      targetWeightKg: 5.1,
      activityLevel: "medium",
      insuranceStatus: "none",
      notes: "피부와 귀 상태를 주기적으로 확인합니다.",
    },
  });

  await prisma.dogCondition.createMany({
    data: [
      {
        dogId: dog.id,
        conditionType: "chronic",
        conditionName: "피부 민감",
        severity: "low",
        status: "monitoring",
        notes: "계절이 바뀔 때 가려움이 심해질 수 있습니다.",
      },
      {
        dogId: dog.id,
        conditionType: "allergy",
        conditionName: "닭고기 알레르기 의심",
        severity: "medium",
        status: "active",
      },
    ],
  });

  await prisma.dogMedication.create({
    data: {
      dogId: dog.id,
      medicationName: "귀 세정제",
      dosage: "적당량",
      frequencyText: "주 2회",
      startedOn: new Date("2026-04-01"),
      prescribedBy: "동네동물병원",
      isActive: true,
    },
  });

  const now = new Date();
  await generateDefaultCareSchedules(prisma, dog.id, now, user.id);

  await prisma.healthLog.createMany({
    data: [
      {
        dogId: dog.id,
        logType: "weight",
        title: "아침 체중",
        recordedAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
        valueNumeric: 5.4,
        valueUnit: "kg",
        memo: "목표 체중보다 조금 높음",
        createdBy: user.id,
      },
      {
        dogId: dog.id,
        logType: "symptom",
        title: "귀 긁음",
        recordedAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
        valueNumeric: 3,
        valueUnit: "회",
        memo: "저녁에 오른쪽 귀를 자주 긁음",
        createdBy: user.id,
      },
      {
        dogId: dog.id,
        logType: "appetite",
        title: "식욕 정상",
        recordedAt: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000),
        memo: "사료를 평소와 비슷하게 먹음",
        createdBy: user.id,
      },
    ],
  });

  const visit = await prisma.medicalVisit.create({
    data: {
      dogId: dog.id,
      hospitalName: "동네동물병원",
      veterinarianName: "김수의사",
      visitDate: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000),
      visitReason: "귀 가려움",
      symptoms: "오른쪽 귀를 자주 긁음",
      diagnosis: "외이염 경미",
      treatment: "귀 세정 및 경과 관찰",
      prescribedItems: "귀 세정제",
      followUpDate: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
      notes: "증상이 심해지면 재방문",
      createdBy: user.id,
    },
  });

  await prisma.expense.createMany({
    data: [
      {
        dogId: dog.id,
        medicalVisitId: visit.id,
        expenseCategory: "hospital",
        amount: 52000,
        expenseDate: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000),
        vendorName: "동네동물병원",
        memo: "진료 및 세정",
        createdBy: user.id,
      },
      {
        dogId: dog.id,
        expenseCategory: "food",
        amount: 38000,
        expenseDate: new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000),
        vendorName: "펫푸드몰",
        memo: "저알러지 사료",
        createdBy: user.id,
      },
      {
        dogId: dog.id,
        expenseCategory: "grooming",
        amount: 45000,
        expenseDate: new Date(now.getTime() - 18 * 24 * 60 * 60 * 1000),
        vendorName: "동네미용실",
        memo: "위생 미용",
        createdBy: user.id,
      },
    ],
  });

  await recalculateCostForecasts(prisma, dog.id);
  const report = await buildVisitReport(prisma, dog.id, user.id);

  console.log(
    JSON.stringify(
      {
        ok: true,
        account: {
          email: demoAccount.email,
          password: demoAccount.password,
        },
        dogId: Number(dog.id),
        dogName: dog.name,
        reportId: Number(report.id),
      },
      null,
      2,
    ),
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
