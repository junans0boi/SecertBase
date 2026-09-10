import { createHash } from 'node:crypto';
import {
  ENGINE_VERSION,
  RULESET,
  analyzeElements,
  analyzeSipseong,
  BRANCH_ANIMAL,
  BRANCH_HOURS,
  STEM_YANG,
  deriveSaju,
  iljuInfo,
  sipseongOf,
} from 'k-saju';

export const SAJU_CALCULATION_VERSION = `saju-v1-k-saju-${ENGINE_VERSION}`;
const SUPPORTED_YEAR_MIN = 1900;
const SUPPORTED_YEAR_MAX = 2050;
const KOREA_TIMEZONE = 'Asia/Seoul';

const hasText = (value) => typeof value === 'string' && value.trim().length > 0;

const offsetMinutesAt = (date, time, timezone) => {
  const wallClock = new Date(`${date}T${time}Z`);
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(wallClock);
  const values = Object.fromEntries(parts
    .filter(({ type }) => type !== 'literal')
    .map(({ type, value }) => [type, value]));
  const localAsUtc = Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second),
  );
  return Math.round((localAsUtc - wallClock.getTime()) / 60000);
};

const normalizeProfile = (profile) => profile == null ? null : ({
  calendarType: profile.calendarType ?? 'solar',
  birthDate: profile.birthDate ?? null,
  lunarLeapMonth: profile.lunarLeapMonth === true,
  birthTime: profile.birthTime ?? null,
  timezone: profile.timezone ?? null,
  birthPlace: profile.birthPlace ?? null,
});

const inputSummary = (profile) => ({
  calendarType: profile.calendarType,
  birthDate: profile.birthDate,
  lunarLeapMonth: profile.lunarLeapMonth,
  birthTime: profile.birthTime,
  timezone: profile.timezone,
  birthPlace: profile.birthPlace,
});

const basicProfileMissing = (profile) => !profile ||
  !hasText(profile.birthDate) || !hasText(profile.timezone) ||
  !['solar', 'lunar'].includes(profile.calendarType);

const missingOptionalFields = (profile) => [
  ...(hasText(profile.birthTime) ? [] : ['birthTimeMissing']),
  ...(hasText(profile.birthPlace) ? [] : ['birthPlaceMissing']),
];

const yearOf = (date) => Number(String(date).slice(0, 4));

const ELEMENT_PLAIN_NAME = {
  木: '나무',
  火: '불',
  土: '흙',
  金: '금속',
  水: '물',
};

const STEM_PLAIN_NAME = {
  甲: '갑', 乙: '을', 丙: '병', 丁: '정', 戊: '무',
  己: '기', 庚: '경', 辛: '신', 壬: '임', 癸: '계',
};

const ELEMENT_THEME = {
  木: { name: '나무', keywords: '성장·시작·유연함' },
  火: { name: '불', keywords: '표현·열정·활력' },
  土: { name: '흙', keywords: '안정·돌봄·현실감' },
  金: { name: '금속', keywords: '기준·정리·선명함' },
  水: { name: '물', keywords: '관찰·깊이·유연한 사고' },
};

const SIPSEONG_THEME = {
  비겁: { name: '나와 비슷한 힘', keywords: '자기주장·동료·경쟁' },
  식상: { name: '표현하는 힘', keywords: '말·창작·행동' },
  재성: { name: '현실을 다루는 힘', keywords: '관리·교환·생활감각' },
  관성: { name: '기준을 세우는 힘', keywords: '책임·규칙·경계' },
  인성: { name: '배우고 회복하는 힘', keywords: '배움·보호·도움받기' },
};

const STAGE_THEME = {
  장생: '새로운 감각이 자라나는 시작점',
  목욕: '익숙한 모습을 씻고 감각을 실험하는 구간',
  관대: '내 방식과 표현을 밖으로 펼쳐보는 구간',
  건록: '내 힘으로 기준을 세우고 꾸려가는 구간',
  제왕: '가장 선명하게 드러나는 힘을 관찰하는 구간',
  쇠: '속도를 조절하며 오래가는 방식을 찾는 구간',
  병: '무리한 부분을 알아차리고 회복을 우선하는 구간',
  사: '끝난 감정과 역할을 정리하는 구간',
  묘: '안쪽에 경험을 저장하고 다시 꺼내 보는 구간',
  절: '이전 흐름과 다음 흐름 사이를 비우는 구간',
  태: '아직 작지만 새로운 가능성을 품는 구간',
  양: '도움과 돌봄 속에서 천천히 힘을 기르는 구간',
};

const PILLAR_META = {
  year: { label: '년주', role: '뿌리와 바깥 인상' },
  month: { label: '월주', role: '성장 환경과 생활 리듬' },
  day: { label: '일주', role: '나의 중심과 관계 감각' },
  hour: { label: '시주', role: '미래의 관심과 표현' },
};

const elementEntry = (element, elements) => ({
  key: element,
  name: ELEMENT_PLAIN_NAME[element] ?? element,
  keywords: ELEMENT_THEME[element]?.keywords ?? '',
  count: elements.counts[element] ?? 0,
  weighted: Number((elements.weighted[element] ?? 0).toFixed(2)),
});

const sipseongEntry = (category, sipseong) => ({
  key: category,
  name: SIPSEONG_THEME[category]?.name ?? category,
  keywords: SIPSEONG_THEME[category]?.keywords ?? '',
  count: sipseong.counts[category] ?? 0,
});

const pillarEntry = (key, pillar) => {
  const meta = PILLAR_META[key];
  if (!pillar) {
    return {
      key,
      label: meta.label,
      role: meta.role,
      available: false,
      korean: null,
      hanja: null,
      description: '출생 시각이 없어 시주는 아직 계산하지 않았어요.',
    };
  }
  const animal = BRANCH_ANIMAL[pillar.branch];
  const hour = key === 'hour' ? BRANCH_HOURS[pillar.branch] : null;
  return {
    key,
    label: meta.label,
    role: meta.role,
    available: true,
    korean: pillar.korean,
    hanja: pillar.hanja,
    stem: pillar.stem,
    branch: pillar.branch,
    animal,
    clockRange: hour,
    description: `${meta.role}을 살펴보는 ${pillar.korean}(${pillar.hanja}) 기둥이에요.`,
  };
};

export const getSajuProfileState = (rawProfile) => {
  const profile = normalizeProfile(rawProfile);
  if (basicProfileMissing(profile)) {
    return { status: 'requires_profile', profile, missingFields: ['birthDate', 'timezone'] };
  }
  const year = yearOf(profile.birthDate);
  if (!Number.isInteger(year) || year < SUPPORTED_YEAR_MIN || year > SUPPORTED_YEAR_MAX) {
    return {
      status: 'unsupported_range',
      profile,
      limitations: ['birthDateOutsideSupportedRange'],
    };
  }
  const optionalMissing = missingOptionalFields(profile);
  const timezoneLimited = profile.timezone !== KOREA_TIMEZONE;
  return {
    status: optionalMissing.length || timezoneLimited ? 'limited_available' : 'ready',
    profile,
    missingFields: optionalMissing,
    limitations: [
      ...optionalMissing,
      ...(timezoneLimited ? ['timezoneLimited'] : []),
    ],
  };
};

const plainTitle = ({ elements, day }) => {
  if (elements.lacking.length > 0) {
    const missing = elements.lacking.map((element) => ELEMENT_PLAIN_NAME[element] ?? element);
    return `${day.korean} 일주, ${missing.join('·')} 기운을 살펴보는 날`;
  }
  return `${day.korean} 일주, 내 중심을 차분히 살펴보는 날`;
};

const plainReading = ({ chart, elements, sipseong, ilju, limitations }) => {
  const dayElement = ELEMENT_THEME[ilju.stemElement] ?? {
    name: ilju.stemElement,
    keywords: '',
  };
  const dayStemName = STEM_PLAIN_NAME[ilju.dayStem] ?? ilju.dayStem;
  const polarity = STEM_YANG[ilju.dayStem] ? '양' : '음';
  const dominantSipseong = sipseong.dominant.map((category) => ({
    category,
    ...SIPSEONG_THEME[category],
  }));
  const dominantElements = elements.excess.map((element) => ({
    key: element,
    name: ELEMENT_PLAIN_NAME[element] ?? element,
    keywords: ELEMENT_THEME[element]?.keywords ?? '',
  }));
  const lackingElements = elements.lacking.map((element) => ({
    key: element,
    name: ELEMENT_PLAIN_NAME[element] ?? element,
    keywords: ELEMENT_THEME[element]?.keywords ?? '',
  }));
  return {
    title: plainTitle({ elements, day: chart.day }),
    summary: `네 기둥과 ${ilju.ganji} 일주를 함께 보면, 지금 내 마음이 어떤 방식으로 움직이는지 더 입체적으로 살펴볼 수 있어요.`,
    focus: elements.lacking.length > 0
      ? `${elements.lacking.map((element) => ELEMENT_PLAIN_NAME[element] ?? element).join('·')} 기운이 비어 있어, 그 반대편의 휴식·유연함·도움을 의식해보세요.`
      : '한 가지 기운으로 나를 단정하지 말고, 지금 잘하고 있는 것과 더 돌보고 싶은 것을 각각 적어보세요.',
    limitationNotice: limitations.length > 0
      ? '일부 출생 정보가 없어 기본 명식 중심으로 안내해요.'
      : null,
    disclaimer: '사주는 자기 성찰을 돕는 콘텐츠이며 사실 예측이나 진단이 아니에요.',
    dayPillar: ilju.ganji,
    dominantThemes: sipseong.dominant,
    pillars: [
      pillarEntry('year', chart.year),
      pillarEntry('month', chart.month),
      pillarEntry('day', chart.day),
      pillarEntry('hour', chart.hour),
    ],
    dayMaster: {
      stem: ilju.dayStem,
      stemName: dayStemName,
      polarity,
      element: ilju.stemElement,
      elementName: dayElement.name,
      label: `${dayStemName}${dayElement.name}(${ilju.dayStem}${ilju.stemElement})`,
      keywords: dayElement.keywords,
      summary: `내 중심을 뜻하는 일간은 ${dayStemName}${dayElement.name}이에요. ${dayElement.keywords}처럼 내가 가진 기준과 반응을 관찰해보는 출발점으로 삼아보세요.`,
    },
    elements: {
      entries: ['木', '火', '土', '金', '水'].map((element) => elementEntry(element, elements)),
      lacking: lackingElements,
      dominant: dominantElements,
      summary: lackingElements.length > 0
        ? `${lackingElements.map(({ name }) => name).join('·')} 기운은 명식의 본기에서 드러나지 않고, ${dominantElements.length > 0 ? dominantElements.map(({ name }) => name).join('·') : '다른'} 기운이 상대적으로 많이 보여요.`
        : '다섯 기운이 모두 드러나 있어, 어느 한쪽으로 나를 단정하기보다 상황에 따라 균형이 어떻게 달라지는지 살펴보면 좋아요.',
    },
    sipseong: {
      entries: ['비겁', '식상', '재성', '관성', '인성'].map((category) => sipseongEntry(category, sipseong)),
      dominant: dominantSipseong,
      summary: dominantSipseong.length > 0
        ? `${dominantSipseong.map(({ name }) => name).join('·')} 흐름이 비교적 선명해요. ${dominantSipseong.map(({ keywords }) => keywords).join('·')}을/를 관계와 생활에서 어떻게 쓰는지 관찰해보세요.`
        : '한 가지 십신에만 기대지 않고 여러 반응을 고르게 관찰해보세요.',
    },
    ilju: {
      ganji: ilju.ganji,
      dayStem: ilju.dayStem,
      dayBranch: ilju.dayBranch,
      branchElement: ilju.branchElement,
      branchSipseong: ilju.branchSipseong,
      twelveStage: ilju.twelveStage,
      stageSummary: STAGE_THEME[ilju.twelveStage] ?? '내 힘의 흐름을 천천히 관찰하는 구간',
      summary: `${ilju.ganji} 일주는 ${ilju.twelveStage}의 흐름과 ${ilju.branchSipseong ?? '일지'}의 관계를 함께 봐요. ${STAGE_THEME[ilju.twelveStage] ?? '내 힘의 흐름을 천천히 관찰하는 구간'}으로 읽어보세요.`,
    },
    reflectionPrompts: [
      `내 중심인 ${dayStemName}${dayElement.name}의 장점을 오늘 어떤 행동으로 써볼까요?`,
      lackingElements.length > 0
        ? `${lackingElements.map(({ name }) => name).join('·')} 기운을 보완하기 위해 누구에게 어떤 도움을 청해볼까요?`
        : '오늘 내 균형을 지켜준 작은 습관은 무엇이었나요?',
      '네 기둥 중 지금의 나와 가장 닮았다고 느껴지는 기둥은 무엇인가요?',
    ],
  };
};

export const calculatePersonalSaju = ({ profile: rawProfile, mode = 'complete' }) => {
  const state = getSajuProfileState(rawProfile);
  if (state.status === 'requires_profile') {
    const error = new Error('birth_profile_incomplete');
    error.code = 'birth_profile_incomplete';
    error.status = 422;
    throw error;
  }
  if (state.status === 'unsupported_range') {
    const error = new Error('unsupported_birth_date_range');
    error.code = 'unsupported_birth_date_range';
    error.status = 422;
    throw error;
  }
  if (mode === 'complete' && state.status !== 'ready') {
    const error = new Error('saju_limited_confirmation_required');
    error.code = 'saju_limited_confirmation_required';
    error.status = 409;
    error.missingFields = state.missingFields;
    error.limitations = state.limitations;
    throw error;
  }

  const profile = state.profile;
  const limited = mode === 'limited';
  const time = profile.birthTime?.slice(0, 5);
  const tzOffsetMin = offsetMinutesAt(profile.birthDate, time ?? '12:00', profile.timezone);
  const chart = deriveSaju({
    date: profile.birthDate,
    ...(time ? { time } : {}),
    calendar: profile.calendarType,
    isLeapMonth: profile.calendarType === 'lunar' ? profile.lunarLeapMonth : undefined,
    tzOffsetMin,
  });
  const elements = analyzeElements(chart);
  const sipseong = analyzeSipseong(chart);
  const ilju = iljuInfo(chart);
  const limitations = [
    ...state.limitations,
    ...(limited && !state.limitations.includes('birthTimeMissing') && profile.birthTime
      ? ['limitedModeSelected']
      : []),
  ];
  const result = {
    scope: 'user',
    mode: limited ? 'limited' : 'complete',
    inputSummary: inputSummary(profile),
    basis: [
      `k-saju ${ENGINE_VERSION}`,
      `규칙 세트 ${RULESET}`,
      '입춘·절기 시각과 출생지 문자열을 기준으로 서버에서 결정론적으로 계산',
    ],
    limitations,
    plain: plainReading({ chart, elements, sipseong, ilju, limitations }),
    technical: {
      engine: 'k-saju',
      engineVersion: ENGINE_VERSION,
      ruleset: RULESET,
      chart,
      elements,
      sipseong,
      ilju,
      tzOffsetMin,
    },
  };
  return {
    status: limited || limitations.length > 0 ? 'limited' : 'ready',
    calculationVersion: SAJU_CALCULATION_VERSION,
    ...result,
  };
};

const participantLimitations = (state, prefix) => {
  const label = prefix === 'first' ? 'first' : 'second';
  return (state.limitations ?? []).map((limitation) => {
    const suffix = limitation.charAt(0).toUpperCase() + limitation.slice(1);
    return `${label}${suffix}`;
  });
};

const dominantElements = (elements) => {
  const entries = Object.entries(elements.counts);
  const max = Math.max(...entries.map(([, count]) => count));
  return entries.filter(([, count]) => count === max).map(([element]) => element);
};

const sharedElements = (first, second) => dominantElements(first)
  .filter((element) => dominantElements(second).includes(element));

const relationTheme = {
  비겁: {
    title: '비슷한 힘을 주고받는 사이',
    summary: '서로의 속도와 의지를 비슷한 눈높이에서 알아차릴 수 있어요.',
    question: '우리가 요즘 비슷한 속도로 힘을 쓰고 있는 일은 무엇인가요?',
  },
  식상: {
    title: '표현과 반응을 넓히는 사이',
    summary: '한 사람의 표현이 다른 사람의 반응과 아이디어를 열어줄 수 있어요.',
    question: '내가 건넨 표현 중 상대가 편하게 받아들였던 것은 무엇이었나요?',
  },
  재성: {
    title: '현실적인 챙김을 나누는 사이',
    summary: '작은 약속과 생활 속 챙김이 관계의 안정감을 만들 수 있어요.',
    question: '이번 주에 서로에게 가장 현실적으로 도움이 될 작은 일은 무엇인가요?',
  },
  관성: {
    title: '기준과 책임을 조율하는 사이',
    summary: '서로 중요하게 여기는 기준을 확인하면 부담을 나눌 수 있어요.',
    question: '지금 우리 사이에서 함께 정하고 싶은 기준 하나는 무엇인가요?',
  },
  인성: {
    title: '배움과 돌봄을 나누는 사이',
    summary: '서로의 경험과 돌봄이 마음을 회복하는 자원이 될 수 있어요.',
    question: '요즘 상대에게 받고 싶은 돌봄이나 이해는 어떤 모양인가요?',
  },
};

export const buildRelationshipSaju = ({
  firstProfile: rawFirstProfile,
  secondProfile: rawSecondProfile,
  mode = 'complete',
}) => {
  const firstState = getSajuProfileState(rawFirstProfile);
  const secondState = getSajuProfileState(rawSecondProfile);
  if (firstState.status === 'requires_profile' || secondState.status === 'requires_profile') {
    const error = new Error('relationship_saju_profile_incomplete');
    error.code = 'relationship_saju_profile_incomplete';
    error.status = 422;
    throw error;
  }
  if (firstState.status === 'unsupported_range' || secondState.status === 'unsupported_range') {
    const error = new Error('relationship_saju_unsupported_range');
    error.code = 'relationship_saju_unsupported_range';
    error.status = 422;
    throw error;
  }
  const limited = mode === 'limited' || firstState.status !== 'ready' || secondState.status !== 'ready';
  const calculationMode = limited ? 'limited' : 'complete';
  const first = calculatePersonalSaju({ profile: firstState.profile, mode: calculationMode });
  const second = calculatePersonalSaju({ profile: secondState.profile, mode: calculationMode });
  const firstElements = first.technical.elements;
  const secondElements = second.technical.elements;
  const common = sharedElements(firstElements, secondElements);
  const dayMasterRelation = sipseongOf(
    first.technical.chart.day.stem,
    second.technical.chart.day.stem,
  );
  const theme = relationTheme[dayMasterRelation] ?? {
    title: '서로의 차이를 알아가는 사이',
    summary: '서로 다른 반응과 속도를 비교하기보다 먼저 이해해보세요.',
    question: '서로 다르게 반응하는 순간에 먼저 확인하고 싶은 마음은 무엇인가요?',
  };
  const patterns = [
    {
      key: 'element_balance',
      title: common.length > 0 ? '함께 닿아 있는 기운' : '서로 다른 균형을 살펴보기',
      summary: common.length > 0
        ? `${common.join('·')} 기운을 매개로 서로의 상태를 알아차려보세요.`
        : '서로의 강점과 부족함을 우열 없이 관찰해보세요.',
    },
    {
      key: 'day_master_relation',
      title: theme.title,
      summary: theme.summary,
    },
  ];
  return {
    scope: 'couple',
    status: limited ? 'limited' : 'ready',
    mode: calculationMode,
    inputSummary: {
      firstMode: first.mode,
      secondMode: second.mode,
      firstLimitations: participantLimitations(firstState, 'first'),
      secondLimitations: participantLimitations(secondState, 'second'),
    },
    basis: [
      `k-saju ${ENGINE_VERSION}`,
      '두 명식의 오행 균형과 일간 관계를 패턴 카드로만 표현',
    ],
    limitations: [
      ...participantLimitations(firstState, 'first'),
      ...participantLimitations(secondState, 'second'),
      ...(mode === 'limited' ? ['limitedModeSelected'] : []),
    ],
    patterns,
    conversationQuestions: [
      theme.question,
      '이번 주에 서로의 마음을 확인하기 위해 어떤 질문을 먼저 건네볼까요?',
    ],
    disclaimer: '관계 사주는 우열이나 미래를 정하는 점수가 아니라 대화를 돕는 참고 콘텐츠예요.',
  };
};

export const fingerprintSajuInput = (profile) => createHash('sha256')
  .update(JSON.stringify({ version: SAJU_CALCULATION_VERSION, ...inputSummary(normalizeProfile(profile)) }))
  .digest('hex');

export const fingerprintSajuPair = (firstProfile, secondProfile) => createHash('sha256')
  .update(JSON.stringify({
    version: SAJU_CALCULATION_VERSION,
    first: inputSummary(normalizeProfile(firstProfile)),
    second: inputSummary(normalizeProfile(secondProfile)),
  }))
  .digest('hex');

export const sajuApiState = { SUPPORTED_YEAR_MIN, SUPPORTED_YEAR_MAX, KOREA_TIMEZONE };
