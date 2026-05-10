# PawPlan 프로젝트 계획서

반려견 예방관리와 생애비용 계획을 함께 제공하는 모바일 케어 관리 시스템

작성일: 2026년 4월 29일  
프로젝트명: PawPlan  
개발 형태: 캡스톤디자인 / 모바일 앱 + 백엔드 API + 데이터베이스  
주요 기술: Flutter, Express, TypeScript, PostgreSQL, Prisma, Railway

---

## 1. 프로젝트 작품의 개요

### 1.1 작품명

본 프로젝트의 작품명은 **PawPlan**이다. PawPlan은 반려견 보호자가 반려견의 예방관리 일정, 건강 기록, 병원 방문 기록, 지출 내역, 예상 비용을 하나의 모바일 앱에서 통합 관리할 수 있도록 지원하는 반려견 케어 관리 시스템이다.

`PawPlan`이라는 이름은 반려동물을 뜻하는 `Paw`와 계획을 뜻하는 `Plan`을 결합한 것으로, 단순히 기록을 저장하는 앱이 아니라 반려견의 건강관리와 비용 계획을 함께 설계한다는 의미를 담고 있다.

### 1.2 작품의 한 줄 정의

> 반려견의 건강 기록과 지출 데이터를 기반으로 예방 일정, 병원 방문 준비, 예상 비용 관리를 지원하는 예방 중심 반려견 케어 앱

### 1.3 기획 배경

반려견을 양육하는 보호자는 예방접종, 심장사상충 예방, 구충, 건강검진, 미용, 복약, 병원 방문, 사료 구매, 용품 구매 등 반복적인 관리 업무를 수행해야 한다. 그러나 이러한 정보는 캘린더, 메모장, 사진첩, 병원 영수증, 가계부 등에 분산되어 관리되는 경우가 많다.

정보가 분산되면 다음과 같은 문제가 발생한다.

- 예방접종이나 구충 일정을 놓칠 수 있다.
- 체중 변화, 증상 변화, 복약 이력 등 건강 흐름을 장기적으로 보기 어렵다.
- 병원 방문 전 최근 증상과 이전 진료 내용을 빠르게 정리하기 어렵다.
- 병원비, 사료비, 용품비 등 반려견 관련 지출 규모를 체계적으로 파악하기 어렵다.
- 갑작스러운 병원비에 대비하기 위한 예산 계획을 세우기 어렵다.

PawPlan은 이러한 문제를 해결하기 위해 반려견의 건강관리 기록과 비용 관리 기능을 하나의 흐름으로 묶는다. 특히 단순 기록 기능에 그치지 않고, 보호자가 "앞으로 무엇을 해야 하는지", "어느 정도 비용을 예상해야 하는지", "병원 방문 전에 어떤 정보를 준비해야 하는지"를 확인할 수 있도록 설계한다.

### 1.4 프로젝트의 최종 목표

본 프로젝트의 최종 목표는 실제 Android 기기에서 실행 가능한 MVP를 구현하고, 백엔드 서버와 데이터베이스를 클라우드 환경에 배포하여 팀원 및 사용자 테스트가 가능한 형태로 완성하는 것이다.

구체적인 목표는 다음과 같다.

- Flutter 기반 Android 모바일 앱 구현
- Express + TypeScript 기반 REST API 서버 구현
- PostgreSQL 기반 데이터베이스 설계 및 Prisma ORM 연동
- JWT 기반 로그인/인증 기능 구현
- 반려견 등록, 케어 일정, 건강 기록, 병원 방문, 지출 기록 기능 구현
- 건강 기록, 병원 방문, 지출 내역을 통합 타임라인으로 제공
- 지출 데이터를 기반으로 비용 예측 결과 제공
- 병원 방문 전 참고 가능한 요약 리포트 제공
- Railway 기반 백엔드 및 PostgreSQL 배포
- APK 파일을 통한 실기기 테스트 가능 상태 확보

### 1.5 개발 범위

본 프로젝트는 캡스톤디자인의 기간과 구현 가능성을 고려하여 MVP 중심으로 개발한다. MVP에서는 반려견 1마리 또는 다견 등록, 개인 보호자 계정, 로컬 알림, 건강 기록, 병원 기록, 지출 관리, 비용 예측을 핵심 범위로 한다.

가족 공유, 병원 예약 연동, 보험 청구 자동화, AI 진단 기능, 서버 푸시 알림은 향후 확장 기능으로 분류한다. 특히 본 프로젝트는 의료 판단이나 진단을 제공하지 않으며, 보호자가 입력한 정보를 정리하고 관리하는 보조 도구로 한정한다.

---

## 2. 프로젝트 작품의 필요성 및 효과

### 2.1 사회적 필요성

농림축산식품부가 발표한 2025년 반려동물 양육현황 조사에 따르면 반려동물 양육가구 비율은 29.2%로, 반려동물은 이미 많은 가정의 일상적인 가족 구성원으로 자리 잡고 있다. 또한 반려동물 양육가구 중 개를 기르는 비율이 높고, 동물병원 이용 경험도 높은 수준으로 나타난다. 이는 반려견 건강관리와 병원비 관리가 일부 보호자만의 문제가 아니라 반복적이고 보편적인 생활 문제임을 보여준다.

반려동물 양육 인구가 증가하면서 보호자의 책임도 함께 증가하고 있다. 반려견은 스스로 건강 상태를 설명할 수 없기 때문에 보호자가 예방 일정, 증상 변화, 식습관, 체중 변화, 병원 진료 이력 등을 꾸준히 관리해야 한다. 따라서 보호자가 건강 정보를 체계적으로 축적하고 필요한 시점에 활용할 수 있는 도구가 필요하다.

### 2.2 사용자 관점의 필요성

반려견 보호자에게 필요한 것은 단순히 기록을 남기는 기능만이 아니다. 보호자가 실제로 필요로 하는 것은 다음과 같은 의사결정 지원이다.

- 다음 예방접종이나 구충 시점은 언제인가?
- 최근 증상이 언제부터 나타났고 얼마나 자주 반복되었는가?
- 병원 방문 전에 수의사에게 어떤 내용을 설명해야 하는가?
- 이번 달 반려견 관련 지출은 얼마나 발생했는가?
- 앞으로 병원비나 예방관리 비용을 어느 정도 예상해야 하는가?

기존 캘린더나 메모 앱으로도 일부 기록은 가능하지만, 반려견 건강관리 맥락에 맞게 기록을 연결하고 비용 흐름까지 함께 보여주기는 어렵다. PawPlan은 이 지점을 해결하기 위해 예방 일정, 건강 기록, 병원 기록, 지출 기록을 반려견이라는 하나의 중심 엔터티로 연결한다.

### 2.3 기술적 필요성

본 프로젝트는 모바일 앱, 백엔드 API, 데이터베이스, 배포, 테스트를 모두 포함하는 실서비스형 구조를 가진다. 따라서 단순 화면 구현을 넘어 다음과 같은 소프트웨어 개발 역량을 종합적으로 학습할 수 있다.

- Flutter 기반 크로스플랫폼 모바일 앱 개발
- Express 기반 REST API 설계 및 구현
- PostgreSQL 관계형 데이터베이스 설계
- Prisma를 이용한 ORM, migration, schema 관리
- JWT 기반 인증과 비밀번호 해싱
- 파일 업로드와 인증 기반 다운로드
- 로컬 알림을 활용한 사용자 리마인더 기능
- API 스모크 테스트와 모바일 통합 테스트
- Railway를 이용한 클라우드 배포

### 2.4 기대 효과

PawPlan의 기대 효과는 보호자, 반려견 건강관리, 비용 관리, 교육적 측면으로 나누어 볼 수 있다.

| 구분 | 기대 효과 |
| --- | --- |
| 보호자 측면 | 예방 일정 누락 감소, 병원 방문 준비 시간 단축, 반려견 관리 부담 감소 |
| 건강관리 측면 | 건강 기록 축적, 증상 변화 추적, 복약 및 기저질환 정보 정리 |
| 비용관리 측면 | 월별 지출 파악, 예상 비용 확인, 갑작스러운 지출 대비 |
| 데이터 활용 측면 | 건강 기록과 지출 기록을 연결하여 보호자 의사결정 보조 |
| 교육적 측면 | 모바일, 백엔드, DB, 배포, 테스트까지 전 과정을 경험 |

### 2.5 차별성

PawPlan은 단순한 반려동물 메모 앱이나 일정 알림 앱이 아니라, 다음 세 가지를 결합한다는 점에서 차별성을 가진다.

1. **예방 일정 관리**
   - 예방접종, 구충, 검진 등 반복적인 케어 일정을 관리하고 완료/건너뛰기 상태를 기록한다.

2. **건강·병원·지출 통합 기록**
   - 건강 로그, 병원 방문, 지출 기록을 각각 저장하되, 사용자 화면에서는 통합 타임라인으로 제공한다.

3. **비용 예측 및 방문 리포트**
   - 단순 지출 합계를 넘어서 향후 예상 비용을 보여주고, 병원 방문 전 최근 기록을 요약한다.

---

## 3. 프로젝트 작품의 주요내용 및 구성

### 3.1 전체 시스템 구성

PawPlan은 모바일 앱, 백엔드 API 서버, 데이터베이스로 구성된다.

```text
사용자
  ↓
Flutter Android App
  ↓ REST API
Express + TypeScript Backend
  ↓ Prisma ORM
PostgreSQL Database
```

각 구성요소의 역할은 다음과 같다.

| 구성요소 | 역할 |
| --- | --- |
| Flutter 모바일 앱 | 사용자 화면, 입력 폼, 로컬 알림, API 호출 |
| Express 백엔드 | 인증, 비즈니스 로직, REST API 제공 |
| PostgreSQL | 사용자, 반려견, 일정, 기록, 지출, 리포트 데이터 저장 |
| Prisma ORM | DB schema 관리, migration, type-safe DB 접근 |
| Railway | 백엔드 서버와 PostgreSQL 클라우드 배포 |

### 3.2 주요 기능

#### 3.2.1 회원가입 및 로그인

사용자는 이메일, 비밀번호, 이름을 입력하여 계정을 생성하고 로그인할 수 있다. 비밀번호는 bcrypt로 해시하여 저장하며, 로그인 성공 시 JWT access token을 발급한다. 인증이 필요한 API는 `Authorization: Bearer {token}` 헤더를 통해 접근한다.

#### 3.2.2 반려견 등록 및 프로필 관리

사용자는 반려견의 이름, 품종, 생년월일, 성별, 중성화 여부, 현재 체중, 목표 체중, 활동량, 보험 상태 등을 등록할 수 있다. 반려견 프로필은 이후 일정 생성, 건강 기록, 지출 기록, 비용 예측의 기준 데이터가 된다.

#### 3.2.3 케어 일정 관리

반려견 등록 후 기본적인 케어 일정이 생성된다. 사용자는 예방접종, 심장사상충 예방, 구충, 건강검진, 미용, 복약 등 케어 일정을 확인하고 완료하거나 건너뛸 수 있다. 반복 일정은 완료 또는 건너뛰기 후 다음 회차 일정이 이어지도록 설계한다.

#### 3.2.4 로컬 알림

서버 푸시 알림 대신 Flutter 로컬 알림을 사용한다. 앱이 서버에서 pending 상태의 케어 일정을 조회한 뒤, 사용자의 기기에서 예정 알림을 예약한다. 이는 캡스톤 MVP에서 FCM 서버 푸시 구축 부담을 줄이면서도 일정 리마인더 기능을 제공하기 위한 설계이다.

#### 3.2.5 건강 기록 관리

사용자는 반려견의 체중, 증상, 식사, 산책, 메모 등의 건강 로그를 입력할 수 있다. 건강 기록은 날짜, 유형, 제목, 수치, 단위, 메모를 포함한다. 이를 통해 보호자는 반려견의 상태 변화를 장기적으로 확인할 수 있다.

#### 3.2.6 병원 방문 기록 관리

사용자는 병원명, 방문 사유, 증상, 진단 내용, 처치 내용, 처방 내용, 재방문 예정일 등을 기록할 수 있다. 병원 방문 기록은 반려견의 의료 이력 관리에 활용되며, 병원 방문 리포트 생성의 기초 데이터가 된다.

#### 3.2.7 병원 방문 첨부파일 관리

영수증, 처방전, 검사 결과, 이미지 파일을 병원 방문 기록에 첨부할 수 있다. 첨부파일은 인증된 사용자만 조회 및 다운로드할 수 있도록 설계한다. 운영 환경에서는 Railway Volume 또는 외부 스토리지와 연동하여 파일 유실을 방지한다.

#### 3.2.8 지출 기록 관리

사용자는 병원비, 사료비, 간식비, 미용비, 보험료, 용품비 등 반려견 관련 지출을 기록할 수 있다. 병원 방문 생성 시 선택적으로 지출 기록을 함께 생성할 수 있으며, 월별 지출 요약과 비용 예측에 활용된다.

#### 3.2.9 통합 타임라인

건강 기록, 병원 방문 기록, 지출 기록은 DB에서는 각각 분리하여 저장하지만, 사용자 화면에서는 통합 타임라인으로 제공한다. 사용자는 전체, 건강, 병원, 지출 필터를 전환하여 반려견의 최근 상태와 비용 흐름을 한 번에 확인할 수 있다.

#### 3.2.10 비용 예측

반려견의 프로필, 기저질환, 실제 지출 기록을 바탕으로 월 예상 비용, 6개월 예상 비용, 연 예상 비용 등을 계산한다. MVP에서는 규칙 기반 계산 방식을 사용하며, 향후 실제 데이터가 축적되면 품종, 연령, 질환 이력 기반의 고도화가 가능하다.

#### 3.2.11 병원 방문 리포트

최근 건강 기록, 병원 방문 기록, 지출 기록을 바탕으로 보호자가 병원 방문 전에 참고할 수 있는 요약 리포트를 생성한다. 이 리포트는 진단을 제공하는 기능이 아니라, 보호자가 수의사에게 설명할 정보를 정리하는 보조 자료이다.

### 3.3 데이터베이스 구성

주요 테이블은 다음과 같다.

| 테이블 | 설명 |
| --- | --- |
| `users` | 사용자 계정 |
| `dogs` | 반려견 기본 정보 |
| `dog_conditions` | 알레르기, 기저질환 등 건강 상태 |
| `dog_medications` | 복약 정보 |
| `care_schedules` | 예방접종, 구충, 검진 등 케어 일정 |
| `health_logs` | 건강 및 생활 기록 |
| `medical_visits` | 병원 방문 기록 |
| `medical_visit_attachments` | 병원 방문 첨부파일 |
| `expenses` | 반려견 관련 지출 기록 |
| `cost_forecasts` | 비용 예측 결과 |
| `visit_reports` | 병원 방문 요약 리포트 |

### 3.4 기술 스택

| 영역 | 기술 |
| --- | --- |
| 모바일 | Flutter, Dart |
| 백엔드 | Node.js, Express, TypeScript |
| 데이터베이스 | PostgreSQL |
| ORM | Prisma |
| 인증 | JWT, bcrypt |
| 파일 업로드 | multer |
| 알림 | flutter_local_notifications |
| 로컬 개발 DB | Docker Compose |
| 배포 | Railway |
| 형상관리 | GitHub |
| 테스트 | API E2E smoke test, Flutter widget/integration test |

### 3.5 비기능 요구사항

| 항목 | 요구사항 |
| --- | --- |
| 보안 | 비밀번호 해시 저장, JWT 인증, 민감 정보 응답 제외 |
| 개인정보 | 반려견 건강 기록, 병원 기록, 영수증 이미지를 민감 정보로 취급 |
| 안정성 | API 오류 응답 형식 통일, DB migration 관리 |
| 유지보수성 | API 명세와 DB schema를 문서화하고 Prisma migration으로 관리 |
| 확장성 | 가족 공유, 서버 푸시, 외부 스토리지, 보험 연동이 가능하도록 구조 설계 |
| 사용성 | 모바일 화면에서 핵심 정보를 빠르게 확인할 수 있도록 탭 기반 UI 구성 |

---

## 4. 활용방안

### 4.1 개인 보호자의 반려견 관리 도구

PawPlan은 반려견 보호자가 일상적으로 사용하는 관리 도구로 활용될 수 있다. 보호자는 앱을 통해 오늘 해야 할 케어 일정, 최근 건강 기록, 지출 내역, 병원 방문 이력을 확인할 수 있다. 특히 초보 보호자는 예방접종, 구충, 건강검진 등 기본 관리 항목을 놓치지 않는 데 도움을 받을 수 있다.

### 4.2 병원 방문 전 준비 자료

반려견이 병원에 방문할 때 보호자는 증상이 언제 시작되었는지, 얼마나 자주 반복되었는지, 이전에 어떤 처방을 받았는지 기억하기 어려운 경우가 많다. PawPlan의 병원 방문 리포트는 최근 건강 로그와 병원 기록을 정리하여 보호자가 수의사에게 더 정확하게 설명할 수 있도록 돕는다.

### 4.3 지출 및 예산 관리

반려견 양육비는 사료비, 병원비, 미용비, 용품비 등으로 꾸준히 발생한다. PawPlan은 실제 지출 데이터를 카테고리별로 저장하고, 예상 비용을 제공함으로써 보호자가 월별 예산을 세우고 갑작스러운 비용에 대비할 수 있도록 돕는다.

### 4.4 노령견 및 만성질환견 관리

노령견이나 만성질환견은 병원 방문, 복약, 검사, 식이 조절이 반복적으로 필요하다. PawPlan은 복약 정보, 건강 상태, 병원 방문 기록, 비용 기록을 함께 관리할 수 있어 장기 관리가 필요한 반려견 보호자에게 유용하다.

### 4.5 교육 및 포트폴리오 활용

본 프로젝트는 캡스톤디자인 결과물로서 모바일 앱, 백엔드, 데이터베이스, 배포, 테스트를 모두 포함한다. 따라서 팀원들은 실무형 서비스 개발 경험을 포트폴리오로 제시할 수 있다. 특히 Railway 배포와 APK 실행까지 포함하므로 단순 과제 코드가 아니라 실제 사용 가능한 MVP로 설명할 수 있다.

### 4.6 향후 확장 방안

향후 확장 가능한 기능은 다음과 같다.

- 가족 구성원 공동 관리 기능
- 다견 가구를 위한 반려견별 비교 대시보드
- Cloudflare R2 또는 S3 기반 첨부파일 저장
- FCM 기반 서버 푸시 알림
- 병원 방문 기록 PDF 내보내기
- 병원 진료비 표준 항목 기반 비용 비교
- 보험 가입 여부에 따른 예상 비용 시뮬레이션
- AI 기반 증상 분류 보조 기능

---

## 5. 참고문헌

본 프로젝트의 참고문헌은 단순 개발 문서에 한정하지 않고, 반려동물 양육 규모, 동물병원 이용, 접근 가능한 수의진료, 예방관리, 보호자 순응도, 모바일 알림 효과, 시스템 개발 기술 문서로 구분하여 정리하였다.

### 5.1 국내 반려동물 양육 현황 및 시장 자료

1. 농림축산식품부. (2026). 「2025년 반려동물 양육현황 조사」 보도자료.  
   https://www.mafra.go.kr/bbs/home/792/594753/download.do  
   - 본 프로젝트의 시장 필요성 근거로 활용하였다. 해당 자료는 반려동물 양육가구 비율, 반려견 양육 비중, 월평균 양육비, 동물병원 이용 경험 등을 제시한다.

2. 농림축산식품부. (2026). 「2025년 동물복지에 대한 국민의식조사」 및 「2025년 반려동물 양육현황 조사」 결과 발표.  
   https://www.mafra.go.kr/home/5109/subview.do?enc=Zm5jdDF8QEB8JTJGYmJzJTJGaG9tZSUyRjc5MiUyRjU3Njk2MSUyRmFydGNsVmlldy5kbyUzRg%3D%3D  
   - 반려동물 양육이 보편화되고 있으며, 동물병원 이용률이 높다는 점을 근거로 PawPlan의 건강관리·병원기록 관리 필요성을 설명하는 데 활용하였다.

3. KB금융지주 경영연구소. (2025). 「2025 한국 반려동물 보고서」.  
   https://kbthink.com/investment/deepdive/research/250629-1.html  
   - 반려동물 생애 지출, 치료비 부담, 펫보험 인식 등 비용관리 측면의 근거 자료로 활용하였다.

4. KB금융지주 경영연구소. (2025). 「2025 한국 반려동물 보고서」 PDF.  
   https://kbthink.com/content/dam/kb-financial-group/holdings/IBR/05/2025/06/202506290838130/2025%ED%95%9C%EA%B5%AD%EB%B0%98%EB%A0%A4%EB%8F%99%EB%AC%BC%EB%B3%B4%EA%B3%A0%EC%84%9C.pdf  
   - 반려동물 양육비와 의료비 부담을 정량적으로 제시하는 자료로, PawPlan의 지출 기록 및 비용 예측 기능 필요성을 뒷받침한다.

### 5.2 수의진료 접근성, 보호자 부담, 예방관리 관련 연구

5. Applebaum, J. W., Tomlinson, C. A., Matijczak, A., McDonald, S. E., & Zsembik, B. A. (2020). The concerns, difficulties, and stressors of caring for pets during COVID-19: Results from a large survey of U.S. pet owners. *Animals, 10*(10), 1882.  
   https://doi.org/10.3390/ani10101882  
   - 보호자가 반려동물 돌봄에서 경험하는 경제적·심리적 부담을 이해하는 배경 자료로 활용할 수 있다.

6. LaVallee, E., Mueller, M. K., & McCobb, E. (2017). A systematic review of the literature addressing veterinary care for underserved communities. *Journal of Applied Animal Welfare Science, 20*(4), 381-394.  
   https://doi.org/10.1080/10888705.2017.1337515  
   - 수의진료 접근성 문제가 반려동물 복지와 보호자 의사결정에 영향을 준다는 점을 설명하는 근거로 활용하였다.

7. Access to Veterinary Care Coalition. (2018). *Access to Veterinary Care: Barriers, Current Practices, and Public Policy*.  
   https://pphe.utk.edu/access-to-veterinary-care-coalition-avcc/  
   - 진료비, 이동성, 정보 부족 등이 수의진료 접근성의 장벽이 될 수 있음을 설명하는 정책·연구 보고서이다. PawPlan의 비용 예측과 기록 정리 기능의 필요성 근거로 활용 가능하다.

8. Kogan, L. R., Erdman, P., Bussolari, C., Currin-McCulloch, J., & Packman, W. (2021). Community veterinary medicine programs: Pet owners' perceptions and experiences. *Frontiers in Veterinary Science, 8*, 678595.  
   https://doi.org/10.3389/fvets.2021.678595  
   - 비용과 접근성이 보호자의 진료 이용 경험에 영향을 준다는 점을 보여주는 연구로, 저비용·예방 중심 관리 도구의 필요성을 설명하는 데 활용할 수 있다.

9. Jacobson, L., & Englar, R. (2024). Breaking down the barriers to accessible veterinary care. *Journal of Feline Medicine and Surgery, 26*(11).  
   https://doi.org/10.1177/1098612X241283532  
   - 접근 가능한 수의진료의 개념과 장벽을 정리한 문헌으로, PawPlan이 직접 진료를 제공하지 않더라도 보호자의 준비와 기록 정리를 보조해야 하는 이유를 설명하는 근거로 활용한다.

10. Dolan, E. D., Scotto, J., Slater, M., & Weiss, E. (2015). Risk factors for dog relinquishment to a Los Angeles municipal animal shelter. *Animals, 5*(4), 1311-1328.  
    https://doi.org/10.3390/ani5040413  
    - 반려동물 양육 지속성과 보호자 부담의 관계를 이해하는 배경자료로 활용 가능하다.

11. AAHA/AVMA Preventive Healthcare Task Force. (2011). *AAHA-AVMA Canine Preventive Healthcare Guidelines*.  
    https://www.aaha.org/wp-content/uploads/2019/05/caninepreventiveguidelines_ppph.pdf  
    - 예방접종, 기생충 예방, 건강 평가, 보호자 교육 등 예방관리의 중요성을 제시하는 지침으로, PawPlan의 케어 일정 기능 설계 근거로 활용하였다.

12. Creevy, K. E., Grady, J., Little, S. E., Moore, G. E., Strickler, B. G., Thompson, S., & Webb, J. A. (2019). 2019 AAHA Canine Life Stage Guidelines. *Journal of the American Animal Hospital Association, 55*(6), 267-290.  
    https://doi.org/10.5326/JAAHA-MS-6999  
    - 반려견의 생애주기별 예방관리와 건강관리 항목을 제시하는 지침이다. PawPlan의 생애주기 기반 케어 플랜 확장 방향과 관련된다.

### 5.3 반려견 건강기록, 비만, 보호자 순응도 관련 연구

13. Chandler, M., Cunningham, S., Lund, E. M., Khanna, C., Naramore, R., Patel, A., & Day, M. J. (2017). Obesity and associated comorbidities in people and companion animals: A One Health perspective. *Journal of Comparative Pathology, 156*(4), 296-309.  
    https://doi.org/10.1016/j.jcpa.2017.03.006  
    - 반려동물 비만과 보호자 생활습관의 연관성을 다루며, 체중·식이·운동 기록 기능의 필요성을 뒷받침한다.

14. Ward, E., German, A. J., & Churchill, J. A. (2018). The global pet obesity initiative position statement. *Journal of Small Animal Practice, 59*(9), 568-569.  
    https://doi.org/10.1111/jsap.12919  
    - 반려동물 비만을 예방관리 관점에서 접근해야 한다는 자료로, PawPlan의 체중 및 건강 로그 기능과 연결된다.

15. Muñoz-Prieto, A., Nielsen, L. R., Dąbrowski, R., Bjørnvad, C. R., Söder, J., Lamy, E., Monkeviciene, I., Ljubić, B. B., Vasiu, I., Savic, S., Busato, F., Yilmaz, Z., Bravo-Cantero, A. F., Öhlund, M., Lucena, S., Zelvyte, R., Aladrović, J., Lopez-Jornet, P., Caldin, M., Lavrador, C., ... Tvarijonaviciute, A. (2018). European dog owner perceptions of obesity and factors associated with human and canine obesity. *Scientific Reports, 8*, 13353.  
    https://doi.org/10.1038/s41598-018-31532-0  
    - 보호자의 인식과 반려견 비만 관리의 관계를 다룬 연구로, 보호자에게 기록 기반 피드백을 제공하는 기능의 필요성을 설명하는 데 활용 가능하다.

16. German, A. J. (2006). The growing problem of obesity in dogs and cats. *The Journal of Nutrition, 136*(7 Suppl), 1940S-1946S.  
    https://doi.org/10.1093/jn/136.7.1940S  
    - 반려견·반려묘 비만 문제의 임상적 중요성을 다룬 고전적 문헌으로, 건강 로그와 체중 관리 기능의 배경 자료로 활용한다.

17. Di Cerbo, A., Morales-Medina, J. C., Palmieri, B., Pezzuto, F., Cocco, R., Flores, G., & Iannitti, T. (2015). Preliminary study of pet owner adherence in behaviour, cardiology, urology, and oncology fields. *Veterinary Medicine International, 2015*, 618216.  
    https://pmc.ncbi.nlm.nih.gov/articles/PMC4491582/  
    - 수의학 치료에서는 보호자가 권장 치료 계획을 얼마나 정확히 수행하는지가 중요하다는 점을 보여주는 연구이다. PawPlan의 복약 정보 관리, 병원 방문 기록, 일정 알림 기능의 필요성과 연결된다.

18. Jukes, A., Ramsey, I., & Kogan, L. R. (2025). Medication compliance by cat owners prescribed treatment for home administration. *Journal of Veterinary Internal Medicine, 39*(1), e17298.  
    https://doi.org/10.1111/jvim.17298  
    - 보호자가 가정에서 약물을 투여할 때 일정, 투여 간격, 복약 완료 여부가 실제 순응도에 영향을 줄 수 있음을 보여준다. PawPlan의 복약 기록 및 향후 복약 알림 확장 근거로 활용한다.

### 5.4 모바일 알림, 기록 관리, 디지털 헬스 관련 연구

19. Thakkar, J., Kurup, R., Laba, T. L., Santo, K., Thiagalingam, A., Rodgers, A., Woodward, M., Redfern, J., & Chow, C. K. (2016). Mobile telephone text messaging for medication adherence in chronic disease: A meta-analysis. *JAMA Internal Medicine, 176*(3), 340-349.  
    https://doi.org/10.1001/jamainternmed.2015.7667  
    - 모바일 메시지와 리마인더가 복약 및 건강행동 순응도에 미치는 효과를 다룬 연구로, PawPlan의 로컬 알림 기능 설계 근거로 활용 가능하다.

20. Fauk, N. K., et al. (2021). Effectiveness of mobile phone text message reminder interventions to improve adherence to antiretroviral therapy among adolescents living with HIV: A systematic review and meta-analysis. *PLOS ONE, 16*(7), e0254890.  
    https://doi.org/10.1371/journal.pone.0254890  
    - 모바일 알림의 효과가 맥락에 따라 달라질 수 있음을 보여주는 자료로, PawPlan에서도 단순 알림뿐 아니라 일정 상태 기록과 사용자 확인 흐름이 필요하다는 점을 설명할 수 있다.

21. Ibeneme, S. C., et al. (2021). Effectiveness of mobile text reminder in improving adherence to medication, physical exercise, and quality of life in patients living with HIV: A systematic review. *BMC Infectious Diseases, 21*, 859.  
    https://doi.org/10.1186/s12879-021-06563-0  
    - 모바일 리마인더가 약물 복용과 건강행동 실천에 활용될 수 있음을 보여주는 체계적 문헌고찰이다.

22. Bhuyan, S. S., Lu, N., Chandak, A., Kim, H., Wyant, D., Bhatt, J., Kedia, S., & Chang, C. F. (2016). Use of mobile health applications for health-seeking behavior among US adults. *Journal of Medical Systems, 40*, 153.  
    https://doi.org/10.1007/s10916-016-0492-7  
    - 모바일 앱이 사용자의 건강정보 탐색과 자기관리 행동에 활용될 수 있음을 보여주는 연구이다. PawPlan의 모바일 기반 기록·알림·요약 기능과 관련된다.

23. Zapata, B. C., Fernández-Alemán, J. L., Idri, A., & Toval, A. (2015). Empirical studies on usability of mHealth apps: A systematic literature review. *Journal of Medical Systems, 39*, 1.  
    https://doi.org/10.1007/s10916-014-0182-2  
    - 모바일 헬스 앱에서 사용성이 중요하다는 점을 다룬 연구로, PawPlan의 탭 기반 UI와 간단한 기록 입력 흐름 설계의 근거로 활용할 수 있다.

### 5.5 개발 기술 및 배포 관련 공식 문서

24. Flutter. (2026). *Flutter documentation*.  
    https://docs.flutter.dev/  
    - Flutter 앱 구조, 위젯, Android 빌드, 테스트 문서 참고.

25. Express. (2026). *Express - Node.js web application framework*.  
    https://expressjs.com/  
    - REST API 서버 구현과 middleware 구조 참고.

26. PostgreSQL Global Development Group. (2026). *PostgreSQL Documentation*.  
    https://www.postgresql.org/docs/  
    - 관계형 데이터베이스 설계, 자료형, 인덱스, 제약조건 참고.

27. Prisma. (2026). *PostgreSQL database connector*.  
    https://www.prisma.io/docs/v6/orm/overview/databases/postgresql  
    - Prisma schema, PostgreSQL 연결, ORM client 구성 참고.

28. flutter_local_notifications. (2026). *Package documentation*.  
    https://pub.dev/packages/flutter_local_notifications  
    - Android 로컬 알림 구현 방식 참고.

29. Railway. (2026). *Railway Docs - Config as Code and Pricing*.  
    https://docs.railway.com/  
    - 백엔드 배포, PostgreSQL 서비스, 환경변수, 배포 설정, 요금 정책 참고.

30. GitHub. (2026). *GitHub pricing and repository features*.  
    https://github.com/pricing  
    - 저장소 관리, 협업, public/private repository 정책 참고.

### 5.6 프로젝트 내부 산출물

31. PawPlan API 명세서, `pawplan-api-spec.md`
32. PawPlan DB 설계서, `pawplan-db-design.md`
33. PawPlan 백엔드 README, `backend/README.md`
34. PawPlan 모바일 README, `mobile/README.md`

---

## 6. 개발 추진전략 및 추진체계

### 6.1 개발 추진전략

본 프로젝트는 MVP 우선 개발 전략을 따른다. 모든 기능을 한 번에 완성하기보다, 사용자 핵심 흐름을 먼저 구현하고 이후 기능을 확장하는 방식으로 추진한다.

핵심 사용자 흐름은 다음과 같다.

```text
회원가입/로그인
  → 반려견 등록
  → 기본 케어 일정 확인
  → 건강 기록/병원 기록/지출 기록 입력
  → 통합 타임라인 확인
  → 비용 예측 및 방문 리포트 확인
```

### 6.2 단계별 추진전략

| 단계 | 추진전략 |
| --- | --- |
| 요구사항 정의 | 사용자 문제를 예방관리, 기록관리, 비용관리로 구분 |
| 설계 | DB schema와 API 명세를 먼저 작성하여 개발 기준 통일 |
| 구현 | Flutter 앱과 Express API를 기능 단위로 병렬 개발 |
| 검증 | API smoke test와 Flutter 테스트로 주요 흐름 검증 |
| 배포 | Railway에 백엔드와 PostgreSQL을 배포하고 APK를 배포 URL로 빌드 |
| 발표 | 실제 에뮬레이터 또는 갤럭시 폰에서 시연 가능한 상태로 준비 |

### 6.3 개발 추진체계

역할은 기능 영역에 따라 분담한다. 단, 캡스톤 프로젝트 특성상 각 담당자는 자신의 영역만 수행하는 것이 아니라 API 명세, DB 구조, 테스트 결과를 함께 공유하며 통합 품질을 관리한다.

```text
프로젝트 총괄
  ├─ 모바일 앱 개발
  ├─ 백엔드 API 개발
  ├─ DB/API 설계
  ├─ 테스트 및 품질관리
  └─ 문서화 및 발표 준비
```

### 6.4 협업 방식

- GitHub 저장소를 사용하여 소스코드를 관리한다.
- 기능 단위로 작업 후 main 브랜치에 병합한다.
- DB 변경은 Prisma migration으로 관리한다.
- API 변경 시 API 명세서를 함께 수정한다.
- 주요 기능 구현 후 `npm run smoke:e2e`, `flutter analyze`, `flutter test`를 실행한다.
- 배포 전 Railway 환경변수와 DB migration 상태를 확인한다.

### 6.5 위험요소 및 대응방안

| 위험요소 | 영향 | 대응방안 |
| --- | --- | --- |
| 기능 범위 과다 | 일정 지연 | MVP 필수 기능과 확장 기능을 구분 |
| API와 앱 데이터 불일치 | 연동 오류 | API 명세와 DB schema를 기준으로 개발 |
| 배포 환경 DB 연결 오류 | 실기기 테스트 불가 | Railway 환경변수, migration, health check 확인 |
| 첨부파일 유실 | 병원 기록 신뢰도 저하 | Railway Volume 또는 외부 스토리지 적용 |
| 알림 권한 문제 | 일정 알림 미동작 | 로컬 알림 권한 안내 및 에뮬레이터/실기기 테스트 |
| 의료정보 오해 | 법적·윤리적 문제 | 진단 기능이 아닌 기록 정리 보조 기능으로 명확히 제한 |

---

## 7. 추진계획 및 일정

### 7.1 전체 일정

| 주차 | 추진 내용 | 산출물 |
| --- | --- | --- |
| 1주차 | 주제 선정, 문제 정의, 사용자 대상 설정 | 주제 제안서, 문제 정의 |
| 2주차 | 시장 및 경쟁 서비스 조사 | 경쟁 분석 자료 |
| 3주차 | MVP 범위 확정, 핵심 기능 정의 | 요구사항 목록 |
| 4주차 | 화면 흐름 및 와이어프레임 작성 | 와이어프레임 문서 |
| 5주차 | DB schema 초안 작성 | DB 설계서 |
| 6주차 | API 명세 작성, 백엔드 구조 설계 | API 명세서 |
| 7주차 | Flutter 앱 프로젝트 구성, 로그인 화면 구현 | 앱 기본 골격 |
| 8주차 | Express 서버, Prisma, PostgreSQL 연동 | 백엔드 기본 API |
| 9주차 | 반려견 등록, 케어 일정, 로컬 알림 구현 | 온보딩/일정 기능 |
| 10주차 | 건강 기록, 지출 기록, 병원 방문 기록 구현 | 기록 관리 기능 |
| 11주차 | 첨부파일, 통합 타임라인 구현 | 병원 첨부/타임라인 |
| 12주차 | 비용 예측, 병원 방문 리포트 구현 | 예측/리포트 기능 |
| 13주차 | Railway 배포, APK 빌드, 실기기 테스트 | 배포 URL, APK |
| 14주차 | UI 개선, 오류 수정, 테스트 보강 | 안정화 버전 |
| 15주차 | 최종 보고서, 발표자료, 시연 영상 제작 | 최종 산출물 |

### 7.2 세부 개발 일정

#### 7.2.1 설계 단계

설계 단계에서는 기획 문서, DB 설계, API 명세, 화면 와이어프레임을 작성한다. 이 단계의 핵심은 구현 전에 프론트엔드와 백엔드가 사용할 데이터 구조와 API 규칙을 통일하는 것이다.

주요 산출물:

- 프로젝트 기획서
- DB 테이블 설계서
- API 명세서
- 화면 와이어프레임
- MVP 기능 범위표

#### 7.2.2 구현 단계

구현 단계에서는 기능 단위로 앱과 백엔드를 연결한다. 인증, 반려견 등록, 일정 관리, 기록 관리, 지출 관리, 타임라인, 리포트 순서로 구현한다.

주요 산출물:

- Flutter Android 앱
- Express REST API
- Prisma migration
- PostgreSQL 테이블
- 데모 seed 데이터

#### 7.2.3 검증 및 배포 단계

검증 단계에서는 API 스모크 테스트와 Flutter 테스트를 수행한다. 배포 단계에서는 Railway에 백엔드와 PostgreSQL을 배포하고, 배포 URL을 기준으로 APK를 다시 빌드한다.

주요 산출물:

- Railway 배포 환경
- Android APK
- 테스트 결과
- 최종 발표 자료

---

## 8. 참여학생 연구분담표

아래 표는 4인 팀 기준 예시이며, 실제 팀 구성에 맞게 이름과 담당 범위를 조정한다.

| 번호 | 성명 | 역할 | 주요 담당 업무 | 세부 산출물 |
| --- | --- | --- | --- | --- |
| 1 | 학생 A | 프로젝트 총괄/기획 | 문제 정의, 요구사항 정리, 일정 관리, 발표자료 작성 | 기획서, 발표자료, 최종 보고서 |
| 2 | 학생 B | 모바일 앱 개발 | Flutter 화면 구현, 상태 관리, 로컬 알림, APK 빌드 | Android 앱, UI 테스트, APK |
| 3 | 학생 C | 백엔드 개발 | Express API, JWT 인증, 파일 업로드, Railway 배포 | REST API, 배포 서버, API 테스트 |
| 4 | 학생 D | DB/API 설계 및 테스트 | PostgreSQL schema, Prisma migration, API 명세, E2E 검증 | DB 설계서, API 명세서, 테스트 결과 |

### 8.1 역할별 세부 책임

#### 프로젝트 총괄/기획 담당

- 사용자 문제 정의
- 프로젝트 범위 조정
- 주차별 일정 관리
- 회의록 및 산출물 관리
- 최종 발표자료 작성
- 시연 흐름 구성

#### 모바일 앱 개발 담당

- Flutter 프로젝트 구조 관리
- 로그인/회원가입 화면 구현
- 반려견 온보딩 화면 구현
- 대시보드, 기록 탭, 정보 탭, 리포트 탭 구현
- 로컬 알림 연동
- APK 빌드 및 실기기 테스트

#### 백엔드 개발 담당

- Express 서버 구조 구성
- JWT 인증 구현
- 반려견, 일정, 기록, 지출 API 구현
- 병원 첨부파일 업로드/다운로드 구현
- 비용 예측 및 방문 리포트 API 구현
- Railway 배포 설정

#### DB/API 설계 및 테스트 담당

- PostgreSQL 테이블 설계
- Prisma schema 및 migration 작성
- API 명세 관리
- 데모 seed 데이터 작성
- API E2E smoke test 작성
- Flutter 통합 테스트 지원

### 8.2 협업 산출물 관리

| 산출물 | 담당 | 관리 방식 |
| --- | --- | --- |
| 소스코드 | 전체 | GitHub 저장소 |
| DB schema | DB/API 담당 | Prisma migration |
| API 명세 | 백엔드 + DB/API 담당 | Markdown 문서 |
| 앱 화면 | 모바일 담당 | Flutter 코드 및 APK |
| 테스트 결과 | 전체 | 명령 실행 결과 및 보고서 |
| 발표자료 | 총괄 담당 | PPT 또는 PDF |

---

## 9. 필요 부품별 조달 계획

본 프로젝트는 별도 하드웨어 제작이 필요한 IoT 작품이 아니라 모바일 앱과 서버 기반 소프트웨어 작품이다. 따라서 대부분의 개발 도구는 무료 또는 보유 장비를 활용한다. 비용은 2026년 4월 기준 캡스톤 시연용 예상치이며, 실제 비용은 환율과 서비스 요금 정책에 따라 달라질 수 있다.

### 9.1 개발 장비 및 소프트웨어

| 항목 | 용도 | 조달 방법 | 예상 가격 | 비고 |
| --- | --- | --- | --- | --- |
| 개발용 노트북/PC | Flutter, 백엔드, DB 개발 | 팀원 보유 장비 활용 | 0원 | Windows 환경 기준 |
| Android 스마트폰 | 실기기 테스트 | 팀원 보유 기기 활용 | 0원 | 갤럭시 등 Android 기기 |
| Android Emulator | 앱 실행 테스트 | Android Studio/SDK 사용 | 0원 | `PawPlan_API36` AVD |
| Flutter SDK | 모바일 앱 개발 | 공식 사이트 다운로드 | 0원 | 오픈소스 |
| Node.js | 백엔드 실행 환경 | 공식 사이트 다운로드 | 0원 | 오픈소스 |
| PostgreSQL | 로컬 DB | Docker 이미지 사용 | 0원 | 로컬 개발용 |
| Docker Desktop | 로컬 DB 실행 | 공식 사이트 다운로드 | 0원 | 개인/교육 목적 기준 확인 필요 |
| VS Code/IDE | 코드 작성 | 무료 IDE 사용 | 0원 | 선택 사항 |

### 9.2 클라우드 및 배포 비용

| 항목 | 용도 | 조달 방법 | 예상 가격 | 비고 |
| --- | --- | --- | --- | --- |
| GitHub 저장소 | 소스코드 관리 | GitHub 계정 생성 | 0원 | public/private repository 활용 |
| Railway Hobby | 백엔드 서버 및 DB 배포 | Railway 프로젝트 생성 | 월 $5 수준부터 | 공식 요금 정책 확인 필요 |
| Railway PostgreSQL | 운영 DB | Railway DB 서비스 생성 | 사용량 기반 | 소규모 테스트 기준 저비용 |
| Railway Volume | 첨부파일 보관 | `/data` 볼륨 마운트 | 사용량 기반 | 영수증/처방전 이미지 보관 |
| 도메인 | 선택 사항 | 가비아, Cloudflare 등 | 연 1~2만 원 내외 | 캡스톤 시연에는 필수 아님 |
| Google Play Console | 선택 사항, 스토어 배포 시 | 개발자 계정 등록 | 1회 $25 | APK 직접 공유 시 불필요 |

### 9.3 운영 환경 조달 계획

캡스톤 시연 단계에서는 다음 구성을 우선 사용한다.

```text
GitHub
  ↓
Railway Backend Service
  ↓
Railway PostgreSQL
```

첨부파일 기능까지 안정적으로 시연하려면 Railway Volume을 추가한다.

```text
UPLOAD_ROOT=/data/uploads
```

실제 사용자 테스트를 위해 팀원 갤럭시 폰에서 실행하려면 Railway 배포 URL을 기준으로 APK를 다시 빌드한다.

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://<railway-domain>/api/v1
```

### 9.4 총 예상 비용

| 구분 | 최소 비용 | 권장 비용 |
| --- | --- | --- |
| 로컬 개발 및 에뮬레이터 테스트 | 0원 | 0원 |
| 팀원 실기기 APK 테스트 | 0원 | 0원 |
| Railway 배포 테스트 | 월 $5 수준부터 | 월 $5~$10 내외 예상 |
| 도메인 연결 | 0원 | 연 1~2만 원 |
| Google Play 배포 | 0원 | 1회 $25 |

캡스톤 제출 및 시연만을 목표로 할 경우, 필수 비용은 Railway 사용료 정도로 제한할 수 있다. 학교 내부 시연에서 로컬 서버와 에뮬레이터만 사용할 경우 추가 비용 없이도 진행 가능하다.

---

## 부록 A. 현재 구현된 MVP 범위

현재 PawPlan MVP는 다음 기능을 구현 대상으로 한다.

- 이메일 회원가입 및 로그인
- JWT 기반 인증
- 반려견 등록 및 프로필 수정
- 기본 케어 일정 생성, 조회, 완료, 건너뛰기
- 반복 일정 다음 회차 생성
- Flutter 로컬 알림
- 건강 상태 및 복약 정보 관리
- 건강 로그 관리
- 병원 방문 기록 관리
- 병원 방문 첨부파일 업로드/다운로드/삭제
- 지출 기록 관리
- 건강/병원/지출 통합 타임라인
- 비용 예측
- 병원 방문 리포트
- Railway 배포 준비
- Android APK 빌드

## 부록 B. 제외 및 향후 개발 범위

MVP에서 제외하고 향후 개발로 분류한 항목은 다음과 같다.

- 수의학적 진단 또는 처방 추천
- 병원 예약 API 연동
- 보험사 청구 API 연동
- 가족 공유 및 권한 관리
- FCM 기반 서버 푸시 알림
- 앱스토어/플레이스토어 정식 배포
- AI 기반 증상 판별
- 병원비 표준 항목 기반 비교 분석

## 부록 C. 성공 기준

프로젝트 완료 기준은 다음과 같다.

- Android 에뮬레이터 또는 실기기에서 APK 실행 가능
- 회원가입/로그인 후 반려견 등록 가능
- 케어 일정, 건강 기록, 병원 방문, 지출 기록 생성 가능
- 통합 타임라인에서 기록 확인 가능
- 비용 예측 및 방문 리포트 확인 가능
- 백엔드 API가 Railway에서 실행 가능
- PostgreSQL migration이 정상 적용 가능
- API 스모크 테스트 통과
- Flutter 정적 분석 및 테스트 통과
