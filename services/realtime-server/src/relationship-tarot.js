export const TAROT_CATALOG_VERSION = 'tarot-major-v1';

const cardDefinitions = [
  ['the_fool', '바보', '새로운 시작 앞에서 가볍게 한 걸음 내디뎌봐요.'],
  ['the_magician', '마법사', '이미 가진 도구를 조합해 작은 가능성을 현실로 옮겨봐요.'],
  ['the_high_priestess', '여사제', '바깥의 답보다 조용히 올라오는 감각을 먼저 들어봐요.'],
  ['the_empress', '여제', '돌봄과 풍요를 서두르지 않고 충분히 누려봐요.'],
  ['the_emperor', '황제', '오늘 지키고 싶은 기준 하나를 부드럽게 세워봐요.'],
  ['the_hierophant', '교황', '믿을 만한 지혜와 경험에서 필요한 힌트를 찾아봐요.'],
  ['the_lovers', '연인', '중요한 선택 앞에서 내 마음과 상대의 마음을 함께 살펴봐요.'],
  ['the_chariot', '전차', '흔들려도 내가 정한 방향으로 한 걸음씩 움직여봐요.'],
  ['strength', '힘', '세게 밀어붙이기보다 다정한 용기로 마음을 다뤄봐요.'],
  ['the_hermit', '은둔자', '잠시 속도를 낮추고 나만의 답을 들을 시간을 마련해봐요.'],
  ['wheel_of_fortune', '운명의 수레바퀴', '변화하는 흐름 속에서 내가 선택할 수 있는 것을 찾아봐요.'],
  ['justice', '정의', '감정과 사실을 나누어 보고 나에게 공정한 선택을 해봐요.'],
  ['the_hanged_man', '매달린 사람', '익숙한 관점을 잠시 뒤집어 보면 다른 길이 보일 수 있어요.'],
  ['death', '죽음', '끝난 것을 정리하고 다음 장을 위한 자리를 비워봐요.'],
  ['temperance', '절제', '서로 다른 마음과 속도를 조금씩 섞어 균형을 찾아봐요.'],
  ['the_devil', '악마', '나를 붙잡는 습관이나 두려움을 판단 없이 바라봐요.'],
  ['the_tower', '탑', '갑작스러운 변화 속에서도 안전과 진짜 필요를 먼저 확인해봐요.'],
  ['the_star', '별', '작더라도 회복의 신호와 다시 기대할 이유를 찾아봐요.'],
  ['the_moon', '달', '분명하지 않은 감정은 결론 내리기보다 천천히 이름 붙여봐요.'],
  ['the_sun', '태양', '기쁨과 고마움을 숨기지 말고 따뜻하게 나눠봐요.'],
  ['judgement', '심판', '지나온 선택을 돌아보고 지금의 나에게 필요한 응답을 골라봐요.'],
  ['the_world', '세계', '한 사이클을 잘 지나온 나를 인정하고 다음 장을 맞이해봐요.'],
];

export const majorArcanaCatalog = cardDefinitions.map(([key, title, plain]) => ({
  key,
  title,
  orientation: 'upright',
  plain,
  reflection: '오늘 이 메시지가 내 마음과 만나는 지점을 한 문장으로 적어보세요.',
}));

export const tarotSelectionCatalog = majorArcanaCatalog.map((card, index) => ({
  key: card.key,
  position: index + 1,
}));

const disclaimer = '타로는 자기 성찰을 돕는 참고 콘텐츠이며 사실 예측이나 진단이 아니에요.';

export const undrawnTarot = ({ scope, date }) => ({
  scope,
  date,
  catalogVersion: TAROT_CATALOG_VERSION,
  drawn: false,
  drawRequired: true,
  cards: tarotSelectionCatalog.map((card) => ({ ...card })),
  redrawAvailable: false,
  disclaimer,
});

export const drawSelectedTarot = ({ scope, date, cardKey }) => {
  const card = majorArcanaCatalog.find((candidate) => candidate.key === cardKey);
  if (!card) {
    const error = new Error('invalid_tarot_card');
    error.code = 'invalid_tarot_card';
    error.status = 422;
    throw error;
  }
  return {
    scope,
    date,
    catalogVersion: TAROT_CATALOG_VERSION,
    drawn: true,
    drawRequired: false,
    selectedByUser: true,
    redrawAvailable: false,
    card: { ...card },
    disclaimer,
  };
};
