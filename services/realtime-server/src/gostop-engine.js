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
  { id: 'm1_animal',   month: 1,  type: T.ANIMAL, subtype: null },
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
  { id: 'm4_ribbon',   month: 4,  type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm4_junk_1',   month: 4,  type: T.JUNK,   subtype: null },
  { id: 'm4_junk_2',   month: 4,  type: T.JUNK,   subtype: null },
  // 5월 (창포)
  { id: 'm5_animal',   month: 5,  type: T.ANIMAL, subtype: null },
  { id: 'm5_ribbon',   month: 5,  type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm5_junk_1',   month: 5,  type: T.JUNK,   subtype: null },
  { id: 'm5_junk_2',   month: 5,  type: T.JUNK,   subtype: null },
  // 6월 (모란)
  { id: 'm6_animal',   month: 6,  type: T.ANIMAL, subtype: null },
  { id: 'm6_ribbon',   month: 6,  type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm6_junk_1',   month: 6,  type: T.JUNK,   subtype: null },
  { id: 'm6_junk_2',   month: 6,  type: T.JUNK,   subtype: null },
  // 7월 (싸리)
  { id: 'm7_animal_1', month: 7,  type: T.ANIMAL, subtype: null },
  { id: 'm7_animal_2', month: 7,  type: T.ANIMAL, subtype: null },
  { id: 'm7_junk_1',   month: 7,  type: T.JUNK,   subtype: null },
  { id: 'm7_junk_2',   month: 7,  type: T.JUNK,   subtype: null },
  // 8월 (억새)
  { id: 'm8_bright',   month: 8,  type: T.BRIGHT, subtype: null },
  { id: 'm8_animal',   month: 8,  type: T.ANIMAL, subtype: null },
  { id: 'm8_junk_1',   month: 8,  type: T.JUNK,   subtype: null },
  { id: 'm8_junk_2',   month: 8,  type: T.JUNK,   subtype: null },
  // 9월 (국화)
  { id: 'm9_animal',   month: 9,  type: T.ANIMAL, subtype: null },
  { id: 'm9_ribbon',   month: 9,  type: T.RIBBON, subtype: null },
  { id: 'm9_junk_1',   month: 9,  type: T.JUNK,   subtype: null },
  { id: 'm9_junk_2',   month: 9,  type: T.JUNK,   subtype: null },
  // 10월 (단풍)
  { id: 'm10_animal',  month: 10, type: T.ANIMAL, subtype: null },
  { id: 'm10_ribbon',  month: 10, type: T.RIBBON, subtype: SUB.RED },
  { id: 'm10_junk_1',  month: 10, type: T.JUNK,   subtype: null },
  { id: 'm10_junk_2',  month: 10, type: T.JUNK,   subtype: null },
  // 11월 (비/버들) — 비광(rain), 쌍피
  { id: 'm11_bright',  month: 11, type: T.BRIGHT, subtype: SUB.RAIN },
  { id: 'm11_animal',  month: 11, type: T.ANIMAL, subtype: null },
  { id: 'm11_ribbon',  month: 11, type: T.RIBBON, subtype: null },
  { id: 'm11_junk_d',  month: 11, type: T.JUNK,   subtype: SUB.DOUBLE },
  // 12월 (오동)
  { id: 'm12_bright',  month: 12, type: T.BRIGHT, subtype: null },
  { id: 'm12_junk_1',  month: 12, type: T.JUNK,   subtype: null },
  { id: 'm12_junk_2',  month: 12, type: T.JUNK,   subtype: null },
  { id: 'm12_junk_d',  month: 12, type: T.JUNK,   subtype: SUB.DOUBLE },
];

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
// 홍단: 2,3,10월 단 / 청단: 4,5,6월 단
const HONGDAN_MONTHS = new Set([2, 3, 10]);
const CHEONGDAN_MONTHS = new Set([4, 5, 6]);

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

  const total = gwangScore + animScore + ribScore + hongdanBonus + cheongdanBonus + piScore;
  return {
    total,
    gwangScore,
    gwangCount,
    hasRain,
    animScore,
    animCount,
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
  const deck = createHwatuDeck();
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

  // 흔들기 감지: 같은 월 2장 이상 → 자동 ×2
  let shakeMultiplier = 1;
  const shakers = [];
  for (const [uid, hand] of [[p1Id, h1], [p2Id, h2]]) {
    const monthCounts = {};
    for (const c of hand) monthCounts[c.month] = (monthCounts[c.month] ?? 0) + 1;
    if (Object.values(monthCounts).some(n => n >= 2)) {
      shakeMultiplier *= 2;
      shakers.push(uid);
    }
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
    phase: chongtong ? 'chongtong' : 'playing',
    players: [p1Id, p2Id],
    currentPlayerIdx: firstPlayerIdx,
    deck,
    field,
    hands,
    captures,
    goCount,
    baseMultiplier: opts.baseMultiplier ?? 1,  // 나가리 이월 배수
    shakeMultiplier,
    shakers,
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
function _resolveDeckFlip(state, playerId, lastCapturedMonth) {
  if (state.deck.length === 0) return _checkNageori(state);

  const deckCard = state.deck[state.deck.length - 1];
  const newDeck = state.deck.slice(0, -1);
  let st = { ...state, deck: newDeck };
  const events = [...st.lastEvents];

  const matches = _fieldByMonth(st.field, deckCard.month);

  if (matches.length === 0) {
    // 뻑: 이번 턴에 바닥에 놓은 패와 같은 월이면 뻑
    const isPpeok = deckCard.month === lastCapturedMonth &&
      st.field.some(c => c.month === deckCard.month);
    if (isPpeok) events.push('ppeok');
    // 덱 카드 바닥에 놓기
    st = { ...st, field: [...st.field, deckCard] };
  } else if (matches.length === 1) {
    // 자동 포획
    const captured = [deckCard, matches[0]];
    // 쪽: 직전 손패 포획 월과 같은 월이면 쪽
    if (deckCard.month === lastCapturedMonth && lastCapturedMonth !== null) {
      events.push('ssok');
    }
    st = _capture(st, playerId, captured);
    // 판쓸이
    if (st.field.length === 0) events.push('pansseuri');
  } else if (matches.length === 2) {
    // 따닥: 덱 카드가 쌍 중 하나를 선택해야 함
    events.push('ddadak_pending');
    st = {
      ...st,
      lastEvents: events,
      pending: { type: 'deck_choice', card: deckCard, fieldOptions: matches },
    };
    return { ...st, phase: 'deck_choice' };
  } else {
    // 3장 이상 (드묾) → 모두 포획
    st = _capture(st, playerId, [deckCard, ...matches]);
    if (st.field.length === 0) events.push('pansseuri');
  }

  return _afterDeckResolved(st, playerId, events);
}

// ── 내부: 덱 처리 후 공통 ────────────────────────────────────────
function _afterDeckResolved(state, playerId, events) {
  const scores = {
    ...state.scores,
    [playerId]: calculateScore(state.captures[playerId]),
  };
  const st = { ...state, scores, lastEvents: events };

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
  if (state.phase !== 'playing') throw new Error(`invalid phase: ${state.phase}`);
  const curId = state.players[state.currentPlayerIdx];
  if (playerId !== curId) throw new Error('not your turn');

  const hand = state.hands[playerId];
  const card = hand.find(c => c.id === cardId);
  if (!card) throw new Error('card not in hand');

  const newHand = hand.filter(c => c.id !== cardId);
  let st = { ...state, hands: { ...state.hands, [playerId]: newHand }, lastEvents: [] };

  const matches = _fieldByMonth(st.field, card.month);
  const events = [];

  if (matches.length === 0) {
    // 바닥에 놓기 (나중에 뻑 가능성)
    st = { ...st, field: [...st.field, card] };
    return _resolveDeckFlip(st, playerId, null);  // lastCapturedMonth = null, 뻑 감지용
  }

  if (matches.length === 1) {
    // 자동 포획 (손패+바닥 1장)
    st = _capture(st, playerId, [card, matches[0]]);
    if (st.field.length === 0) events.push('pansseuri');
    return _resolveDeckFlip(st, playerId, card.month);
  }

  if (matches.length === 2) {
    // 따닥: 손패 카드로 바닥 2장 모두 포획
    events.push('ddadak');
    st = _capture(st, playerId, [card, ...matches]);
    if (st.field.length === 0) events.push('pansseuri');
    return _resolveDeckFlip({ ...st, lastEvents: events }, playerId, card.month);
  }

  // 3장 이상 → 모두 포획
  st = _capture(st, playerId, [card, ...matches]);
  if (st.field.length === 0) events.push('pansseuri');
  return _resolveDeckFlip({ ...st, lastEvents: events }, playerId, card.month);
}

// ── 덱 포획 선택 (deck_choice 단계) ────────────────────────────
export function selectDeckCapture(state, playerId, fieldCardId) {
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
  if (state.phase !== 'go_stop_choice') throw new Error('not in go_stop_choice phase');
  const curId = state.players[state.currentPlayerIdx];
  if (playerId !== curId) throw new Error('not your turn');

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

  let multiplier = state.baseMultiplier * state.shakeMultiplier;

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

  // 광박: 진 사람 광 0장
  const loserGwang = loserScore.gwangCount;
  const gwangbak = loserGwang === 0 && winnerScore.gwangCount > 0;
  if (gwangbak) multiplier *= 2;

  // 베팅액: 점수 × 점당 × 배수
  const points = winnerScore.total;
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
  const hidden = state.players.find(p => p !== viewerId);
  return {
    ...state,
    deck: state.deck.map(() => ({ id: 'back' })),
    hands: {
      [viewerId]: state.hands[viewerId],
      [hidden]: state.hands[hidden].map(() => ({ id: 'back' })),
    },
  };
}

export function serializeGostopGame(state) {
  return { ...state, deck: state.deck.map(() => ({ id: 'back' })) };
}
