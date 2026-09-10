import { createHash } from 'node:crypto';
import {
  ENGINE_VERSION,
  RULESET,
  analyzeElements,
  analyzeSipseong,
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

const plainReading = ({ chart, elements, sipseong, ilju, limitations }) => ({
  title: plainTitle({ elements, day: chart.day }),
  summary: `오늘은 ${chart.day.korean} 일주를 바탕으로 내 마음과 생활의 균형을 천천히 살펴보세요.`,
  focus: elements.lacking.length > 0
    ? `${elements.lacking.join('·')} 기운이 비어 있어 휴식과 주변의 도움을 의식해보세요.`
    : '지금 잘하고 있는 것과 더 돌보고 싶은 것을 한 가지씩 적어보세요.',
  limitationNotice: limitations.length > 0
    ? '일부 출생 정보가 없어 기본 명식 중심으로 안내해요.'
    : null,
  disclaimer: '사주는 자기 성찰을 돕는 콘텐츠이며 사실 예측이나 진단이 아니에요.',
  dayPillar: ilju.ganji,
  dominantThemes: sipseong.dominant,
});

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
