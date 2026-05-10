// 스모크 테스트: 전체 API 흐름을 간단히 검증하는 E2E 테스트

const apiBaseUrl = (
  process.env.API_BASE_URL ?? "http://localhost:4000/api/v1"
).replace(/\/$/, "");
const rootUrl = apiBaseUrl.replace(/\/api\/v1$/, "");
const keepData = process.env.SMOKE_KEEP_DATA === "1";
let smokeEmail;
let smokeMemberEmail;

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function request(method, path, { token, body } = {}) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const decoded = text ? JSON.parse(text) : {};
  if (!response.ok || decoded.success !== true) {
    throw new Error(`${method} ${path} failed: ${response.status} ${text}`);
  }
  return decoded.data;
}

async function expectRequestFailure(
  method,
  path,
  { token, body, status } = {},
) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const decoded = text ? JSON.parse(text) : {};
  if (response.status !== status || decoded.success !== false) {
    throw new Error(
      `${method} ${path} expected ${status} failure, got ${response.status} ${text}`,
    );
  }
  return decoded.error;
}

async function uploadAttachment(
  path,
  { token, fileType, filename, bytes, mimeType },
) {
  const form = new FormData();
  form.set("fileType", fileType);
  form.set("file", new Blob([bytes], { type: mimeType }), filename);
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: form,
  });
  const text = await response.text();
  const decoded = text ? JSON.parse(text) : {};
  if (!response.ok || decoded.success !== true) {
    throw new Error(`POST ${path} upload failed: ${response.status} ${text}`);
  }
  return decoded.data;
}

async function downloadAttachment(attachmentId, { token }) {
  const response = await fetch(
    `${apiBaseUrl}/attachments/${attachmentId}/download`,
    {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    },
  );
  if (!response.ok) {
    throw new Error(
      `GET /attachments/${attachmentId}/download failed: ${response.status}`,
    );
  }
  return response.arrayBuffer();
}

async function healthCheck() {
  const response = await fetch(`${rootUrl}/health`);
  const data = await response.json();
  assert(response.ok && data.ok === true, "health check failed");
}

async function main() {
  await healthCheck();

  const suffix = `${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  const email = `smoke-${suffix}@pawplan.local`;
  smokeEmail = email;
  const password = "password123";

  await request("POST", "/auth/register", {
    body: { email, password, name: "스모크 보호자" },
  });

  const login = await request("POST", "/auth/login", {
    body: { email, password },
  });
  const token = login.accessToken;
  assert(
    typeof token === "string" && token.length > 20,
    "missing access token",
  );

  const onboarding = await request("POST", "/onboarding/dogs", {
    token,
    body: {
      dog: {
        name: "테스트견",
        breed: "Mixed",
        birthDate: "2021-04-01",
        sex: "female",
        neutered: true,
        currentWeightKg: 5.2,
        targetWeightKg: 5.0,
        activityLevel: "medium",
        insuranceStatus: "none",
      },
      conditions: [
        {
          conditionType: "chronic",
          conditionName: "피부 민감",
          severity: "low",
          status: "monitoring",
        },
      ],
    },
  });
  const dogId = onboarding.dogId;
  assert(Number.isInteger(dogId), "missing dog id");

  const memberEmail = `member-${suffix}@pawplan.local`;
  smokeMemberEmail = memberEmail;
  await request("POST", "/auth/register", {
    body: { email: memberEmail, password, name: "shared member" },
  });
  const memberLogin = await request("POST", "/auth/login", {
    body: { email: memberEmail, password },
  });
  const memberToken = memberLogin.accessToken;
  const membership = await request("POST", `/dogs/${dogId}/members`, {
    token,
    body: { email: memberEmail, role: "viewer" },
  });
  assert(
    membership.role === "viewer" && membership.user?.email === memberEmail,
    "dog member add failed",
  );
  const members = await request("GET", `/dogs/${dogId}/members`, { token });
  assert(
    members.some((item) => item.id === membership.id),
    "dog member not listed",
  );
  const memberDogs = await request("GET", "/dogs", { token: memberToken });
  assert(
    memberDogs.some((dog) => dog.id === dogId),
    "shared dog not listed for member",
  );
  const memberDashboard = await request("GET", `/dogs/${dogId}/dashboard`, {
    token: memberToken,
  });
  assert(memberDashboard.dog.id === dogId, "shared dog dashboard denied");
  assert(
    memberDashboard.access?.role === "viewer" &&
      memberDashboard.access?.canManage === false,
    "shared dog access role mismatch",
  );
  await expectRequestFailure("PATCH", `/dogs/${dogId}`, {
    token: memberToken,
    status: 404,
    body: { notes: "viewer cannot update dog profile" },
  });
  await expectRequestFailure("POST", `/dogs/${dogId}/health-logs`, {
    token: memberToken,
    status: 404,
    body: {
      logType: "symptom",
      title: "viewer write should fail",
    },
  });
  const editorMembership = await request(
    "PATCH",
    `/dog-memberships/${membership.id}`,
    {
      token,
      body: { role: "editor" },
    },
  );
  assert(editorMembership.role === "editor", "membership role update failed");
  const editorHealthLog = await request("POST", `/dogs/${dogId}/health-logs`, {
    token: memberToken,
    body: {
      logType: "symptom",
      title: "editor shared write",
    },
  });
  assert(
    Number.isInteger(editorHealthLog.id),
    "editor shared health log create failed",
  );
  await request("DELETE", `/health-logs/${editorHealthLog.id}`, { token });
  await request("DELETE", `/dog-memberships/${membership.id}`, { token });
  const memberDogsAfterRemove = await request("GET", "/dogs", {
    token: memberToken,
  });
  assert(
    !memberDogsAfterRemove.some((dog) => dog.id === dogId),
    "removed member can still list shared dog",
  );

  const dogs = await request("GET", "/dogs", { token });
  assert(
    dogs.some((dog) => dog.id === dogId),
    "created dog not listed",
  );

  const dogToDelete = await request("POST", "/dogs", {
    token,
    body: {
      name: "delete-scope-dog",
      breed: "Mixed",
      sex: "male",
      neutered: false,
    },
  });
  const deletePreview = await request(
    "GET",
    `/dogs/${dogToDelete.id}/delete-preview`,
    { token },
  );
  assert(
    deletePreview.dog?.id === dogToDelete.id &&
      deletePreview.scope === "pet" &&
      deletePreview.accessPolicy === "primary_owner_only",
    "dog delete preview policy mismatch",
  );
  await request("DELETE", `/dogs/${dogToDelete.id}`, { token });
  const dogsAfterDelete = await request("GET", "/dogs", { token });
  assert(
    !dogsAfterDelete.some((dog) => dog.id === dogToDelete.id),
    "deleted dog still listed",
  );
  assert(
    dogsAfterDelete.some((dog) => dog.id === dogId),
    "dog delete removed another dog",
  );

  const schedules = await request(
    "GET",
    `/dogs/${dogId}/care-schedules?status=pending`,
    { token },
  );
  assert(schedules.length > 0, "default care schedules were not generated");
  const recurringSchedule = schedules.find(
    (schedule) => schedule.repeatCycleDays,
  );
  assert(recurringSchedule, "recurring default care schedule missing");
  await request("POST", `/care-schedules/${recurringSchedule.id}/complete`, {
    token,
  });
  const afterCompleteSchedules = await request(
    "GET",
    `/dogs/${dogId}/care-schedules?status=pending`,
    { token },
  );
  assert(
    afterCompleteSchedules.some(
      (schedule) =>
        schedule.title === recurringSchedule.title &&
        schedule.id !== recurringSchedule.id &&
        schedule.reminderEnabled === recurringSchedule.reminderEnabled,
    ),
    "complete did not create next recurring schedule",
  );

  const manualRecurring = await request(
    "POST",
    `/dogs/${dogId}/care-schedules`,
    {
      token,
      body: {
        scheduleType: "medication",
        title: "반복 복약 점검",
        description: "알림 설정 상속 확인",
        dueDate: "2026-04-27",
        repeatCycleDays: 7,
        priority: "medium",
      },
    },
  );
  const disabledRecurring = await request(
    "PATCH",
    `/care-schedules/${manualRecurring.id}`,
    {
      token,
      body: {
        title: manualRecurring.title,
        description: manualRecurring.description,
        dueDate: "2026-04-27",
        priority: manualRecurring.priority,
        reminderEnabled: false,
      },
    },
  );
  await request("POST", `/care-schedules/${disabledRecurring.id}/skip`, {
    token,
  });
  const afterSkipSchedules = await request(
    "GET",
    `/dogs/${dogId}/care-schedules?status=pending`,
    { token },
  );
  assert(
    afterSkipSchedules.some(
      (schedule) =>
        schedule.title === disabledRecurring.title &&
        schedule.id !== disabledRecurring.id &&
        schedule.reminderEnabled === false,
    ),
    "skip did not create next recurring schedule with inherited reminder setting",
  );

  const condition = await request("POST", `/dogs/${dogId}/conditions`, {
    token,
    body: {
      conditionType: "allergy",
      conditionName: "닭고기 알레르기",
      severity: "medium",
      diagnosedOn: "2026-04-01",
      status: "active",
      notes: "간식 성분 확인 필요",
    },
  });
  const updatedCondition = await request(
    "PATCH",
    `/conditions/${condition.id}`,
    {
      token,
      body: {
        conditionType: "allergy",
        conditionName: "닭고기 알레르기 주의",
        severity: "high",
        diagnosedOn: "2026-04-01",
        status: "monitoring",
        notes: "사료 성분도 확인",
      },
    },
  );
  assert(
    updatedCondition.conditionName === "닭고기 알레르기 주의",
    "condition update failed",
  );

  const medication = await request("POST", `/dogs/${dogId}/medications`, {
    token,
    body: {
      medicationName: "귀 세정제",
      dosage: "2방울",
      frequencyText: "하루 1회",
      startedOn: "2026-04-26",
      prescribedBy: "테스트동물병원",
      isActive: true,
      notes: "일주일 사용",
    },
  });
  const updatedMedication = await request(
    "PATCH",
    `/medications/${medication.id}`,
    {
      token,
      body: {
        medicationName: "귀 세정제",
        dosage: "3방울",
        frequencyText: "하루 1회",
        startedOn: "2026-04-26",
        endedOn: "2026-05-03",
        prescribedBy: "테스트동물병원",
        isActive: false,
        notes: "증상 완화 후 중단",
      },
    },
  );
  assert(
    updatedMedication.dosage === "3방울" &&
      updatedMedication.isActive === false,
    "medication update failed",
  );

  const healthLog = await request("POST", `/dogs/${dogId}/health-logs`, {
    token,
    body: {
      logType: "symptom",
      title: "귀 긁음",
      memo: "오른쪽 귀를 자주 긁음",
      valueNumeric: 2,
      valueUnit: "회",
    },
  });
  const updatedHealthLog = await request(
    "PATCH",
    `/health-logs/${healthLog.id}`,
    {
      token,
      body: {
        logType: "symptom",
        title: "귀 긁음 감소",
        memo: "빈도 감소",
        valueNumeric: 1,
        valueUnit: "회",
      },
    },
  );
  assert(updatedHealthLog.title === "귀 긁음 감소", "health log update failed");

  const expense = await request("POST", `/dogs/${dogId}/expenses`, {
    token,
    body: {
      expenseCategory: "supplies",
      amount: 12000,
      expenseDate: "2026-04-26",
      vendorName: "펫샵",
      memo: "귀 세정제",
    },
  });
  const updatedExpense = await request("PATCH", `/expenses/${expense.id}`, {
    token,
    body: {
      expenseCategory: "supplies",
      amount: 15000,
      expenseDate: "2026-04-26",
      vendorName: "펫샵",
      memo: "귀 세정제 추가 구매",
    },
  });
  assert(Number(updatedExpense.amount) === 15000, "expense update failed");

  const visit = await request("POST", `/dogs/${dogId}/medical-visits`, {
    token,
    body: {
      hospitalName: "테스트동물병원",
      visitReason: "귀 가려움",
      symptoms: "오른쪽 귀 긁음",
      diagnosis: "외이염 의심",
      treatment: "귀 세정",
      prescribedItems: "귀 세정제",
      followUpDate: "2026-05-03",
      expense: {
        create: true,
        amount: 52000,
        expenseDate: "2026-04-26",
        vendorName: "테스트동물병원",
      },
    },
  });
  assert(Number.isInteger(visit.id), "medical visit create failed");
  assert(
    Number.isInteger(visit.expenseId),
    "linked visit expense create failed",
  );

  const attachment = await uploadAttachment(
    `/medical-visits/${visit.id}/attachments`,
    {
      token,
      fileType: "receipt",
      filename: "receipt.png",
      bytes: new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]),
      mimeType: "image/png",
    },
  );
  assert(Number.isInteger(attachment.id), "attachment create failed");
  const attachments = await request(
    "GET",
    `/medical-visits/${visit.id}/attachments`,
    { token },
  );
  assert(
    attachments.some((item) => item.id === attachment.id),
    "attachment not listed",
  );
  const downloaded = await downloadAttachment(attachment.id, { token });
  assert(downloaded.byteLength > 0, "attachment download failed");
  await request("DELETE", `/attachments/${attachment.id}`, { token });
  const afterAttachmentDelete = await request(
    "GET",
    `/medical-visits/${visit.id}/attachments`,
    { token },
  );
  assert(
    !afterAttachmentDelete.some((item) => item.id === attachment.id),
    "deleted attachment still listed",
  );

  const updatedVisit = await request("PATCH", `/medical-visits/${visit.id}`, {
    token,
    body: {
      hospitalName: "테스트동물병원",
      visitReason: "귀 가려움 재확인",
      symptoms: "증상 완화",
      diagnosis: "외이염 경미",
      treatment: "세정 지속",
      prescribedItems: "귀 세정제",
      followUpDate: "2026-05-10",
      notes: "일주일 뒤 상태 확인",
    },
  });
  assert(
    updatedVisit.visitReason === "귀 가려움 재확인",
    "medical visit update failed",
  );

  const report = await request("POST", `/dogs/${dogId}/visit-reports`, {
    token,
  });
  assert(Number.isInteger(report.id), "visit report create failed");
  const latestReport = await request(
    "GET",
    `/dogs/${dogId}/visit-reports/latest`,
    { token },
  );
  assert(latestReport?.id === report.id, "latest visit report mismatch");

  const dashboard = await request("GET", `/dogs/${dogId}/dashboard`, { token });
  assert(dashboard.dog.id === dogId, "dashboard dog mismatch");

  const latestForecast = await request(
    "GET",
    `/dogs/${dogId}/cost-forecasts/latest`,
    {
      token,
    },
  );
  assert(latestForecast.basic?.monthlyEstimate > 0, "latest forecast missing");
  const recalculate = await request(
    "POST",
    `/dogs/${dogId}/cost-forecasts/recalculate`,
    {
      token,
    },
  );
  assert(recalculate.generatedCount === 3, "forecast recalculate failed");
  const forecastHistory = await request(
    "GET",
    `/dogs/${dogId}/cost-forecasts/history?pageSize=6`,
    {
      token,
    },
  );
  assert(forecastHistory.items?.length >= 3, "forecast history missing");

  const timeline = await request("GET", `/dogs/${dogId}/timeline?pageSize=20`, {
    token,
  });
  assert(
    timeline.items?.some(
      (item) => item.itemType === "health_log" && item.id === healthLog.id,
    ),
    "timeline health log item missing",
  );
  assert(
    timeline.items?.some(
      (item) => item.itemType === "medical_visit" && item.id === visit.id,
    ),
    "timeline medical visit item missing",
  );
  assert(
    timeline.items?.some(
      (item) => item.itemType === "expense" && item.id === expense.id,
    ),
    "timeline expense item missing",
  );
  const expenseTimeline = await request(
    "GET",
    `/dogs/${dogId}/timeline?type=expense&pageSize=20`,
    {
      token,
    },
  );
  assert(expenseTimeline.type === "expense", "timeline type filter mismatch");
  assert(
    expenseTimeline.items?.every((item) => item.itemType === "expense"),
    "timeline expense filter returned non-expense item",
  );

  await request("DELETE", `/medical-visits/${visit.id}`, { token });
  const linkedExpense = await request("GET", `/expenses/${visit.expenseId}`, {
    token,
  });
  assert(
    linkedExpense.medicalVisitId === null,
    "linked expense was not detached after visit delete",
  );

  await request("DELETE", `/health-logs/${healthLog.id}`, { token });
  await request("DELETE", `/expenses/${expense.id}`, { token });
  await request("DELETE", `/conditions/${condition.id}`, { token });
  await request("DELETE", `/medications/${medication.id}`, { token });

  const finalVisits = await request(
    "GET",
    `/dogs/${dogId}/medical-visits?pageSize=20`,
    { token },
  );
  assert(
    !finalVisits.items?.some((item) => item.id === visit.id),
    "deleted visit still listed",
  );

  console.log(
    JSON.stringify(
      {
        ok: true,
        apiBaseUrl,
        email,
        cleanup: keepData ? "skipped" : "enabled",
        dogId,
        checked: [
          "auth",
          "onboarding",
          "family sharing viewer/editor permissions",
          "dog delete preview/scope",
          "care schedule complete",
          "recurring care schedule continue",
          "condition create/update/delete",
          "medication create/update/delete",
          "health log create/update/delete",
          "expense create/update/delete",
          "medical visit create/update/delete",
          "medical visit attachment upload/list/download/delete",
          "forecast latest/recalculate/history",
          "timeline health/visit/expense",
          "visit report",
          "dashboard",
        ],
      },
      null,
      2,
    ),
  );
}

async function cleanup() {
  if (keepData || !smokeEmail) return;
  const { PrismaClient } = await import("@prisma/client");
  const prisma = new PrismaClient();
  try {
    const user = await prisma.user.findUnique({
      where: { email: smokeEmail },
      select: { id: true },
    });
    if (user) {
      await prisma.dog.deleteMany({ where: { primaryOwnerId: user.id } });
      await prisma.user.delete({ where: { id: user.id } });
    }
    if (smokeMemberEmail) {
      await prisma.user.deleteMany({ where: { email: smokeMemberEmail } });
    }
  } finally {
    await prisma.$disconnect();
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(cleanup);
