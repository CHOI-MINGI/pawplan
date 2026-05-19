# PawPlan 비용 계산 엔진 문서

작성일: 2026-05-17
기준 버전: `breed_profile_v3`

## 1. 목적

PawPlan 비용 계산 엔진은 반려견의 월 예상 비용을 `설명 가능한 형태`로 추정하기 위한 로직이다.

이 엔진의 목표는 단순히 하나의 숫자를 보여주는 것이 아니다.

- 사용자가 왜 이 금액이 나왔는지 이해할 수 있어야 한다.
- 견종 기본값만 쓰지 않고, 실제 사용자의 과거 지출 경험을 점점 더 반영해야 한다.
- 기록이 쌓일수록 `모델값`보다 `그 아이의 실제 패턴`에 가까워져야 한다.
- 결과는 월 예상 비용뿐 아니라 구성비, 신뢰도, 근거 문구까지 함께 내려가야 한다.

## 2. 관련 파일

- 엔진 본체: [backend/src/domain/costForecast.ts](</H:/programming/jonsulpu/backend/src/domain/costForecast.ts>)
- 견종 프로필: [backend/src/domain/costBreedProfiles.ts](</H:/programming/jonsulpu/backend/src/domain/costBreedProfiles.ts>)
- API 응답 변환: [backend/src/routes/appRoutes.ts](</H:/programming/jonsulpu/backend/src/routes/appRoutes.ts>)
- 앱 표시 화면: [mobile/lib/main.dart](</H:/programming/jonsulpu/mobile/lib/main.dart>)

## 3. 핵심 개념

엔진은 최종 월 예상 비용을 아래 3개 축으로 나눈다.

- `fixedCost`: 반복 고정비
- `plannedCareCost`: 반복 예방관리비
- `riskAdjustedCost`: 돌발진료 예비비

최종 월 예상 비용은 아래 구조로 계산된다.

```text
monthlyEstimate = fixedCost + plannedCareCost + riskAdjustedCost
```

이때 각 항목은 단순 합산이 아니라, 아래 3단계를 거친다.

1. 견종/연령/체중 기준의 기본 모델값 계산
2. 최근 실제 지출 패턴으로 사용자 개인화 보정
3. 과거 예측 대비 실제 지출 오차로 추가 보정

## 4. 입력 데이터

엔진은 아래 데이터를 사용한다.

### 4.1 반려견 프로필

- 견종
- 생년월일
- 현재 체중
- 목표 체중
- 보험 가입 여부

### 4.2 건강 상태

- 활성 질환 수
- 활성 복약 수
- 만성질환 여부
- 최근 병원 방문 수

### 4.3 지출 이력

- 최근 90일 지출
- 최근 365일 지출
- 지출 카테고리
- 지출 월별 분포

### 4.4 과거 예측 기록

- 이전 `basic` 시나리오 예측
- 예측 이후 30~60일 실제 지출

## 5. 지출 카테고리 해석

현재 엔진은 지출을 단순 고정비/의료비가 아니라 아래 5개 그룹으로 먼저 분류한다.

### 5.1 고정비 그룹

아래 카테고리는 `fixedCost` 계산에 사용한다.

- `food`
- `snack`
- `grooming`
- `supplies`

보험료는 고정비 성격이지만 별도 `insurance` 그룹으로 분리한다. 실제 보험 지출이 있으면 연간 합계를 12개월로 나눠 월 보험료를 추정하고, 기록이 없지만 가입 상태이면 기본 월 보험료를 사용한다.

### 5.2 반복 의료비 그룹

아래 카테고리는 반복 관리비 성격으로 보고 `plannedCareCost` 보정에 사용한다.

- `medication`
- `checkup`
- `vaccine`
- `prevention`
- `dental_care`

### 5.3 돌발 의료비 그룹

아래 카테고리는 일회성 또는 변동성 높은 진료비로 보고 `riskAdjustedCost` 보정에 사용한다.

- `hospital`
- `emergency`
- `surgery`
- `dental_treatment`
- `skin_treatment`
- `eye_treatment`
- `joint_treatment`
- `digestive_treatment`

### 5.4 기타와 미등록 카테고리

`other`는 별도 기타 그룹으로 보관한다. 엔진에 등록되지 않은 새 카테고리는 보수적으로 돌발 의료비로 취급한다. 이렇게 해야 예전 데이터나 서버 외부에서 들어온 병원성 지출이 빠지지 않는다.

### 5.5 이상치 처리

각 카테고리의 중앙값과 최소 기준선을 함께 보고 고액 지출을 이상치로 분리한다. 이상치는 반복 월지출 평균에는 넣지 않고, 연간화한 예비비 메타데이터로만 완만하게 반영한다.

## 6. 견종 프로필 구조

견종 기본값은 [costBreedProfiles.ts](</H:/programming/jonsulpu/backend/src/domain/costBreedProfiles.ts>)에 정의한다.

각 견종 프로필은 아래 정보를 가진다.

- `displayName`
- `aliases`
- `sizeClass`
- `expectedLifespanYears`
- `groomingMonthly`
- `obesityRatePct`
- `riskFactors`
- `notes`
- `sources`

현재 등록된 대표 프로필은 아래와 같다.

- 푸들
- 말티즈
- 포메라니안
- 비숑 프리제
- 치와와
- 시추
- 요크셔테리어
- 진돗개
- 말티푸
- 믹스견
- 중형 믹스견
- 대형 믹스견

견종이 직접 매칭되지 않으면 아래 규칙을 사용한다.

- `mix`, `mixed`, `믹스`가 포함되면 믹스견 규칙
- 그 외는 체중 기반 대체 프로필

매칭 결과는 `exact`, `mixed`, `size_fallback`, `unknown` 중 하나로 저장한다.

## 7. 기본 모델값 계산

### 7.1 반복 고정비

기본 고정비는 아래 요소를 합쳐 만든다.

- 국내 평균 월 양육비의 식비 비중
- 국내 평균 월 양육비의 용품비 비중
- 견종별 미용비
- 보험료

기본 식비와 용품비는 체중대별 보정을 거친다.

```text
modeledFixedCost
= modeledFoodCost
+ modeledSuppliesCost
+ modeledGroomingCost
+ insurancePremium
```

### 7.2 반복 예방관리비

기본 예방관리비는 아래 요소를 합쳐 만든다.

- 국내 평균 양육비에서 식비/용품비/미용비를 제외한 기준치
- 연령 구간 추가비
- 견종별 반복 관리 리스크
- 현재 질환/복약 관리비
- 체중 관리 여유분

```text
modeledPlannedCareCost
= basePlannedCareCost
+ agePlannedCareCost
+ breedRiskFactor.plannedCareMonthly 합계
+ conditionCareCost
+ obesityCareCost
```

### 7.3 돌발진료 예비비

기본 돌발진료 예비비는 아래 요소를 합쳐 만든다.

- 국내 2년 평균 치료비를 월 단위로 환산한 기본치
- 연령 리스크 배수
- 견종별 예비비 리스크
- 현재 질환 지속 리스크
- 최근 방문 리스크
- 연간 방문 압력
- 체중 관련 리스크
- 보험 가입 할인

```text
modeledRiskAdjustedCost
= treatmentMonthlyReserve * ageRiskMultiplier
+ breedRiskFactor.reserveMonthly 합계
+ conditionReserveCost
+ visitReserveCost
+ annualVisitPressure
+ obesityReserveCost
+ insuranceReserveOffset
```

## 8. 개인화 보정

이번 버전의 핵심은 `기본 모델값` 위에 `실제 사용자 경험`을 점점 더 얹는 것이다.

### 8.1 관찰 창

엔진은 아래 두 개의 관찰 창을 사용한다.

- 최근 90일
- 최근 365일

각 창에서 아래 통계를 만든다.

- 거래 수
- 추적 개월 수
- 실제 지출이 있었던 개월 수
- 총액
- 월평균
- 양수 월 지출 중앙값
- 변동성

### 8.2 고정비 보정

고정비는 최근 90일 평균과 최근 365일 평균을 섞어 `historicalFixedMonthly`를 만든 뒤, 데이터가 충분한 만큼만 반영한다. 보험료는 연간 납입 기록이 한 번만 있어도 월 환산이 가능하도록 `insuranceModel`에서 따로 계산한 뒤 고정비에 합친다.

```text
fixedCost
= modeledFixedCost 와 historicalFixedMonthly의 가중 평균
```

반영 비중은 아래 요소로 계산한다.

- 실제 지출이 있었던 개월 수
- 추적 개월 수
- 거래 수

고정비 기록이 많을수록 `fixedHistoryWeight`가 커진다.

### 8.3 의료비 보정

의료비는 입력 카테고리와 최근 패턴을 함께 보고 두 덩어리로 나눈다.

- `historicalRoutineMedical`: 복약, 검진, 예방접종 같은 반복 관리비
- `historicalReserveMedical`: 병원, 응급, 수술, 치료 같은 돌발 예비비

카테고리가 명확하면 카테고리 분류를 우선한다. 카테고리 정보만으로 부족하면 `medicalRoutineShare()`가 변동성과 방문 횟수를 보고 반복비/예비비 비중을 보정한다.

입력값:

- 의료비 변동성
- 실제 지출이 있던 개월 수
- 최근 병원 방문 수

해석:

- 변동성이 낮으면 반복 관리비 비중을 높게 본다.
- 변동성이 높으면 돌발 예비비 비중을 높게 본다.
- 방문이 잦으면 반복비보다는 위험 예비비 쪽으로 더 기울인다.

### 8.4 총액 정렬 보정

개별 항목 보정 후에도 최근 실제 총지출 체감과 너무 멀면 마지막에 한 번 더 정렬한다.

```text
experienceAlignmentFactor
= 최근 체감 총지출 기준의 완만한 보정 계수
```

이 단계는 과도한 흔들림을 막기 위해 제한적으로만 적용한다.

### 8.5 개인 기준선

`personalBaseline`에는 현재 반려견의 관찰 기반 기준선을 저장한다.

- `fixedMonthly`
- `coreFixedMonthly`
- `routineMedicalMonthly`
- `eventReserveMonthly`
- `totalObservedMonthly`
- `activeMonths`
- `trackedMonths`

이 값은 최종 예측값 자체가 아니라, 모델값을 얼마나 실제 사용자 기록 쪽으로 끌어올지 판단하는 기준선이다.

### 8.6 질병 리스크 벡터

견종 리스크, 질환, 복약, 의료비 카테고리를 같은 축으로 묶어 `riskVector`를 만든다.

현재 축:

- 피부·귀
- 치과
- 관절
- 심장
- 안과
- 호흡기
- 대사·내분비
- 체중
- 소화기
- 일반 건강

`riskVector.topAxes`는 화면 인사이트와 설명 메타데이터에 사용한다. 같은 병원비라도 피부 치료인지, 치과 치료인지, 관절 치료인지에 따라 장기 관리 포인트가 달라지기 때문이다.

### 8.7 보험 모델

`insuranceModel`은 보험료와 보장 효과를 분리한다.

- 실제 `insurance` 지출이 있으면 연간 합계를 12개월로 나눠 월 보험료로 본다.
- 지출 기록은 없지만 보험 상태가 가입이면 기본 월 보험료를 사용한다.
- 보장 효과는 실제 상품 약관을 알 수 없으므로 돌발진료 예비비를 과하게 낮추지 않고 완만한 차감만 적용한다.

## 9. 과거 예측 오차 보정

엔진은 이전 예측과 실제 지출을 비교해서 `forecastBias`를 계산한다.

### 9.1 비교 방식

- 과거 `basic` 예측만 사용
- 예측 후 최소 30일 지난 기록만 사용
- 예측 후 최대 60일 창에서 실제 지출 관찰
- 서로 너무 가까운 예측은 일부만 선택

### 9.2 계산 결과

`evaluateForecastBias()`는 아래 값을 만든다.

- `factor`
- `strength`
- `evaluationCount`
- `averagePredictedMonthly`
- `averageActualMonthly`
- `averageAbsoluteErrorPct`
- `direction`

`direction`은 과거 예측이 실제 지출보다 낮았는지, 높았는지, 또는 방향이 섞였는지를 나타낸다.

### 9.3 적용 방식

실제 월지출이 과거 예측보다 계속 높거나 낮게 나왔으면, 현재 변수비용에 아래 보정을 건다.

```text
variableHistoryBiasFactor
= 1 + (forecastBias.factor - 1) * forecastBias.strength
```

즉, 사용자가 계속 “예측보다 더 많이 쓰는 편”이면 이후 예측도 조금 올라간다.

## 10. 신뢰도와 범위

### 10.1 confidenceLevel

현재 `confidenceLevel`은 아래 요소를 기준으로 정한다.

- 고정비 이력 반영 비중
- 의료비 이력 반영 비중
- 과거 예측 평가 건수
- 견종 직접 매칭 여부

결과 값:

- `high`
- `medium`
- `low`

### 10.2 rangeMin / rangeMax

예상 범위는 신뢰도와 의료비 변동성을 함께 보고 정한다.

- 신뢰도가 높을수록 범위를 좁힌다.
- 의료비 변동성이 높을수록 범위를 넓힌다.
- 과거 예측 평가 건수가 있으면 범위를 약간 줄인다.

## 11. 시나리오 구조

엔진은 3개 시나리오를 저장한다.

- `basic`
- `caution`
- `high_risk`

시나리오 차이는 `plannedCareCost`와 `riskAdjustedCost`에 다른 배수를 주는 방식이다.

### 11.1 basic

- 반복 관리비 배수: `1.0`
- 위험 예비비 배수: `1.0`

### 11.2 caution

- 반복 관리비 배수: `1.08`
- 위험 예비비 배수: `1.2 + volatilityStep * 0.06`

### 11.3 high_risk

- 반복 관리비 배수: `1.15`
- 위험 예비비 배수: `1.42 + volatilityStep * 0.1`

즉, 변동성이 큰 사용자일수록 `주의`, `고위험` 시나리오가 더 벌어진다.

## 12. 저장 구조

각 예측은 `cost_forecasts` 테이블에 저장된다.

주요 필드:

- `scenario`
- `monthlyEstimate`
- `rangeMin`
- `rangeMax`
- `yearlyEstimate`
- `sixMonthEstimate`
- `lifetimeEstimate`
- `confidenceLevel`
- `breakdown`
- `assumptions`

### 12.1 breakdown

`breakdown`에는 금액 구성 항목을 저장한다.

예:

- `fixedCost`
- `foodCost`
- `suppliesCost`
- `groomingCost`
- `insurancePremium`
- `insuranceReserveOffset`
- `historicalFixedMonthly`
- `historicalCoreFixedMonthly`
- `fixedHistoryWeight`
- `plannedCareCost`
- `historicalRoutineMedical`
- `riskAdjustedCost`
- `riskReserveBeforeInsurance`
- `historicalReserveMedical`
- `outlierReserveMonthly`
- `forecastBiasFactor`
- `experienceAlignmentFactor`

### 12.2 assumptions

`assumptions`에는 계산 근거와 설명용 메타데이터를 저장한다.

주요 하위 구조:

- `breedProfile`
- `historyModel`
- `categoryModel`
- `personalBaseline`
- `riskVector`
- `outlierModel`
- `insuranceModel`
- `validation`
- `methodology`
- `explanation`

## 13. API 응답 구조

최신 예측 응답은 [appRoutes.ts](</H:/programming/jonsulpu/backend/src/routes/appRoutes.ts>)의 `forecastResponse()`를 통해 아래 형태로 내려간다.

```json
{
  "basic": {
    "monthlyEstimate": 305000,
    "rangeMin": 262000,
    "rangeMax": 348000,
    "yearlyEstimate": 3660000,
    "sixMonthEstimate": 1830000,
    "lifetimeEstimate": 30825000,
    "confidenceLevel": "medium",
    "breakdown": {},
    "assumptions": {},
    "explanation": {}
  }
}
```

### 13.1 explanation

`explanation`은 화면 설명용으로 바로 사용한다.

구성:

- `title`
- `summary`
- `breedProfile`
- `drivers`
- `sources`

### 13.2 drivers

`drivers`는 상위 비용 요인 8개만 내린다.

각 항목은 아래 값을 가진다.

- `section`
- `label`
- `monthlyImpact`
- `reason`

## 14. 현재 사용 중인 외부 근거

### 14.1 국내 금액 기준

- KB 2025 반려동물 보고서
- KB 2025 반려동물 보고서 6화

국내 자료는 `원화 기준 기본금액`을 잡는 데 사용한다.

### 14.2 해외 임상/품종 근거

- Scientific Reports 2024 breed longevity
- Scientific Reports 2022 UK life tables
- Agria Breed Profiles
- AKC 수명/체중 가이드
- 견종별 AKC/클럽/VCA/PetMD 자료

해외 자료는 `질환 성향`, `수명`, `리스크 방향성`을 잡는 데 사용하고, 한국 가격표처럼 직접 환산하지 않는다.

## 15. 해석 원칙

이 엔진은 `정답 비용 계산기`가 아니다.

정확한 정의는 아래에 가깝다.

- 견종과 건강 상태를 기준으로 만든 기본 모델
- 실제 사용자 지출 기록을 점진적으로 반영하는 개인화 추정
- 과거 예측 오차를 학습하는 보정 레이어

즉, 결과는 `예산 계획용 추정치`로 이해해야 한다.

## 16. 유지보수 규칙

비용 엔진을 수정할 때는 아래를 함께 확인해야 한다.

### 16.1 수식 변경 시

- [backend/src/domain/costForecast.ts](</H:/programming/jonsulpu/backend/src/domain/costForecast.ts>)
- 이 문서
- `assumptions.engineVersion`

### 16.2 견종 추가 시

- [backend/src/domain/costBreedProfiles.ts](</H:/programming/jonsulpu/backend/src/domain/costBreedProfiles.ts>)에 프로필 추가
- `aliases`, `expectedLifespanYears`, `riskFactors`, `sources` 채우기
- 화면 설명이 이상하지 않은지 확인

### 16.3 응답 구조 변경 시

- [backend/src/routes/appRoutes.ts](</H:/programming/jonsulpu/backend/src/routes/appRoutes.ts>)
- [mobile/lib/main.dart](</H:/programming/jonsulpu/mobile/lib/main.dart>)

### 16.4 검증

권장 검증 절차:

- `npx tsc --noEmit`
- `npm run build`
- `npm run check:forecast`
- `node backend/scripts/e2e-smoke.mjs`
- `flutter analyze`
- `flutter test integration_test/app_flow_test.dart -d windows`

## 17. 비용 인사이트 응답

앱은 `basic.explanation.insights`를 사용해 비용 예측 카드 안에 핵심 인사이트를 표시한다.

각 인사이트는 아래 값을 가진다.

- `kind`: `attention`, `action`, `confidence` 중 하나
- `title`
- `body`
- `priority`
- `monthlyImpact`

인사이트는 기존 `drivers`를 대체하지 않는다. `drivers`는 상세 근거 목록이고, `insights`는 사용자가 다음에 무엇을 봐야 하는지 알려주는 짧은 실행 단서다.

현재 인사이트는 아래 상황을 우선 노출한다.

- 가장 큰 비용 요인
- 지출 기록 부족 또는 과거 예측 오차
- 질환, 복약, 체중, 병원비 변동성
- 고액 일회성 지출의 이상치 분리
- 가장 큰 질병 리스크 축
- 보험료와 보장 효과의 분리 반영

## 18. 향후 고도화 후보

- 사용자 군집별 보정 계수 추가
- 지역별 병원비 차이 반영
- 보험 상품 유형별 자기부담률, 보장 한도, 면책 기간 반영
- 장기 시계열이 쌓였을 때 계절성 반영
- 기존 `basic` 예측 오차를 단순 중앙값이 아니라 개월 수 가중 회귀로 보정

## 19. 한 줄 요약

현재 PawPlan 비용 계산 엔진은 `견종 기본값 + 최근 실제 지출 + 과거 예측 오차`를 합쳐, 사용자가 체감하는 비용과 점점 비슷해지도록 설계된 설명 가능한 추정 엔진이다.
