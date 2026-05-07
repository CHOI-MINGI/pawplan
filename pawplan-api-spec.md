# PawPlan API 명세

작성일: 2026-04-21  
버전: v1  
스타일: REST API  
Base URL: `/api/v1`

---

## 1. 목적

이 문서는 PawPlan MVP 구현을 위한 API 명세 초안이다.  
목표는 아래 3가지다.

- 프론트엔드와 백엔드의 개발 기준을 통일한다.
- 핵심 사용자 흐름을 API 기준으로 정리한다.
- DB 설계와 화면 와이어프레임 사이를 연결한다.

---

## 2. 공통 규칙

## 2.1 인증 방식

- 로그인 이후 `JWT Access Token` 사용
- 헤더 예시:

```http
Authorization: Bearer {access_token}
```

## 2.2 응답 형식

성공 응답 예시:

```json
{
  "success": true,
  "data": {
    "id": 1
  }
}
```

실패 응답 예시:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "breed is required"
  }
}
```

## 2.3 날짜/시간 규칙

- 날짜: `YYYY-MM-DD`
- 일시: ISO 8601 (`2026-04-21T10:30:00+09:00`)

## 2.4 상태 코드 규칙

- `200 OK`: 조회/수정 성공
- `201 Created`: 생성 성공
- `400 Bad Request`: 요청 파라미터 오류
- `401 Unauthorized`: 인증 실패
- `403 Forbidden`: 권한 없음
- `404 Not Found`: 리소스 없음
- `409 Conflict`: 중복 데이터
- `500 Internal Server Error`: 서버 오류

## 2.5 보안 및 개인정보 원칙

- 모든 인증 필요 API는 `Authorization` 헤더의 JWT를 검증한다.
- 비밀번호는 `bcrypt`로 해시하고, 응답에 비밀번호 관련 값을 절대 포함하지 않는다.
- JWT secret, DB 접속 정보, 파일 저장 경로는 환경변수로 관리한다.
- 반려견 건강 기록, 병원 방문 기록, 처방, 영수증 이미지는 민감 정보로 취급한다.
- 첨부 파일은 MVP에서도 공개 정적 URL만으로 노출하지 않고, 인증된 사용자만 접근 가능한 다운로드/조회 엔드포인트를 통해 제공한다.
- 반려견 삭제 또는 사용자 탈퇴 시 연결된 건강 기록, 지출, 리포트, 첨부 파일 삭제 정책을 별도로 구현한다.
- 운영 환경에서는 HTTPS를 전제로 한다.

## 2.6 의료 정보 표현 원칙

- API와 화면은 진단, 처방, 치료 판단을 제공하지 않는다.
- 병원 방문 리포트는 보호자가 입력한 최근 기록을 정리하는 용도이며 수의사 진료를 대체하지 않는다.
- 리포트 응답에는 사용자에게 보여줄 안내 문구를 포함한다.

---

## 3. MVP 핵심 사용자 흐름과 API 매핑

### 3.1 첫 사용자 흐름

1. 회원가입
2. 로그인
3. 반려견 온보딩 초기화
4. 초기 케어 일정 자동 생성
5. 초기 비용 예측 자동 생성
6. 홈 대시보드 조회

### 3.2 일상 사용 흐름

1. 홈 대시보드 조회
2. 통합 타임라인 조회
3. 건강 로그 추가 또는 병원 방문 기록 추가
4. 지출 추가
5. 건강 상태/복약 정보 추가 또는 수정
6. 일정 완료 처리
7. 비용 예측 자동 갱신

### 3.3 병원 방문 흐름

1. 병원 방문 기록 등록
2. 필요 시 병원비 지출 자동 생성
3. 영수증/처방전 첨부
4. 병원 리포트 생성
5. 리포트 조회/공유

---

## 4. 인증 API

## 4.1 회원가입

`POST /auth/register`

Request:

```json
{
  "email": "user@example.com",
  "password": "Password123!",
  "name": "홍길동",
  "phone": "01012345678"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com",
    "name": "홍길동"
  }
}
```

## 4.2 로그인

`POST /auth/login`

Request:

```json
{
  "email": "user@example.com",
  "password": "Password123!"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "accessToken": "jwt-token",
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "홍길동"
    }
  }
}
```

## 4.3 내 정보 조회

`GET /auth/me`

Response:

```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com",
    "name": "홍길동",
    "phone": "01012345678"
  }
}
```

---

## 5. 반려견 프로필 API

## 5.1 온보딩 초기화

첫 등록 흐름은 개별 API를 연속 호출하는 대신, 아래 엔드포인트 하나로 처리하는 것을 권장한다.  
서버는 내부적으로 `dogs`, `dog_conditions`, `dog_medications`, `care_schedules`, `cost_forecasts` 생성을 하나의 트랜잭션으로 묶는다.

`POST /onboarding/dogs`

Request:

```json
{
  "dog": {
    "name": "코코",
    "breed": "Maltese",
    "birthDate": "2020-03-01",
    "sex": "female",
    "neutered": true,
    "currentWeightKg": 4.8,
    "targetWeightKg": 4.5,
    "activityLevel": "medium",
    "insuranceStatus": "none",
    "notes": "닭고기 알레르기 의심"
  },
  "conditions": [
    {
      "conditionType": "allergy",
      "conditionName": "닭고기 알레르기",
      "severity": "medium",
      "status": "active"
    }
  ],
  "medications": [
    {
      "medicationName": "피부약 A",
      "dosage": "1 tablet",
      "frequencyText": "하루 2회",
      "startedOn": "2026-04-20",
      "isActive": true
    }
  ],
  "baseDate": "2026-04-21"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "dogId": 101,
    "generatedScheduleCount": 6,
    "forecastSummary": {
      "monthlyEstimate": 210000,
      "yearlyEstimate": 2400000
    }
  }
}
```

## 5.2 반려견 등록

`POST /dogs`

Request:

```json
{
  "name": "코코",
  "breed": "Maltese",
  "birthDate": "2020-03-01",
  "sex": "female",
  "neutered": true,
  "currentWeightKg": 4.8,
  "targetWeightKg": 4.5,
  "activityLevel": "medium",
  "insuranceStatus": "none",
  "notes": "닭고기 알레르기 의심"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": 101,
    "name": "코코"
  }
}
```

## 5.3 반려견 목록 조회

`GET /dogs`

Response:

```json
{
  "success": true,
  "data": [
    {
      "id": 101,
      "name": "코코",
      "breed": "Maltese",
      "currentWeightKg": 4.8
    }
  ]
}
```

## 5.4 반려견 상세 조회

`GET /dogs/{dogId}`

Response:

```json
{
  "success": true,
  "data": {
    "id": 101,
    "name": "코코",
    "breed": "Maltese",
    "birthDate": "2020-03-01",
    "sex": "female",
    "neutered": true,
    "currentWeightKg": 4.8,
    "targetWeightKg": 4.5,
    "activityLevel": "medium",
    "insuranceStatus": "none",
    "notes": "닭고기 알레르기 의심"
  }
}
```

## 5.5 반려견 수정

`PATCH /dogs/{dogId}`

Request:

```json
{
  "currentWeightKg": 4.9,
  "insuranceStatus": "planned"
}
```

비고:

- 반려견 수정 시 서버는 관련 비용 예측을 자동으로 재계산해야 한다.

## 5.6 반려견 삭제 영향도 확인

`GET /dogs/{dogId}/delete-preview`

삭제 전 사용자에게 보여줄 영향도 정보를 반환한다. 현재 MVP에서는 주 보호자 소유 펫 전체 삭제만 지원하므로 `scope`는 `pet`, `accessPolicy`는 `primary_owner_only`로 고정한다.

Response:

```json
{
  "success": true,
  "data": {
    "dog": {
      "id": 1,
      "name": "콩이"
    },
    "scope": "pet",
    "accessPolicy": "primary_owner_only",
    "counts": {
      "schedules": 12,
      "conditions": 2,
      "medications": 1,
      "healthLogs": 34,
      "medicalVisits": 5,
      "expenses": 18,
      "forecasts": 6,
      "visitReports": 1,
      "attachments": 3
    },
    "attachmentBytes": 245760
  }
}
```

## 5.7 반려견 삭제

`DELETE /dogs/{dogId}`

현재 MVP에서는 가족 공유 멤버십이 없으므로 삭제 범위는 “주 보호자가 소유한 펫 전체 삭제”로 고정한다. 삭제 시 연결된 일정, 건강 상태, 복약, 건강 기록, 병원 방문, 첨부 파일 메타데이터, 지출, 비용 예측, 리포트가 함께 삭제된다. 병원 방문 첨부의 실제 업로드 파일도 서버 저장소에서 삭제한다.

향후 가족 공유가 추가되면 이 엔드포인트는 `owner` 권한 사용자에게만 허용하고, 공유 가족이 자신의 목록에서 펫을 제거하는 동작은 별도 membership leave/remove API로 분리한다.

Response:

```json
{
  "success": true,
  "data": {
    "deleted": true,
    "scope": "pet",
    "accessPolicy": "primary_owner_only"
  }
}
```

## 5.8 반려견 멤버 목록

`GET /dogs/{dogId}/members`

active 멤버십이 있는 사용자는 멤버 목록을 조회할 수 있다.

## 5.9 반려견 멤버 추가

`POST /dogs/{dogId}/members`

현재 구현은 기존 가입자 이메일을 찾아 즉시 active 멤버십을 추가한다. 이메일 초대/수락 플로우는 별도 초대 API에서 구현한다. 이 API는 `owner` 권한이 필요하다.

Request:

```json
{
  "email": "family@example.com",
  "role": "viewer"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": 10,
    "dogId": 1,
    "userId": 2,
    "role": "viewer",
    "status": "active",
    "user": {
      "id": 2,
      "email": "family@example.com",
      "name": "가족"
    }
  }
}
```

## 5.10 반려견 멤버 역할 변경

`PATCH /dog-memberships/{membershipId}`

`owner` 권한이 필요하다. 본인의 owner 멤버십은 직접 강등하거나 제거할 수 없다.

Request:

```json
{
  "role": "editor"
}
```

## 5.11 반려견 멤버 제거

`DELETE /dog-memberships/{membershipId}`

멤버십을 물리 삭제하지 않고 `status = removed`로 변경한다. 공유받은 사용자는 이후 반려견 목록에서 해당 펫을 볼 수 없다.

---

## 6. 건강 배경 API

## 6.1 건강 상태 목록 조회

`GET /dogs/{dogId}/conditions`

## 6.2 건강 상태 등록

`POST /dogs/{dogId}/conditions`

Request:

```json
{
  "conditionType": "allergy",
  "conditionName": "닭고기 알레르기",
  "severity": "medium",
  "diagnosedOn": "2025-11-10",
  "status": "active",
  "notes": "사료 변경 필요"
}
```

## 6.3 건강 상태 수정

`PATCH /conditions/{conditionId}`

## 6.4 건강 상태 삭제

`DELETE /conditions/{conditionId}`

## 6.5 복용약 목록 조회

`GET /dogs/{dogId}/medications`

## 6.6 복용약 등록

`POST /dogs/{dogId}/medications`

Request:

```json
{
  "medicationName": "피부약 A",
  "dosage": "1 tablet",
  "frequencyText": "하루 2회",
  "startedOn": "2026-04-20",
  "endedOn": "2026-04-27",
  "prescribedBy": "OO동물병원",
  "isActive": true,
  "notes": "식후 복용"
}
```

## 6.7 복용약 수정

`PATCH /medications/{medicationId}`

## 6.8 복용약 삭제

`DELETE /medications/{medicationId}`

---

## 7. 케어 플랜 API

## 7.1 초기 케어 플랜 생성

반려견 프로필 등록 직후 호출하거나 백엔드 이벤트로 처리할 수 있다.

`POST /dogs/{dogId}/care-schedules/generate`

Request:

```json
{
  "baseDate": "2026-04-21"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "generatedCount": 6
  }
}
```

## 7.2 일정 목록 조회

`GET /dogs/{dogId}/care-schedules?from=2026-04-01&to=2026-04-30&status=pending`

Response:

```json
{
  "success": true,
  "data": [
    {
      "id": 301,
      "scheduleType": "heartworm",
      "title": "심장사상충 예방",
      "dueDate": "2026-04-25",
      "status": "pending",
      "priority": "high"
    }
  ]
}
```

## 7.3 일정 수동 등록

`POST /dogs/{dogId}/care-schedules`

Request:

```json
{
  "scheduleType": "checkup",
  "title": "정기 검진",
  "description": "봄철 건강검진",
  "dueDate": "2026-05-03",
  "repeatCycleDays": 180,
  "priority": "medium",
  "sourceType": "manual"
}
```

## 7.4 일정 상세 조회

`GET /care-schedules/{scheduleId}`

## 7.5 일정 수정

`PATCH /care-schedules/{scheduleId}`

## 7.6 일정 완료 처리

`POST /care-schedules/{scheduleId}/complete`

반복 일정(`repeatCycleDays`가 있는 일정)을 완료하면 서버가 다음 회차 일정을 자동 생성한다. 다음 회차는 기존 일정의 `reminderEnabled` 값을 그대로 상속한다.

Request:

```json
{
  "completedAt": "2026-04-25T09:00:00+09:00"
}
```

## 7.7 일정 건너뛰기

`POST /care-schedules/{scheduleId}/skip`

반복 일정을 건너뛰는 경우에도 완료 처리와 동일하게 다음 회차 일정을 자동 생성한다. 이미 완료되었거나 건너뛴 일정에 같은 요청이 다시 들어오면 추가 회차를 중복 생성하지 않는다.

---

## 8. 건강 로그 API

## 8.1 건강 로그 목록 조회

`GET /dogs/{dogId}/health-logs?type=weight&from=2026-04-01&to=2026-04-30&page=1&pageSize=20`

Response:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 401,
        "logType": "weight",
        "title": "체중 기록",
        "recordedAt": "2026-04-21T08:30:00+09:00",
        "valueNumeric": 4.8,
        "valueUnit": "kg",
        "memo": "아침 식전 측정"
      }
    ],
    "page": 1,
    "pageSize": 20,
    "total": 1
  }
}
```

## 8.2 건강 로그 등록

`POST /dogs/{dogId}/health-logs`

Request:

```json
{
  "logType": "meal",
  "title": "아침 식사",
  "recordedAt": "2026-04-21T08:00:00+09:00",
  "memo": "잘 먹음",
  "metadata": {
    "foodName": "저알러지 사료",
    "amountGram": 80
  }
}
```

다른 예시: 체중 로그

```json
{
  "logType": "weight",
  "title": "체중 기록",
  "recordedAt": "2026-04-21T08:30:00+09:00",
  "valueNumeric": 4.8,
  "valueUnit": "kg",
  "memo": "아침 식전 측정"
}
```

## 8.3 건강 로그 상세 조회

`GET /health-logs/{logId}`

## 8.4 건강 로그 수정

`PATCH /health-logs/{logId}`

## 8.5 건강 로그 삭제

`DELETE /health-logs/{logId}`

## 8.6 통합 타임라인 조회

기록 탭은 `health_logs`, `medical_visits`, `expenses`를 합친 통합 피드를 사용한다.
`type`은 `all`, `health_log`, `medical_visit`, `expense` 중 하나이며, 호환 입력으로 `health`, `visit`도 허용한다.

`GET /dogs/{dogId}/timeline?from=2026-04-01&to=2026-04-30&type=all&page=1&pageSize=20`

Response:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "itemType": "health_log",
        "id": 401,
        "logType": "weight",
        "title": "체중 기록",
        "eventAt": "2026-04-21T08:30:00+09:00",
        "summary": "4.8kg"
      },
      {
        "itemType": "medical_visit",
        "id": 501,
        "eventAt": "2026-04-20T14:00:00+09:00",
        "title": "OO동물병원 방문",
        "summary": "피부 가려움 상담",
        "hospitalName": "OO동물병원",
        "attachmentCount": 1
      },
      {
        "itemType": "expense",
        "id": 601,
        "eventAt": "2026-04-19",
        "title": "food 지출",
        "summary": "동네펫샵",
        "expenseCategory": "food",
        "amount": 42000
      }
    ],
    "page": 1,
    "pageSize": 20,
    "total": 3,
    "type": "all"
  }
}
```

---

## 9. 병원 방문 API

## 9.1 병원 방문 목록 조회

`GET /dogs/{dogId}/medical-visits?page=1&pageSize=20`

## 9.2 병원 방문 등록

`POST /dogs/{dogId}/medical-visits`

Request:

```json
{
  "hospitalName": "OO동물병원",
  "veterinarianName": "김수의사",
  "visitDate": "2026-04-20T14:00:00+09:00",
  "visitReason": "피부 가려움",
  "symptoms": "귀를 자주 긁음",
  "diagnosis": "피부염 의심",
  "treatment": "약 처방",
  "prescribedItems": "피부약 A, 귀 세정제",
  "followUpDate": "2026-04-27",
  "notes": "1주일 경과 관찰",
  "expense": {
    "create": true,
    "amount": 80000,
    "expenseDate": "2026-04-20",
    "vendorName": "OO동물병원",
    "memo": "피부염 진료비"
  }
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": 501,
    "expenseId": 801
  }
}
```

비고:

- 병원비의 회계 기준 데이터는 `expenses`다.
- 병원 방문 저장 시 `expense.create = true`이면 연결된 지출 레코드를 함께 생성한다.
- 이후 비용 예측은 자동 재계산되어야 한다.

## 9.3 병원 방문 상세 조회

`GET /medical-visits/{visitId}`

## 9.4 병원 방문 첨부 목록 조회

`GET /medical-visits/{visitId}/attachments`

## 9.5 병원 방문 첨부 업로드

`POST /medical-visits/{visitId}/attachments`

Request: `multipart/form-data`

| 필드     | 설명                                                       |
| -------- | ---------------------------------------------------------- |
| file     | 업로드할 이미지 또는 문서 파일                             |
| fileType | `receipt`, `prescription`, `test_result`, `image`, `other` |

비고:

- 파일은 공개 정적 URL로 노출하지 않는다.
- 응답의 `fileUrl`은 서버 내부 저장 경로이며, 클라이언트는 다운로드 API를 사용한다.

## 9.6 병원 방문 첨부 다운로드

`GET /attachments/{attachmentId}/download`

## 9.7 병원 방문 첨부 삭제

`DELETE /attachments/{attachmentId}`

## 9.8 병원 방문 수정

`PATCH /medical-visits/{visitId}`

## 9.9 병원 방문 삭제

`DELETE /medical-visits/{visitId}`

Response:

```json
{
  "success": true,
  "data": {
    "deleted": true
  }
}
```

비고:

- 연결된 지출 기록은 삭제하지 않고 `medicalVisitId`만 해제한다.
- 연결된 첨부파일은 DB 레코드와 실제 저장 파일을 함께 삭제한다.
- 삭제 후 비용 예측은 다시 계산한다.

---

## 10. 지출 API

## 10.1 지출 목록 조회

`GET /dogs/{dogId}/expenses?from=2026-04-01&to=2026-04-30&category=hospital&page=1&pageSize=20`

## 10.2 지출 등록

`POST /dogs/{dogId}/expenses`

Request:

```json
{
  "medicalVisitId": 501,
  "expenseCategory": "hospital",
  "amount": 80000,
  "expenseDate": "2026-04-20",
  "vendorName": "OO동물병원",
  "memo": "피부염 진료비"
}
```

## 10.3 지출 상세 조회

`GET /expenses/{expenseId}`

## 10.4 지출 수정

`PATCH /expenses/{expenseId}`

## 10.5 지출 삭제

`DELETE /expenses/{expenseId}`

## 10.6 월별 지출 요약

`GET /dogs/{dogId}/expenses/summary?year=2026&month=4`

Response:

```json
{
  "success": true,
  "data": {
    "totalAmount": 182000,
    "byCategory": [
      { "category": "hospital", "amount": 80000 },
      { "category": "food", "amount": 52000 },
      { "category": "supplies", "amount": 50000 }
    ]
  }
}
```

---

## 11. 비용 예측 API

## 11.1 최신 비용 예측 조회

`GET /dogs/{dogId}/cost-forecasts/latest`

Response:

```json
{
  "success": true,
  "data": {
    "basic": {
      "monthlyEstimate": 210000,
      "rangeMin": 180000,
      "rangeMax": 240000,
      "yearlyEstimate": 2400000,
      "sixMonthEstimate": 1260000,
      "lifetimeEstimate": 18000000,
      "confidenceLevel": "medium",
      "breakdown": {
        "fixedCost": 120000,
        "plannedCareCost": 50000,
        "riskAdjustedCost": 40000
      }
    },
    "caution": {
      "monthlyEstimate": 260000,
      "rangeMin": 230000,
      "rangeMax": 300000,
      "yearlyEstimate": 3100000,
      "sixMonthEstimate": 1560000,
      "lifetimeEstimate": 22000000,
      "confidenceLevel": "medium",
      "breakdown": {
        "fixedCost": 120000,
        "plannedCareCost": 50000,
        "riskAdjustedCost": 90000
      }
    },
    "highRisk": {
      "monthlyEstimate": 340000,
      "rangeMin": 300000,
      "rangeMax": 390000,
      "yearlyEstimate": 4100000,
      "sixMonthEstimate": 2040000,
      "lifetimeEstimate": 29000000,
      "confidenceLevel": "medium",
      "breakdown": {
        "fixedCost": 120000,
        "plannedCareCost": 50000,
        "riskAdjustedCost": 170000
      }
    },
    "generatedAt": "2026-04-21T11:20:00+09:00"
  }
}
```

DB 매핑:

- `monthlyEstimate` -> `cost_forecasts.monthly_estimate`
- `rangeMin` -> `cost_forecasts.range_min`
- `rangeMax` -> `cost_forecasts.range_max`
- `yearlyEstimate` -> `cost_forecasts.yearly_estimate`
- `sixMonthEstimate` -> `cost_forecasts.six_month_estimate`
- `lifetimeEstimate` -> `cost_forecasts.lifetime_estimate`
- `confidenceLevel` -> `cost_forecasts.confidence_level`
- `breakdown` -> `cost_forecasts.breakdown`
- 계산 가정과 입력값 -> `cost_forecasts.assumptions`

## 11.2 비용 예측 재계산

이 API는 운영자 테스트, 디버깅, 수동 재계산 용도로만 남긴다.  
일반 사용자 흐름에서는 아래 이벤트에 의해 자동 재계산되는 것을 기본으로 한다.

- 반려견 프로필 수정
- 건강 상태 수정
- 복용약 수정
- 지출 생성/수정/삭제
- 병원 방문 생성/수정 시 연결 지출 변경

`POST /dogs/{dogId}/cost-forecasts/recalculate`

Request:

```json
{
  "trigger": "profile_updated"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "generatedCount": 3
  }
}
```

## 11.3 비용 예측 이력 조회

`GET /dogs/{dogId}/cost-forecasts/history?page=1&pageSize=10`

---

## 12. 병원 방문 리포트 API

## 12.1 병원 방문 리포트 생성

`POST /dogs/{dogId}/visit-reports`

Request:

```json
{
  "reportType": "vet_visit_summary"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "id": 701,
    "title": "2026-04-21 병원 방문 리포트"
  }
}
```

## 12.2 병원 방문 리포트 상세 조회

`GET /visit-reports/{reportId}`

Response:

```json
{
  "success": true,
  "data": {
    "id": 701,
    "title": "2026-04-21 병원 방문 리포트",
    "summary": {
      "dog": {
        "name": "코코",
        "breed": "Maltese",
        "ageYears": 6,
        "currentWeightKg": 4.8
      },
      "recentSymptoms": ["3일 전부터 귀를 자주 긁음"],
      "weightTrend": {
        "previousWeightKg": 4.6,
        "currentWeightKg": 4.8
      },
      "activeMedications": ["피부약 A 하루 2회"],
      "conditions": ["닭고기 알레르기"],
      "recentVisits": ["2026-04-03 피부 진료"]
    },
    "notice": "이 리포트는 보호자가 입력한 기록을 병원 방문 전에 정리하기 위한 자료이며, 진단이나 치료 판단을 대체하지 않습니다.",
    "pdfUrl": null,
    "generatedAt": "2026-04-21T11:30:00+09:00"
  }
}
```

## 12.3 최신 병원 방문 리포트 조회

`GET /dogs/{dogId}/visit-reports/latest`

## 12.4 병원 방문 리포트 목록 조회

`GET /dogs/{dogId}/visit-reports?page=1&pageSize=20`

---

## 13. 홈 대시보드 API

프론트에서 홈 화면을 효율적으로 그리기 위해 집계 API를 별도로 두는 것이 좋다.

## 13.1 홈 대시보드 조회

`GET /dogs/{dogId}/dashboard`

Response:

```json
{
  "success": true,
  "data": {
    "dog": {
      "id": 101,
      "name": "코코",
      "breed": "Maltese"
    },
    "todaySchedules": [
      {
        "id": 301,
        "title": "심장사상충 예방",
        "dueDate": "2026-04-25",
        "status": "pending"
      }
    ],
    "recentHealthLogs": [
      {
        "id": 401,
        "logType": "weight",
        "title": "체중 기록",
        "recordedAt": "2026-04-21T08:30:00+09:00",
        "summary": "4.8kg"
      }
    ],
    "monthlyExpenseSummary": {
      "totalAmount": 182000,
      "byCategory": [
        { "category": "hospital", "amount": 80000 },
        { "category": "food", "amount": 52000 }
      ]
    },
    "latestForecast": {
      "monthlyEstimate": 210000,
      "yearlyEstimate": 2400000
    },
    "access": {
      "role": "owner",
      "canManage": true
    }
  }
}
```

---

## 14. 디바이스 / 알림 API

MVP에서는 Flutter 앱의 로컬 알림을 사용하므로 서버 디바이스/푸시 API는 필수가 아니다.  
아래 API는 FCM 기반 서버 푸시를 도입하는 2차 확장 범위로 둔다.

## 14.1 디바이스 등록

`POST /devices`

Request:

```json
{
  "platform": "android",
  "pushToken": "fcm-token",
  "timezone": "Asia/Seoul",
  "notificationsEnabled": true
}
```

## 14.2 디바이스 수정

`PATCH /devices/{deviceId}`

Request:

```json
{
  "pushToken": "new-fcm-token",
  "notificationsEnabled": true
}
```

## 14.3 내 알림 설정 조회

`GET /me/notification-settings`

Response:

```json
{
  "success": true,
  "data": {
    "careReminderEnabled": true,
    "budgetAlertEnabled": true
  }
}
```

## 14.4 내 알림 설정 수정

`PATCH /me/notification-settings`

Request:

```json
{
  "careReminderEnabled": true,
  "budgetAlertEnabled": false
}
```

---

## 15. 권한 규칙

- 로그인한 사용자는 자신이 주 보호자이거나 `dog_memberships.status = active`인 반려견만 조회 가능
- `dog_memberships.role`은 `owner`, `editor`, `viewer`를 사용
- 현재 구현 범위에서는 주 보호자와 신규 생성 펫의 `owner` 멤버십을 항상 함께 유지
- 반려견 삭제, 삭제 영향도 확인, 주요 프로필 수정은 `owner` 권한으로 제한
- 향후 초대 API가 추가되면 `viewer`는 조회 전용, `editor`는 로그/일정/지출 작성 가능, `owner`는 멤버 관리와 펫 삭제 가능으로 분리

---

## 16. 유효성 검사 규칙

### 16.1 반려견 등록

- `name`, `breed`, `sex` 필수
- `currentWeightKg`는 0보다 커야 함

### 16.2 건강 로그

- `logType`, `recordedAt` 필수
- `weight` 로그는 `valueNumeric`, `valueUnit` 필수
- `meal` 로그는 `metadata.amountGram` 권장

### 16.3 일정

- `dueDate` 필수
- `scheduleType`, `title` 필수

### 16.4 지출

- `expenseCategory`, `amount`, `expenseDate` 필수
- `amount`는 0보다 커야 함

### 16.5 병원 방문

- `hospitalName`, `visitDate` 필수

### 16.6 건강 상태

- `conditionType`, `conditionName` 필수
- `severity`는 `low`, `medium`, `high` 중 하나 권장
- `status`는 `active`, `monitoring`, `resolved` 중 하나 권장

### 16.7 복약

- `medicationName` 필수
- `startedOn`, `endedOn`은 날짜 형식일 때만 허용
- `isActive`는 boolean 값이어야 함

---

## 17. 구현 우선순위

### 17.1 1차 API

- `/auth/register`
- `/auth/login`
- `/onboarding/dogs`
- `/dogs/{dogId}`
- `/dogs/{dogId}/conditions`
- `/dogs/{dogId}/medications`
- `/dogs/{dogId}/care-schedules`
- `/dogs/{dogId}/health-logs`
- `/dogs/{dogId}/medical-visits`
- `/medical-visits/{visitId}/attachments`
- `/attachments/{attachmentId}/download`
- `/dogs/{dogId}/expenses`
- `/dogs/{dogId}/dashboard`
- `/dogs/{dogId}/cost-forecasts/latest`
- `/dogs/{dogId}/cost-forecasts/recalculate`
- `/dogs/{dogId}/cost-forecasts/history`
- `/dogs/{dogId}/visit-reports`
- `/dogs/{dogId}/visit-reports/latest`

### 17.2 2차 API

- `/devices`
- `/me/notification-settings`

### 17.3 3차 API

- 가족 공유
- PDF 다운로드

---

## 18. 한 줄 정리

PawPlan API는  
`프로필 등록 -> 일정 생성 -> 로그/지출 입력 -> 예측 갱신 -> 리포트 생성` 흐름을 기준으로 설계하는 것이 가장 자연스럽다.
