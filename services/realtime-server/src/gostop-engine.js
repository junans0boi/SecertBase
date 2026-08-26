// ──────────────────────────────────────────────────────────────
// 화투 고스톱(2인 맞고) 엔진
// Rules: 기본 + 고배수 + 피박/광박 + 흔들기/폭탄 + 쪽/뻑/따닥/판쓸이
//        + 고박 + 총통 + 비광 반쪽 광 + 나가리(×2/×4) 이월
// ──────────────────────────────────────────────────────────────

// ── 카드 정의 ──────────────────────────────────────────────────

const T = { BRIGHT: 'bright', ANIMAL: 'animal', RIBBON: 'ribbon', JUNK: 'junk' };
const SUB = { RAIN: 'rain', DOUBLE: 'double', RED: 'red', BLUE: 'blue' };

// 48장: { id, month, type, subtype }
// subtype: 'rain'=비광, 'double'=쌍피, 'red'=홍단, 'blue'=청단, null=plain
const DECK_DEF = [
  // 1월 (소나무)
  { id: 'm1_bright',   month: 1,  type: T.BRIGHT, subtype: null },
  // 기존 ID는 클라이언트/진행 중 게임 호환용으로 유지. 실제 패는 홍단 띠다.
  { id: 'm1_animal',   month: 1,  type: T.RIBBON, subtype: SUB.RED },
  { id: 'm1_junk_1',   month: 1,  type: T.JUNK,   subtype: null },
  { id: 'm1_junk_2',   month: 1,  type: T.JUNK,   subtype: null },
  // 2월 (매화)
  { id: 'm2_animal',   month: 2,  type: T.ANIMAL, subtype: null },
  { id: 'm2_ribbon',   month: 2,  type: T.RIBBON, subtype: SUB.RED },
  { id: 'm2_junk_1',   month: 2,  type: T.JUNK,   subtype: null },
  { id: 'm2_junk_2',   month: 2,  type: T.JUNK,   subtype: null },
  // 3월 (벚꽃)
  { id: 'm3_bright',   month: 3,  type: T.BRIGHT, subtype: null },
  { id: 'm3_ribbon',   month: 3,  type: T.RIBBON, subtype: SUB.RED },
  { id: 'm3_junk_1',   month: 3,  type: T.JUNK,   subtype: null },
  { id: 'm3_junk_2',   month: 3,  type: T.JUNK,   subtype: null },
  // 4월 (등나무)
  { id: 'm4_animal',   month: 4,  type: T.ANIMAL, subtype: null },
  { id: 'm4_ribbon',   month: 4,  type: T.RIBBON, subtype: null },
  { id: 'm4_junk_1',   month: 4,  type: T.JUNK,   subtype: null },
  { id: 'm4_junk_2',   month: 4,  type: T.JUNK,   subtype: null },
  // 5월 (창포)
  { id: 'm5_animal',   month: 5,  type: T.ANIMAL, subtype: null },
  { id: 'm5_ribbon',   month: 5,  type: T.RIBBON, subtype: null },
  { id: 'm5_junk_1',   month: 5,  type: T.JUNK,   subtype: null },
  { id: 'm5_junk_2',   month: 5,  type: T.JUNK,   subtype: null },
  // 6월 (모란)
  { id: 'm6_animal',   month: 6,  type: T.ANIMAL, subtype: null },
  { id: 'm6_ribbon',   month: 6,  type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm6_junk_1',   month: 6,  type: T.JUNK,   subtype: null },
  { id: 'm6_junk_2',   month: 6,  type: T.JUNK,   subtype: null },
  // 7월 (싸리)
  { id: 'm7_animal_1', month: 7,  type: T.ANIMAL, subtype: null },
  // 기존 ID는 호환용으로 유지. 실제 패는 초단 띠다.
  { id: 'm7_animal_2', month: 7,  type: T.RIBBON, subtype: null },
  { id: 'm7_junk_1',   month: 7,  type: T.JUNK,   subtype: null },
  { id: 'm7_junk_2',   month: 7,  type: T.JUNK,   subtype: null },
  // 8월 (억새)
  { id: 'm8_bright',   month: 8,  type: T.BRIGHT, subtype: null },
  { id: 'm8_animal',   month: 8,  type: T.ANIMAL, subtype: null },
  { id: 'm8_junk_1',   month: 8,  type: T.JUNK,   subtype: null },
  { id: 'm8_junk_2',   month: 8,  type: T.JUNK,   subtype: null },
  // 9월 (국화)
  { id: 'm9_animal',   month: 9,  type: T.ANIMAL, subtype: null },
  { id: 'm9_ribbon',   month: 9,  type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm9_junk_1',   month: 9,  type: T.JUNK,   subtype: null },
  { id: 'm9_junk_2',   month: 9,  type: T.JUNK,   subtype: null },
  // 10월 (단풍)
  { id: 'm10_animal',  month: 10, type: T.ANIMAL, subtype: null },
  { id: 'm10_ribbon',  month: 10, type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm10_junk_1',  month: 10, type: T.JUNK,   subtype: null },
  { id: 'm10_junk_2',  month: 10, type: T.JUNK,   subtype: null },
  // 11월 (오동)
  { id: 'm11_bright',  month: 11, type: T.BRIGHT, subtype: null },
  { id: 'm11_junk_1',  month: 11, type: T.JUNK,   subtype: null },
  { id: 'm11_junk_2',  month: 11, type: T.JUNK,   subtype: null },
  { id: 'm11_junk_d',  month: 11, type: T.JUNK,   subtype: SUB.DOUBLE },
  // 12월 (비/버들) — 비광(rain), 쌍피
  { id: 'm12_bright',  month: 12, type: T.BRIGHT, subtype: SUB.RAIN },
  { id: 'm12_animal',  month: 12, type: T.ANIMAL, subtype: null },
  { id: 'm12_ribbon',  month: 12, type: T.RIBBON, subtype: null },
  { id: 'm12_junk_d',  month: 12, type: T.JUNK,   subtype: SUB.DOUBLE },
];

const DECK_BY_ID = new Map(DECK_DEF.map(card => [card.id, card]));

function _normalizeCard(card) {
  const canonical = DECK_BY_ID.get(card?.id);
  if (!canonical || (
    card.month === canonical.month &&
    card.type === canonical.type &&
    card.subtype === canonical.subtype
  )) {
    return card;
  }
  return { ...card, ...canonical };
}

// 배포 전 Redis 상태에는 지금과 같은 ID에 과거 type/subtype이 남아 있을 수 있다.
// 모든 공개 진입점에서 정규화해 그림, 획득 그룹, 점수 계산을 같은 계약으로 맞춘다.
export function normalizeGostopGameState(state) {
  if (!state || typeof state !== 'object') return state;

  let cardMetadataChanged = false;
  const normalizeCard = card => {
    const normalized = _normalizeCard(card);
    if (normalized !== card) cardMetadataChanged = true;
    return normalized;
  };
  const normalizeGroups = groups => Object.fromEntries(
    Object.entries(groups ?? {}).map(([playerId, cards]) => [
      playerId,
      (cards ?? []).map(normalizeCard),
    ]),
  );
  const hands = normalizeGroups(state.hands);
  const captures = normalizeGroups(state.captures);
  const pending = state.pending
    ? {
        ...state.pending,
        card: normalizeCard(state.pending.card),
        fieldOptions: (state.pending.fieldOptions ?? []).map(normalizeCard),
      }
    : null;
  const scores = Object.fromEntries(
    (state.players ?? []).map(playerId => {
      const derived = calculateScore(captures[playerId] ?? []);
      const existing = state.scores?.[playerId];
      if (!existing || cardMetadataChanged ||
          (existing.godoriScore == null && derived.godoriScore > 0)) {
        return [playerId, derived];
      }
      // Scores are persisted derived data. Backfill fields introduced after
      // an older Redis snapshot without discarding an in-flight test/manual
      // state whose explicit total is still authoritative.
      return [playerId, { ...existing, godoriScore: existing.godoriScore ?? 0 }];
    }),
  );

  return {
    ...state,
    deck: (state.deck ?? []).map(normalizeCard),
    field: (state.field ?? []).map(normalizeCard),
    hands,
    captures,
    pending,
    scores,
    shakeMultiplier: state.shakeMultiplier ?? 1,
    bombMultiplier: state.bombMultiplier ?? 1,
    shakers: state.shakers ?? [],
    shakeQueue: state.shakeQueue ?? [],
    shakePlayerId: state.shakePlayerId ?? null,
    firstPlayerIdx: state.firstPlayerIdx ?? state.currentPlayerIdx ?? 0,
  };
}

function _shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function createHwatuDeck() {
  return _shuffle([...DECK_DEF]);
}

// ── 피 점수 계산 헬퍼 ────────────────────────────────────────────
function _piValue(card) {
  return card.subtype === SUB.DOUBLE ? 2 : 1;
}

// ── 점수 계산 ────────────────────────────────────────────────────
// 홍단: 1,2,3월 단 / 청단: 6,9,10월 단
const HONGDAN_MONTHS = new Set([1, 2, 3]);
const CHEONGDAN_MONTHS = new Set([6, 9, 10]);
const GODORI_MONTHS = new Set([2, 4, 8]);
const CHONGTONG_POINTS = 5;

export function calculateScore(captures) {
  const brights = captures.filter(c => c.type === T.BRIGHT);
  const animals = captures.filter(c => c.type === T.ANIMAL);
  const ribbons = captures.filter(c => c.type === T.RIBBON);
  const junks   = captures.filter(c => c.type === T.JUNK);

  // 광 계산
  const gwangCount = brights.length;
  const hasRain = brights.some(c => c.subtype === SUB.RAIN);
  let gwangScore = 0;
  if (gwangCount >= 3) {
    const base = gwangCount === 3 ? 3 : gwangCount === 4 ? 4 : 15;
    gwangScore = hasRain ? base - 1 : base;
  }

  // 열끗
  const animCount = animals.length;
  const animScore = animCount >= 5 ? animCount - 4 : 0;
  const hasGodori = [...GODORI_MONTHS].every(month =>
    animals.some(card => card.month === month));
  const godoriScore = hasGodori ? 5 : 0;

  // 단
  const ribCount = ribbons.length;
  const ribScore = ribCount >= 5 ? ribCount - 4 : 0;
  const hongdanBonus = HONGDAN_MONTHS.size === [...HONGDAN_MONTHS].filter(m =>
    ribbons.some(r => r.month === m && r.subtype === SUB.RED)).length ? 3 : 0;
  const cheongdanBonus = CHEONGDAN_MONTHS.size === [...CHEONGDAN_MONTHS].filter(m =>
    ribbons.some(r => r.month === m && r.subtype === SUB.BLUE)).length ? 3 : 0;

  // 피
  const piTotal = junks.reduce((s, c) => s + _piValue(c), 0);
  const piScore = piTotal >= 10 ? piTotal - 9 : 0;

  const total = gwangScore + animScore + godoriScore + ribScore + hongdanBonus + cheongdanBonus + piScore;
  return {
    total,
    gwangScore,
    gwangCount,
    hasRain,
    animScore,
    animCount,
    godoriScore,
    ribScore,
    ribCount,
    hongdanBonus,
    cheongdanBonus,
    piScore,
    piTotal,
  };
}

// ── 게임 생성 ────────────────────────────────────────────────────
// 2인: 각 10장, 바닥 8장, 덱 나머지 20장
export function createGostopGameState(p1Id, p2Id, opts = {}) {
  const deck = opts.deck ? [...opts.deck] : createHwatuDeck();
  const h1 = [], h2 = [], field = [];

  // 2장씩 교대로 10장 배분, 그 다음 바닥 8장
  for (let i = 0; i < 5; i++) {
    h1.push(deck.pop(), deck.pop());
    h2.push(deck.pop(), deck.pop());
    if (i < 2) { field.push(deck.pop(), deck.pop(), deck.pop(), deck.pop()); }
  }
  // 나머지 2장 바닥
  if (field.length < 8) {
    while (field.length < 8 && deck.length > 0) field.push(deck.pop());
  }

  const hands = { [p1Id]: h1, [p2Id]: h2 };
  const captures = { [p1Id]: [], [p2Id]: [] };
  const goCount = { [p1Id]: 0, [p2Id]: 0 };

  // 흔들기 감지: 같은 월 3장 이상이면 해당 플레이어가 선언할 수 있다.
  // 시작 시 자동으로 배수를 올리면 UI에서 선언할 기회가 사라지고,
  // 재접속 시에도 동일한 규칙을 재현할 수 없으므로 큐에 보관한다.
  const shakeQueue = [];
  for (const [uid, hand] of [[p1Id, h1], [p2Id, h2]]) {
    const monthCounts = {};
    for (const c of hand) monthCounts[c.month] = (monthCounts[c.month] ?? 0) + 1;
    if (Object.values(monthCounts).some(n => n >= 3)) shakeQueue.push(uid);
  }

  // 총통 감지: 같은 월 4장 모두 같은 손에 → 즉시 승리 선언 가능 (phase: 'chongtong')
  let chongtong = null;
  for (const [uid, hand] of [[p1Id, h1], [p2Id, h2]]) {
    const monthCounts = {};
    for (const c of hand) monthCounts[c.month] = (monthCounts[c.month] ?? 0) + 1;
    const m = Object.entries(monthCounts).find(([, n]) => n >= 4);
    if (m) { chongtong = uid; break; }
  }

  // 선 결정: opts.firstPlayer 없으면 랜덤
  const firstPlayerIdx = opts.firstPlayerIdx ?? Math.floor(Math.random() * 2);

  const state = {
    phase: chongtong ? 'chongtong' : shakeQueue.length > 0 ? 'shake_choice' : 'playing',
    players: [p1Id, p2Id],
    currentPlayerIdx: firstPlayerIdx,
    firstPlayerIdx,
    deck,
    field,
    hands,
    captures,
    goCount,
    baseMultiplier: opts.baseMultiplier ?? 1,  // 나가리 이월 배수
    shakeMultiplier: 1,
    bombMultiplier: 1,
    shakers: [],
    shakeQueue,
    shakePlayerId: shakeQueue[0] ?? null,
    chongtong,
    lastEvents: [],      // 이번 턴 이벤트 (쪽/뻑/따닥/판쓸이 등)
    pending: null,       // { type, card, fieldOptions }
    scores: {
      [p1Id]: calculateScore([]),
      [p2Id]: calculateScore([]),
    },
    winner: null,
    loser: null,
    settlement: null,
    turn: 1,
    perPointBet: opts.perPointBet ?? 100,  // 점당 베팅액
    gameId: opts.gameId ?? null,
  };

  // 총통이면 즉시 승리
  if (chongtong) {
    return _settleWin(state, chongtong, ['chongtong']);
  }

  return state;
}

// ── 내부: 필드에서 같은 월 카드 목록 ──────────────────────────────
function _fieldByMonth(field, month) {
  return field.filter(c => c.month === month);
}

// ── 내부: 카드 포획 ─────────────────────────────────────────────
function _capture(state, playerId, cards) {
  return {
    ...state,
    captures: {
      ...state.captures,
      [playerId]: [...state.captures[playerId], ...cards],
    },
    field: state.field.filter(c => !cards.some(cap => cap.id === c.id)),
  };
}

// ── 내부: 덱 플립 처리 ──────────────────────────────────────────
// 손패를 먼저 바닥에 올려 둔 뒤 덱을 뒤집는다. 그래야 빈 바닥에서
// 같은 월을 뒤집는 쪽, 한 장을 맞춘 뒤 같은 월을 뒤집는 뻑을
// 서로 구분할 수 있다.
function _resolveDeckFlip(state, playerId, context = {}) {
  const {
    playedCard = null,
    initialMatches = [],
  } = context;

  if (state.deck.length === 0) {
    let st = state;
    const events = [...st.lastEvents];
    if (initialMatches.length === 1 && playedCard) {
      st = _capture(st, playerId, [playedCard, ...initialMatches]);
      if (st.field.length === 0) events.push('pansseuri');
    }
    return _afterDeckResolved(st, playerId, events);
  }

  const deckCard = state.deck[state.deck.length - 1];
  const newDeck = state.deck.slice(0, -1);
  let st = { ...state, deck: newDeck };
  const events = [...st.lastEvents];

  // 한 장을 맞춘 뒤 같은 월을 뒤집으면 세 장 모두 바닥에 남긴다.
  if (initialMatches.length === 1 && playedCard && deckCard.month === playedCard.month) {
    events.push('ppeok');
    st = { ...st, field: [...st.field, deckCard] };
    return _afterDeckResolved(st, playerId, events);
  }

  // 빈 바닥에 낸 카드와 덱 카드가 같은 월이면 둘만 포획한다(쪽).
  if (initialMatches.length === 0 && playedCard && deckCard.month === playedCard.month) {
    st = _capture(st, playerId, [playedCard, deckCard]);
    events.push('ssok');
    if (st.field.length === 0) events.push('pansseuri');
    return _afterDeckResolved(st, playerId, events);
  }

  // 한 장 매칭은 위의 뻑이 아닌 경우에만 손패 카드와 함께 포획한다.
  if (initialMatches.length === 1 && playedCard) {
    st = _capture(st, playerId, [playedCard, ...initialMatches]);
    if (st.field.length === 0) events.push('pansseuri');
  }

  const matches = _fieldByMonth(st.field, deckCard.month);

  if (matches.length === 0) {
    st = { ...st, field: [...st.field, deckCard] };
  } else if (matches.length === 1) {
    st = _capture(st, playerId, [deckCard, matches[0]]);
    if (st.field.length === 0) events.push('pansseuri');
  } else if (matches.length === 2) {
    events.push('ddadak_pending');
    st = {
      ...st,
      lastEvents: events,
      pending: { type: 'deck_choice', card: deckCard, fieldOptions: matches },
    };
    return { ...st, phase: 'deck_choice' };
  } else {
    st = _capture(st, playerId, [deckCard, ...matches]);
    if (st.field.length === 0) events.push('pansseuri');
  }

  return _afterDeckResolved(st, playerId, events);
}

// ── 내부: 덱 처리 후 공통 ────────────────────────────────────────
function _allHandsEmpty(state) {
  return state.players.every(playerId => (state.hands[playerId] ?? []).length === 0);
}

function _finishWhenHandsExhausted(state, scores, events) {
  const [firstId, secondId] = state.players;
  const firstScore = scores[firstId]?.total ?? 0;
  const secondScore = scores[secondId]?.total ?? 0;
  const hasWinningScore = Math.max(firstScore, secondScore) >= 7;

  if (!hasWinningScore || firstScore === secondScore) {
    return _checkNageori({ ...state, scores });
  }

  const winnerId = firstScore > secondScore ? firstId : secondId;
  return _settleWin(
    { ...state, scores },
    winnerId,
    [...events, 'hand_exhausted'],
  );
}

// Redis에 남아 있는 구버전 상태도 조회 시 종료 상태로 승격한다.
// 배포 전에 이미 양쪽 손패가 비어 버린 게임을 복구하기 위한 공개 seam이다.
export function resolveGostopTerminalState(state) {
  state = normalizeGostopGameState(state);
  if (state.phase !== 'playing' || !_allHandsEmpty(state)) return state;

  const scores = Object.fromEntries(
    state.players.map(playerId => [
      playerId,
      calculateScore(state.captures[playerId] ?? []),
    ]),
  );
  return _finishWhenHandsExhausted(state, scores, state.lastEvents ?? []);
}

function _afterDeckResolved(state, playerId, events) {
  const scores = {
    ...state.scores,
    [playerId]: calculateScore(state.captures[playerId]),
  };
  const st = { ...state, scores, lastEvents: events };

  // 폭탄이나 정상적인 마지막 턴으로 양쪽 손패가 먼저 소진될 수 있다.
  // 덱이 남아 있어도 더 이상 낼 카드가 없으므로 즉시 점수를 비교한다.
  if (_allHandsEmpty(st)) {
    return _finishWhenHandsExhausted(st, scores, events);
  }

  // 덱 소진 체크
  if (st.deck.length === 0 && scores[playerId].total < 7) {
    const otherId = st.players.find(p => p !== playerId);
    if (scores[otherId].total < 7) return _checkNageori(st);
  }

  // 7점 이상이면 고/스톱 선택
  if (scores[playerId].total >= 7) {
    return { ...st, phase: 'go_stop_choice' };
  }

  return _nextTurn(st);
}

// ── 내부: 나가리 체크 ────────────────────────────────────────────
function _checkNageori(state) {
  return {
    ...state,
    phase: 'nageori',
    baseMultiplier: Math.min(state.baseMultiplier * 2, 4),
  };
}

// ── 내부: 다음 턴 ────────────────────────────────────────────────
function _nextTurn(state) {
  const nextIdx = state.currentPlayerIdx === 0 ? 1 : 0;
  return {
    ...state,
    phase: 'playing',
    currentPlayerIdx: nextIdx,
    pending: null,
    lastEvents: [],
    turn: state.turn + 1,
  };
}

// ── 손패 카드 내기 ───────────────────────────────────────────────
export function playHandCard(state, playerId, cardId) {
  state = normalizeGostopGameState(state);
  if (state.phase !== 'playing') throw new Error(`invalid phase: ${state.phase}`);
  const curId = state.players[state.currentPlayerIdx];
  if (playerId !== curId) throw new Error('not your turn');

  const hand = state.hands[playerId];
  const card = hand.find(c => c.id === cardId);
  if (!card) throw new Error('card not in hand');

  const newHand = hand.filter(c => c.id !== cardId);
  const initialMatches = _fieldByMonth(state.field, card.month);
  const events = [];
  let st = {
    ...state,
    hands: { ...state.hands, [playerId]: newHand },
    field: [...state.field, card],
    lastEvents: events,
  };

  // 두 장 이상은 손패 카드와 함께 즉시 포획한다. 한 장 이하는
  // 덱 결과까지 본 뒤 쪽/뻑을 판정해야 하므로 바닥에 잠시 남긴다.
  if (initialMatches.length >= 2) {
    if (initialMatches.length === 2) events.push('ddadak');
    st = _capture(st, playerId, [card, ...initialMatches]);
    if (st.field.length === 0) events.push('pansseuri');
    return _resolveDeckFlip({ ...st, lastEvents: events }, playerId);
  }

  return _resolveDeckFlip(st, playerId, { playedCard: card, initialMatches });
}

// ── 흔들기 선언 ──────────────────────────────────────────────────
export function declareShake(state, playerId, decision) {
  state = normalizeGostopGameState(state);
  if (state.phase !== 'shake_choice') throw new Error('not in shake_choice phase');
  if (state.shakePlayerId !== playerId) throw new Error('not shake owner');
  if (decision !== 'shake' && decision !== 'pass') throw new Error('invalid shake decision');

  const queue = state.shakeQueue.filter(id => id !== playerId);
  const shaken = decision === 'shake'
    ? [...state.shakers, playerId]
    : state.shakers;
  const nextMultiplier = decision === 'shake'
    ? state.shakeMultiplier * 2
    : state.shakeMultiplier;
  const nextPlayerId = queue[0] ?? null;
  const events = decision === 'shake' ? [...state.lastEvents, 'shake'] : state.lastEvents;

  if (nextPlayerId) {
    return {
      ...state,
      shakeQueue: queue,
      shakePlayerId: nextPlayerId,
      shakers: shaken,
      shakeMultiplier: nextMultiplier,
      lastEvents: events,
    };
  }

  return {
    ...state,
    phase: 'playing',
    shakeQueue: [],
    shakePlayerId: null,
    shakers: shaken,
    shakeMultiplier: nextMultiplier,
    lastEvents: events,
  };
}

// ── 폭탄 ─────────────────────────────────────────────────────────
// 세 장의 같은 월 손패와 바닥의 한 장을 한 번에 포획한다.
// 폭탄 선언 후에는 일반 덱 플립을 한 번 더 진행한다.
export function playBomb(state, playerId, month) {
  state = normalizeGostopGameState(state);
  if (state.phase !== 'playing') throw new Error(`invalid phase: ${state.phase}`);
  if (state.players[state.currentPlayerIdx] !== playerId) throw new Error('not your turn');
  if (!Number.isInteger(month) || month < 1 || month > 12) throw new Error('invalid bomb month');

  const handCards = (state.hands[playerId] ?? []).filter(card => card.month === month);
  const fieldCards = _fieldByMonth(state.field, month);
  if (handCards.length < 3) throw new Error('bomb requires three hand cards');
  if (fieldCards.length !== 1) throw new Error('bomb requires one field card');

  const handIds = new Set(handCards.slice(0, 3).map(card => card.id));
  const hand = state.hands[playerId].filter(card => !handIds.has(card.id));
  let st = {
    ...state,
    hands: { ...state.hands, [playerId]: hand },
    lastEvents: [...state.lastEvents, 'bomb'],
    bombMultiplier: state.bombMultiplier * 2,
  };
  st = _capture(st, playerId, [...handCards.slice(0, 3), fieldCards[0]]);
  if (st.field.length === 0) st.lastEvents = [...st.lastEvents, 'pansseuri'];
  return _resolveDeckFlip(st, playerId);
}

// ── 덱 포획 선택 (deck_choice 단계) ────────────────────────────
export function selectDeckCapture(state, playerId, fieldCardId) {
  state = normalizeGostopGameState(state);
  if (state.phase !== 'deck_choice') throw new Error('not in deck_choice phase');
  const curId = state.players[state.currentPlayerIdx];
  if (playerId !== curId) throw new Error('not your turn');

  const { card, fieldOptions } = state.pending;
  const chosen = fieldOptions.find(c => c.id === fieldCardId);
  if (!chosen) throw new Error('invalid field card choice');

  const events = [...state.lastEvents.filter(e => e !== 'ddadak_pending')];
  events.push('ddadak');

  // 선택한 필드 카드 1개만 포획 (나머지 남음)
  let st = _capture(state, playerId, [card, chosen]);
  if (st.field.length === 0) events.push('pansseuri');

  return _afterDeckResolved({ ...st, pending: null }, playerId, events);
}

// ── 고/스톱 선언 ────────────────────────────────────────────────
export function declareGoStop(state, playerId, decision) {
  state = normalizeGostopGameState(state);
  if (state.phase !== 'go_stop_choice') throw new Error('not in go_stop_choice phase');
  const curId = state.players[state.currentPlayerIdx];
  if (playerId !== curId) throw new Error('not your turn');
  if (decision !== 'go' && decision !== 'stop') throw new Error('invalid go/stop decision');

  if (decision === 'stop') {
    return _settleWin(state, playerId, []);
  }

  // GO 선언
  const goCount = { ...state.goCount, [playerId]: state.goCount[playerId] + 1 };
  return _nextTurn({ ...state, goCount, phase: 'playing' });
}

// ── 정산 ─────────────────────────────────────────────────────────
function _settleWin(state, winnerId, reasonEvents) {
  const loserId = state.players.find(p => p !== winnerId);
  const winnerScore = state.scores[winnerId] ?? calculateScore(state.captures[winnerId] ?? []);
  const loserScore  = state.scores[loserId]  ?? calculateScore(state.captures[loserId]  ?? []);

  let multiplier = state.baseMultiplier * state.shakeMultiplier * state.bombMultiplier;

  // 고 횟수 배수: GO 1회=×2, 2회=×4
  const goN = state.goCount[winnerId];
  if (goN > 0) multiplier *= Math.pow(2, goN);

  // 고박: 진 사람도 GO 선언한 경우 ×2
  const loserGoN = state.goCount[loserId];
  if (loserGoN > 0) multiplier *= 2;

  // 피박: 이긴 사람 피 합계 ≥10, 진 사람 피 합계 <5
  const winnerPi = winnerScore.piTotal;
  const loserPi  = loserScore.piTotal;
  const pibak = winnerPi >= 10 && loserPi < 5;
  if (pibak) multiplier *= 2;

  // 광박: 승자가 광 3장 이상이고 진 사람이 광을 하나도 못 모은 경우
  const loserGwang = loserScore.gwangCount;
  const gwangbak = loserGwang === 0 && winnerScore.gwangCount >= 3;
  if (gwangbak) multiplier *= 2;

  // 베팅액: 점수 × 점당 × 배수
  const points = reasonEvents.includes('chongtong') ? CHONGTONG_POINTS : winnerScore.total;
  const amount = points * state.perPointBet * multiplier;

  const settlement = {
    winnerId,
    loserId,
    points,
    multiplier,
    perPointBet: state.perPointBet,
    amount,
    pibak,
    gwangbak,
    godori: winnerScore.godoriScore > 0,
    bombMultiplier: state.bombMultiplier,
    chongtong: reasonEvents.includes('chongtong'),
    goBonusWinner: goN,
    goBonusLoser: loserGoN,
    winnerScore,
    loserScore,
    reasonEvents,
  };

  return {
    ...state,
    phase: 'finished',
    winner: winnerId,
    loser: loserId,
    settlement,
    lastEvents: reasonEvents,
  };
}

// ── 기타 유틸 ────────────────────────────────────────────────────

// 현재 플레이어 Id
export function currentPlayer(state) {
  return state.players[state.currentPlayerIdx];
}

// 유효한 손패 카드 목록 (손패에서 낼 수 있는 카드 = 전부)
export function validHandCards(state, playerId) {
  return state.hands[playerId] ?? [];
}

// 상태 직렬화 (소켓 전송용 — 상대 손패 숨김)
export function serializeFor(state, viewerId) {
  state = normalizeGostopGameState(state);
  const hidden = state.players.find(p => p !== viewerId);
  const { shakeQueue: _privateShakeQueue, ...publicState } = state;
  return {
    ...publicState,
    deck: publicState.deck.map(() => ({ id: 'back' })),
    hands: {
      [viewerId]: publicState.hands[viewerId],
      [hidden]: publicState.hands[hidden].map(() => ({ id: 'back' })),
    },
    shakePlayerId: state.shakePlayerId === viewerId ? viewerId : null,
  };
}

export function serializeGostopGame(state) {
  state = normalizeGostopGameState(state);
  return { ...state, deck: state.deck.map(() => ({ id: 'back' })) };
}
