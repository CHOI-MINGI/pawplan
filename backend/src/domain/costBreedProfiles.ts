export type BreedSizeClass = "toy" | "small" | "medium" | "large";

export type BreedSource = {
  label: string;
  url: string;
};

export type BreedRiskFactor = {
  key: string;
  label: string;
  plannedCareMonthly: number;
  reserveMonthly: number;
  reason: string;
};

export type BreedProfile = {
  key: string;
  displayName: string;
  aliases: readonly string[];
  sizeClass: BreedSizeClass;
  expectedLifespanYears: readonly [number, number];
  groomingMonthly: number;
  obesityRatePct?: number;
  riskFactors: readonly BreedRiskFactor[];
  notes: readonly string[];
  sources: readonly BreedSource[];
};

export type BreedMatchType =
  | "exact"
  | "mixed"
  | "size_fallback"
  | "unknown";

export type ResolvedBreedProfile = {
  profile: BreedProfile;
  inputBreed: string;
  normalizedBreed: string;
  matchType: BreedMatchType;
};

const kbBreedResearch: BreedSource = {
  label: "KB 2025 한국 반려동물 보고서",
  url: "https://kbthink.com/content/dam/kb-financial-group/holdings/IBR/05/2025/06/202506290838130/2025%ED%95%9C%EA%B5%AD%EB%B0%98%EB%A0%A4%EB%8F%99%EB%AC%BC%EB%B3%B4%EA%B3%A0%EC%84%9C.pdf",
};

const akcLifeResearch: BreedSource = {
  label: "AKC 평균 수명 가이드",
  url: "https://www.akc.org/expert-advice/health/general-health/how-long-do-dogs-live/",
};

const akcMixedResearch: BreedSource = {
  label: "AKC 믹스견 건강 가이드",
  url: "https://www.akc.org/expert-advice/dog-breeds/mixed-breed-purebred-health/",
};

function profile(definition: BreedProfile): BreedProfile {
  return definition;
}

const profiles = [
  profile({
    key: "poodle",
    displayName: "푸들",
    aliases: [
      "푸들",
      "토이푸들",
      "미니어처푸들",
      "스탠다드푸들",
      "poodle",
      "toypoodle",
      "miniaturepoodle",
      "standardpoodle",
    ],
    sizeClass: "small",
    expectedLifespanYears: [12, 15],
    groomingMonthly: 26000,
    obesityRatePct: 6.9,
    riskFactors: [
      {
        key: "skin-ear",
        label: "피부·귀 관리",
        plannedCareMonthly: 7000,
        reserveMonthly: 6000,
        reason: "피부와 귀 관리가 자주 필요해 예방성 체크 비용을 조금 더 반영했습니다.",
      },
      {
        key: "orthopedic",
        label: "관절·슬개골 체크",
        plannedCareMonthly: 6000,
        reserveMonthly: 8000,
        reason: "소형 푸들은 관절 관련 모니터링이 꾸준히 필요한 편이라 예비비를 더 잡았습니다.",
      },
      {
        key: "endocrine",
        label: "내분비·만성질환 대비",
        plannedCareMonthly: 5000,
        reserveMonthly: 9000,
        reason: "푸들 계열은 만성 관리가 길어질 수 있어 위험 예비비를 높였습니다.",
      },
    ],
    notes: [
      "장수형 소형견이지만 곱슬 코트 특성상 미용비 비중이 평균보다 높습니다.",
      "피부·귀·관절·내분비 축을 주기 관리 포인트로 둡니다.",
    ],
    sources: [
      akcLifeResearch,
      {
        label: "Poodle Club of America 건강 성명서",
        url: "https://cdn.akc.org/Marketplace/Health-Statement/Poodle.pdf",
      },
      {
        label: "AKC 푸들 관리 가이드",
        url: "https://www.akc.org/expert-advice/dog-breeds/poodle-right-for-you/",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "maltese",
    displayName: "말티즈",
    aliases: ["말티즈", "maltese"],
    sizeClass: "toy",
    expectedLifespanYears: [12, 14],
    groomingMonthly: 24000,
    obesityRatePct: 16.0,
    riskFactors: [
      {
        key: "dental",
        label: "치과 관리",
        plannedCareMonthly: 8000,
        reserveMonthly: 6000,
        reason: "소형견 특유의 치아·구강 관리가 자주 필요해 예방관리 비용을 더 반영했습니다.",
      },
      {
        key: "cardiac",
        label: "심장 모니터링",
        plannedCareMonthly: 5000,
        reserveMonthly: 9000,
        reason: "심장성 질환을 놓치지 않도록 중장년 이후 검진 여유를 더 잡았습니다.",
      },
      {
        key: "liver",
        label: "간·선천성 이슈 대비",
        plannedCareMonthly: 4000,
        reserveMonthly: 7000,
        reason: "선천성 간 이슈 가능성을 반영해 예비비를 조금 높였습니다.",
      },
    ],
    notes: [
      "한국에서 매우 흔한 소형견이라 국내 평균비를 적용하기 좋지만, 치과와 미용은 평균보다 자주 잡는 편이 안전합니다.",
    ],
    sources: [
      {
        label: "VCA 말티즈 품종 가이드",
        url: "https://vcahospitals.com/know-your-pet/dog-breeds/maltese",
      },
      {
        label: "American Maltese Association 건강 가이드",
        url: "https://cdn.akc.org/Marketplace/Health-Statement/Maltese.pdf",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "pomeranian",
    displayName: "포메라니안",
    aliases: ["포메라니안", "pom", "pomeranian"],
    sizeClass: "toy",
    expectedLifespanYears: [14, 16],
    groomingMonthly: 23000,
    obesityRatePct: 22.2,
    riskFactors: [
      {
        key: "trachea-airway",
        label: "기관·호흡기 대비",
        plannedCareMonthly: 5000,
        reserveMonthly: 9000,
        reason: "기관과 호흡기 쪽 리스크를 반영해 돌발 진료 예비비를 올렸습니다.",
      },
      {
        key: "orthopedic",
        label: "슬개골·관절 체크",
        plannedCareMonthly: 7000,
        reserveMonthly: 8000,
        reason: "슬개골 관리가 흔해 정기 체크와 보조비를 더 잡았습니다.",
      },
      {
        key: "cardiac-thyroid",
        label: "심장·갑상선 추적",
        plannedCareMonthly: 5000,
        reserveMonthly: 7000,
        reason: "중장년기 심장·갑상선 확인 비용을 평균보다 높게 둡니다.",
      },
    ],
    notes: [
      "장수형 토이견이지만 코트 관리와 슬개골 관리 때문에 관리 예산 편차가 큰 편입니다.",
    ],
    sources: [
      akcLifeResearch,
      {
        label: "American Pomeranian Club 건강 성명서",
        url: "https://cdn.akc.org/Marketplace/Health-Statement/Pomeranian.pdf",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "bichon-frise",
    displayName: "비숑 프리제",
    aliases: ["비숑", "비숑프리제", "bichon", "bichonfrise"],
    sizeClass: "small",
    expectedLifespanYears: [14, 15],
    groomingMonthly: 26000,
    obesityRatePct: 11.3,
    riskFactors: [
      {
        key: "skin",
        label: "피부·알레르기 관리",
        plannedCareMonthly: 7000,
        reserveMonthly: 7000,
        reason: "피부 관리와 식이 조절이 비용을 꾸준히 만드는 편이라 반영했습니다.",
      },
      {
        key: "dental",
        label: "치과 관리",
        plannedCareMonthly: 7000,
        reserveMonthly: 5000,
        reason: "소형견 치과 관리 비중을 평균보다 높였습니다.",
      },
      {
        key: "orthopedic-eye",
        label: "관절·안과 체크",
        plannedCareMonthly: 5000,
        reserveMonthly: 7000,
        reason: "관절과 눈 관련 모니터링 비용을 조금 더 반영했습니다.",
      },
    ],
    notes: [
      "미용주기가 짧고 피부 컨디션에 따라 사료·간식 선택 비용이 흔들리기 쉽습니다.",
    ],
    sources: [
      {
        label: "AKC 비숑 프리제 평균 수명 가이드",
        url: "https://www.akc.org/expert-advice/health/general-health/how-long-do-dogs-live/",
      },
      {
        label: "Bichon Frise Club of America 건강 성명서",
        url: "https://cdn.akc.org/Marketplace/Health-Statement/BichonFrise.pdf",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "chihuahua",
    displayName: "치와와",
    aliases: ["치와와", "치와와장모", "치와와단모", "chihuahua"],
    sizeClass: "toy",
    expectedLifespanYears: [15, 17],
    groomingMonthly: 12000,
    obesityRatePct: 27.0,
    riskFactors: [
      {
        key: "cardiac",
        label: "심장 추적",
        plannedCareMonthly: 5000,
        reserveMonthly: 9000,
        reason: "심장 리스크를 반영해 중장년기 모니터링 예산을 높였습니다.",
      },
      {
        key: "patella-eye",
        label: "슬개골·안과 관리",
        plannedCareMonthly: 6000,
        reserveMonthly: 7000,
        reason: "작은 체구에서 자주 보는 관절·안과 문제 대비 비용을 더했습니다.",
      },
      {
        key: "weight",
        label: "체중 관리",
        plannedCareMonthly: 4000,
        reserveMonthly: 6000,
        reason: "비만 위험률이 높아 체중 관리 여유분을 포함했습니다.",
      },
    ],
    notes: [
      "초소형견이라 식비는 낮지만 체중·심장·슬개골 관리에 민감합니다.",
    ],
    sources: [
      akcLifeResearch,
      {
        label: "Chihuahua Club of America 건강 성명서",
        url: "https://cdn.akc.org/Marketplace/Health-Statement/Chihuahua.pdf",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "shih-tzu",
    displayName: "시추",
    aliases: ["시추", "shihtzu", "shihtzu"],
    sizeClass: "small",
    expectedLifespanYears: [10, 18],
    groomingMonthly: 23000,
    obesityRatePct: 5.4,
    riskFactors: [
      {
        key: "airway-eye",
        label: "호흡기·안과 체크",
        plannedCareMonthly: 9000,
        reserveMonthly: 10000,
        reason: "짧은 얼굴형 특성상 눈과 호흡기 관리 비용을 더 반영했습니다.",
      },
      {
        key: "skin",
        label: "피부·귀 관리",
        plannedCareMonthly: 6000,
        reserveMonthly: 6000,
        reason: "코트와 피부 관리가 정기 지출로 이어지기 쉬워 예방비를 높였습니다.",
      },
    ],
    notes: [
      "미용과 안과 관리 비중이 높은 대표 소형견으로 분류했습니다.",
    ],
    sources: [
      {
        label: "PetMD 시추 품종 가이드",
        url: "https://www.petmd.com/dog/breeds/shih-tzu",
      },
      {
        label: "American Shih Tzu Club 건강 성명서",
        url: "https://cdn.akc.org/Marketplace/Health-Statement/ShihTzu.pdf",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "yorkshire-terrier",
    displayName: "요크셔테리어",
    aliases: ["요크셔", "요크셔테리어", "yorkie", "yorkshireterrier"],
    sizeClass: "toy",
    expectedLifespanYears: [14, 16],
    groomingMonthly: 22000,
    obesityRatePct: 29.2,
    riskFactors: [
      {
        key: "dental",
        label: "치과 관리",
        plannedCareMonthly: 8000,
        reserveMonthly: 6000,
        reason: "구강 관리가 비용을 만드는 대표 품종이라 정기관리비를 높였습니다.",
      },
      {
        key: "liver-metabolic",
        label: "간·대사 관리",
        plannedCareMonthly: 5000,
        reserveMonthly: 8000,
        reason: "체구가 작아 대사성 이슈 대응 예비비를 조금 더 잡았습니다.",
      },
      {
        key: "weight",
        label: "비만 관리",
        plannedCareMonthly: 5000,
        reserveMonthly: 7000,
        reason: "비만 위험률이 높아 체중 관리 예산을 추가했습니다.",
      },
    ],
    notes: [
      "식비는 낮지만 치과와 체중 관리 쪽에서 비용 방어가 중요합니다.",
    ],
    sources: [
      {
        label: "VCA 요크셔테리어 품종 가이드",
        url: "https://vcahospitals.com/know-your-pet/dog-breeds/yorkshire-terrier",
      },
      {
        label: "Yorkshire Terrier Club of America 건강 참고 자료",
        url: "https://images.akc.org/pdf/breeds/ytca/YTCA_Health.pdf",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "jindo",
    displayName: "진돗개",
    aliases: ["진돗개", "진도개", "jindo", "koreanjindo", "koreanjindodog"],
    sizeClass: "medium",
    expectedLifespanYears: [10, 13],
    groomingMonthly: 10000,
    obesityRatePct: 5.7,
    riskFactors: [
      {
        key: "activity-joint",
        label: "활동량·관절 관리",
        plannedCareMonthly: 5000,
        reserveMonthly: 7000,
        reason: "중형 활동견 특성을 반영해 관절·근육 관리 예산을 조금 더 잡았습니다.",
      },
    ],
    notes: [
      "중형 활동견 기준으로 식비와 용품비가 소형견보다 높게 계산됩니다.",
    ],
    sources: [
      akcLifeResearch,
      {
        label: "AKC Korean Jindo Dog 품종 소개",
        url: "https://www.akc.org/dog-breeds/jindo/",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "maltipoo",
    displayName: "말티푸",
    aliases: ["말티푸", "maltipoo"],
    sizeClass: "toy",
    expectedLifespanYears: [12, 15],
    groomingMonthly: 26000,
    obesityRatePct: 11.1,
    riskFactors: [
      {
        key: "coat-skin",
        label: "코트·피부 관리",
        plannedCareMonthly: 7000,
        reserveMonthly: 7000,
        reason: "말티즈와 푸들의 코트 특성이 겹쳐 미용·피부 관리 비용을 높였습니다.",
      },
      {
        key: "dental-orthopedic",
        label: "치과·슬개골 체크",
        plannedCareMonthly: 7000,
        reserveMonthly: 8000,
        reason: "양쪽 부모 품종에서 자주 보는 소형견 관리 포인트를 합산했습니다.",
      },
    ],
    notes: [
      "말티즈와 푸들 부모 품종의 공통 관리 포인트를 보수적으로 합산한 프로필입니다.",
    ],
    sources: [
      {
        label: "Maltese breed guide",
        url: "https://vcahospitals.com/know-your-pet/dog-breeds/maltese",
      },
      {
        label: "Poodle Club of America 건강 성명서",
        url: "https://cdn.akc.org/Marketplace/Health-Statement/Poodle.pdf",
      },
      kbBreedResearch,
    ],
  }),
  profile({
    key: "mixed",
    displayName: "믹스견",
    aliases: ["믹스", "믹스견", "mix", "mixed", "mixedbreed"],
    sizeClass: "small",
    expectedLifespanYears: [11, 14],
    groomingMonthly: 15000,
    obesityRatePct: 10.7,
    riskFactors: [
      {
        key: "general",
        label: "일반 예방관리",
        plannedCareMonthly: 5000,
        reserveMonthly: 5000,
        reason: "특정 품종이 확인되지 않으면 체급 중심으로 보수적 관리비를 둡니다.",
      },
    ],
    notes: [
      "품종명이 불명확하면 특정 질환 편향 대신 체급과 현재 건강 기록을 더 강하게 반영합니다.",
    ],
    sources: [akcMixedResearch, kbBreedResearch],
  }),
  profile({
    key: "mixed-medium",
    displayName: "중형 믹스견",
    aliases: [],
    sizeClass: "medium",
    expectedLifespanYears: [10, 13],
    groomingMonthly: 12000,
    obesityRatePct: 10.7,
    riskFactors: [
      {
        key: "general-medium",
        label: "중형견 예방관리",
        plannedCareMonthly: 5000,
        reserveMonthly: 7000,
        reason: "중형견은 소형견보다 식비와 관절 예비비가 더 커서 이를 반영합니다.",
      },
    ],
    notes: ["품종이 불명확한 중형견은 체급 기준으로 추정합니다."],
    sources: [akcMixedResearch, akcLifeResearch, kbBreedResearch],
  }),
  profile({
    key: "mixed-large",
    displayName: "대형 믹스견",
    aliases: [],
    sizeClass: "large",
    expectedLifespanYears: [8, 12],
    groomingMonthly: 12000,
    riskFactors: [
      {
        key: "general-large",
        label: "대형견 예방관리",
        plannedCareMonthly: 7000,
        reserveMonthly: 12000,
        reason: "대형견은 식비와 관절 관련 예비비가 더 커서 보수적으로 계산합니다.",
      },
    ],
    notes: ["품종이 불명확한 대형견은 체급 기준으로 추정합니다."],
    sources: [akcMixedResearch, akcLifeResearch, kbBreedResearch],
  }),
] as const satisfies readonly BreedProfile[];

const aliasMap = new Map<string, BreedProfile>();
for (const breedProfile of profiles) {
  for (const alias of breedProfile.aliases) {
    aliasMap.set(normalizeBreedName(alias), breedProfile);
  }
}

export function normalizeBreedName(value: string | null | undefined) {
  return (value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[\s\-_/()]/g, "");
}

export function sizeClassFromWeight(weightKg: number): BreedSizeClass {
  if (weightKg <= 4) return "toy";
  if (weightKg <= 10) return "small";
  if (weightKg <= 25) return "medium";
  return "large";
}

export function sizeClassLabel(sizeClass: BreedSizeClass) {
  return (
    {
      toy: "초소형",
      small: "소형",
      medium: "중형",
      large: "대형",
    } as const
  )[sizeClass];
}

function fallbackProfileForWeight(weightKg: number) {
  const sizeClass = sizeClassFromWeight(weightKg);
  if (sizeClass === "medium") {
    return profiles.find((item) => item.key === "mixed-medium") ?? profiles[0];
  }
  if (sizeClass === "large") {
    return profiles.find((item) => item.key === "mixed-large") ?? profiles[0];
  }
  return profiles.find((item) => item.key === "mixed") ?? profiles[0];
}

export function resolveBreedProfile(
  breed: string | null | undefined,
  weightKg: number,
): ResolvedBreedProfile {
  const inputBreed = (breed ?? "").trim();
  const normalizedBreed = normalizeBreedName(inputBreed);
  const matched = aliasMap.get(normalizedBreed);
  if (matched) {
    return {
      profile: matched,
      inputBreed,
      normalizedBreed,
      matchType: matched.key.startsWith("mixed") ? "mixed" : "exact",
    };
  }

  if (
    normalizedBreed.includes("mix") ||
    normalizedBreed.includes("mixed") ||
    normalizedBreed.includes("믹스")
  ) {
    return {
      profile: fallbackProfileForWeight(weightKg),
      inputBreed,
      normalizedBreed,
      matchType: "mixed",
    };
  }

  return {
    profile: fallbackProfileForWeight(weightKg),
    inputBreed,
    normalizedBreed,
    matchType: inputBreed ? "size_fallback" : "unknown",
  };
}
