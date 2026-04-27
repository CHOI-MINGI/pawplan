# PawPlan Backend

Express + Prisma + PostgreSQL 기반 PawPlan MVP API 서버입니다.

## 실행 준비

```powershell
cd H:\programming\jonsulpu\backend
copy .env.example .env
npm install
npm run prisma:generate
```

PostgreSQL은 repo root의 Docker Compose로 실행합니다.

```powershell
cd H:\programming\jonsulpu
docker compose up -d postgres
```

Docker Desktop 엔진이 실행 중이어야 합니다. 엔진이 준비되면 migration을 적용합니다.

```powershell
cd H:\programming\jonsulpu\backend
npm run prisma:migrate -- --name init
```

## 개발 서버

```powershell
npm run dev
```

기본 URL:

- Health check: `GET http://localhost:4000/health`
- API base: `http://localhost:4000/api/v1`
- Android emulator access: `http://10.0.2.2:4000/api/v1`

개발 서버는 기본적으로 `HOST=0.0.0.0`에 바인딩합니다. Android 에뮬레이터에서 호스트 PC의 API에 접근하려면 이 설정이 필요합니다.

## Railway 배포

Railway에서는 GitHub 저장소를 연결하고 백엔드 서비스의 Root Directory를 `backend`로 설정합니다. 배포 설정은 `railway.json`에 포함되어 있으며, 자세한 절차는 `RAILWAY.md`를 참고합니다.

필수 환경변수:

- `NODE_ENV=production`
- `JWT_SECRET`
- `DATABASE_URL`
- `CORS_ORIGIN=*`
- `UPLOAD_ROOT=/data/uploads` - 첨부파일을 유지하려면 Railway Volume을 `/data`에 마운트합니다.

## 검증

서버와 PostgreSQL이 실행 중인 상태에서 API E2E 스모크 검증을 실행합니다.

```powershell
cd H:\programming\jonsulpu\backend
npm run smoke:e2e
```

기본값은 테스트 데이터 정리입니다. 확인용 데이터를 남기고 싶을 때만 `SMOKE_KEEP_DATA=1`을 지정합니다.

검증 범위:

- 회원가입, 로그인, JWT 인증
- 반려견 온보딩과 기본 일정 생성
- 일정 완료/건너뛰기와 반복 일정 다음 회차 생성
- 건강 기록 생성, 수정, 삭제
- 지출 생성, 수정, 삭제
- 병원 방문 생성, 수정, 삭제
- 건강/병원/지출 통합 타임라인 조회
- 비용 예측 최신값, 재계산, 이력 조회
- 방문 리포트 생성과 최신 리포트 조회
- 대시보드 조회

## 데모 데이터

앱을 바로 확인할 수 있는 기본 계정과 기록 데이터를 생성합니다. 반복 실행하면 기존 데모 반려견 데이터를 지우고 다시 만듭니다.

```powershell
cd H:\programming\jonsulpu\backend
npm run seed:demo
```

데모 계정:

- Email: `demo@pawplan.kr`
- Password: `password123`

## 현재 구현된 MVP 범위

- 이메일 회원가입, 로그인, JWT 인증
- 반려견 등록 및 온보딩 초기화
- 기본 케어 일정 자동 생성, 조회, 완료, 건너뛰기, 반복 일정 다음 회차 생성
- 건강 상태 생성, 조회, 수정, 삭제
- 복약 기록 생성, 조회, 수정, 삭제
- 건강 기록 생성, 조회, 수정, 삭제
- 병원 방문 기록 생성, 조회, 수정, 삭제
- 병원 방문 첨부파일 업로드, 목록 조회, 인증 다운로드, 삭제
- 지출 기록 생성, 조회, 수정, 삭제, 월별 요약
- 건강 기록, 병원 방문, 지출을 합친 통합 타임라인 조회
- 규칙 기반 비용 예측, 재계산, 이력 조회
- 병원 방문 리포트 생성 및 조회

## MVP 알림 정책

서버 푸시나 FCM은 사용하지 않습니다. 앱에서 `care_schedules`를 조회한 뒤 `flutter_local_notifications`로 기기 로컬 알림을 예약합니다.
