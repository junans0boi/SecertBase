import { createHash } from 'node:crypto';

export const FORTUNE_CONTENT_VERSION = 'v1';

const personalThemes = [
  {
    title: '천천히 이름 붙이는 날',
    summary: '오늘은 감정을 바로 해결하려 하기보다 지금 느끼는 것을 한 문장으로 적어보면 좋아요.',
    signal: '몸의 속도보다 생각의 속도가 빨라질 수 있어요.',
    suggestion: '대답하기 전, “나는 지금 무엇을 원하지?”를 한 번 물어보세요.',
  },
  {
    title: '작은 연결이 커지는 날',
    summary: '짧은 안부와 구체적인 고마움이 관계의 온도를 안정적으로 올려줘요.',
    signal: '혼자 정리한 뒤에야 말을 꺼내고 싶어질 수 있어요.',
    suggestion: '완벽한 설명 대신 지금 가능한 한 문장만 먼저 나눠보세요.',
  },
  {
    title: '경계를 부드럽게 세우는 날',
    summary: '나를 위한 시간과 상대를 위한 시간을 함께 확보하면 마음의 여백이 생겨요.',
    signal: '거리 조절을 사랑의 크기로 해석하기 쉬운 흐름이에요.',
    suggestion: '필요한 시간을 말할 때 돌아올 시점도 함께 약속해보세요.',
  },
  {
    title: '표현이 선명해지는 날',
    summary: '막연한 서운함을 구체적인 부탁으로 바꾸면 서로의 의도가 더 잘 보여요.',
    signal: '상대가 알아서 알아주기를 기대하고 싶어질 수 있어요.',
    suggestion: '“왜 그래?” 대신 “나는 이런 방식이면 안심돼”로 말해보세요.',
  },
];

const relationshipThemes = [
  {
    title: '서로의 리듬을 번역하는 날',
    summary: '같은 행동도 두 사람에게 다른 의미일 수 있어요. 의미를 확인하는 대화가 도움이 됩니다.',
    suggestion: '오늘 서로에게 필요한 관심의 모양을 하나씩 말해보세요.',
  },
  {
    title: '붙어 있음과 자율성의 균형',
    summary: '함께 있는 시간과 각자의 시간을 모두 관계의 일부로 인정하면 긴장이 줄어들어요.',
    suggestion: '각자의 시간을 정한 뒤 다시 만날 약속을 함께 잡아보세요.',
  },
  {
    title: '작은 회복을 쌓는 날',
    summary: '큰 결론보다 짧은 확인과 작은 사과가 두 사람의 안전감을 회복시킬 수 있어요.',
    suggestion: '오늘 고마웠던 행동과 다시 부탁하고 싶은 행동을 하나씩 나눠보세요.',
  },
];

const emotionalThemes = [
  '감정을 안으로만 처리하지 말고 안전한 사람에게 작은 단서부터 나눠보세요.',
  '자극을 더하기 전에 현재 감정의 이름과 강도를 먼저 확인해보세요.',
  '해결책보다 회복에 필요한 시간과 환경을 먼저 마련해보세요.',
];

const normalizedDate = (value) => String(value ?? '').slice(0, 10);

const hashIndex = (seed, length) => {
  const digest = createHash('sha256').update(seed).digest();
  return digest.readUInt32BE(0) % length;
};

const profileKey = (profile) => [
  profile?.calendarType ?? 'solar',
  normalizedDate(profile?.birthDate),
  profile?.birthTime ?? 'unknown-time',
  profile?.timezone ?? 'Asia/Seoul',
  profile?.birthPlace ?? 'unknown-place',
].join('|');

const disclaimer = '사주·운세 형식의 자기성찰 콘텐츠이며 사실 예측이나 의료적 진단을 의미하지 않아요.';

export const buildPersonalFortune = ({ profile, date }) => {
  const day = normalizedDate(date);
  const theme = personalThemes[hashIndex(`${profileKey(profile)}|${day}|personal`, personalThemes.length)];
  return {
    fortuneType: 'personal',
    contentVersion: FORTUNE_CONTENT_VERSION,
    date: day,
    title: theme.title,
    summary: theme.summary,
    signals: [theme.signal],
    suggestion: theme.suggestion,
    birthTimeKnown: Boolean(profile?.birthTime),
    birthPlaceKnown: Boolean(profile?.birthPlace),
    disclaimer,
  };
};

export const buildEmotionalFlow = ({ profile, date }) => {
  const day = normalizedDate(date);
  const theme = personalThemes[hashIndex(`${profileKey(profile)}|${day}|flow`, personalThemes.length)];
  return {
    fortuneType: 'emotional_flow',
    contentVersion: FORTUNE_CONTENT_VERSION,
    date: day,
    title: '오늘의 감정 흐름',
    summary: emotionalThemes[hashIndex(`${profileKey(profile)}|${day}|flow-text`, emotionalThemes.length)],
    signals: [theme.signal],
    suggestion: '감정이 올라오면 사실, 해석, 부탁을 나누어 적어보세요.',
    disclaimer,
  };
};

export const buildRelationshipFortune = ({ firstProfile, secondProfile, date }) => {
  const day = normalizedDate(date);
  const seed = `${profileKey(firstProfile)}|${profileKey(secondProfile)}|${day}|relationship`;
  const theme = relationshipThemes[hashIndex(seed, relationshipThemes.length)];
  return {
    fortuneType: 'relationship',
    contentVersion: FORTUNE_CONTENT_VERSION,
    date: day,
    title: theme.title,
    summary: theme.summary,
    signals: [
      '두 사람의 차이는 우열보다 서로 다른 필요의 신호로 살펴보세요.',
    ],
    suggestion: theme.suggestion,
    disclaimer,
  };
};
