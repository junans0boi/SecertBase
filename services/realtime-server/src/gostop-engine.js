// ──────────────────────────────────────────────────────────────
// 화투 고스톱(2인 맞고) 엔진 2.0 — 순수 함수, random 주입.
// 규칙 기준: docs/plans/game-renewal-2026-11-wave2/01-grilling.md Q25 (도움말에도 같은 내용).
//
//  - 7점 이상 나면 고/스톱. 고 점수: 1고 +1, 2고 +2, 3고 +3 ×2, 이후 고마다 +1점·×2.
//  - 박: 피박(이긴 쪽이 피로 점수 + 진 쪽 피 7장 이하), 광박(이긴 쪽이 광으로 점수 + 진 쪽 광 0장),
//    고박(고를 외친 사람이 지면 ×2).
//  - 흔들기·폭탄: 선언한 사람이 이길 때만 각각 ×2. 흔들기는 그 월 패를 낼 때 선언.
//  - 쓸: 턴이 끝났을 때 바닥이 비면 상대 피 1장(마지막 턴 제외). 쪽·따닥·폭탄·뻑 가져오기도 피 1장.
//  - 손패가 바닥 두 장과 맞으면 직접 고른다(choice/hand), 뒤집은 패도 마찬가지(choice/deck).
//  - 폭탄 뒤에는 도탄 2번(뒤집기만 하는 턴) — 손패·더미가 같이 끝난다.
//  - 이기는 길은 스톱뿐. 낼 패가 없는 사람이 새로 나면 자동 스톱. 그대로 패가 떨어지면 나가리.
//  - 분배 때 바닥 같은 월 4장 → 다시 나눔. 총통(손에 같은 월 4장) = 10점 즉시 승리(거절 가능),
//    둘 다 총통이면 다시 나눔.
//
// 모든 동작은 { ok: true, state } 또는 { ok: false, reason } (reason은 영문 코드, 문구는 클라이언트).
// ──────────────────────────────────────────────────────────────

export const GOSTOP_VERSION = 2;
export const WIN_SCORE = 7;
export const CHONGTONG_POINTS = 10;
export const PIBAK_MAX_PI = 7;
export const DOTAN_PER_BOMB = 2;

/** 거부 사유 코드(클라이언트가 한국어로 바꾼다). */
export const REASONS = {
  game_over: 'game_over',
  invalid_phase: 'invalid_phase',
  not_your_turn: 'not_your_turn',
  not_in_game: 'not_in_game',
  card_not_in_hand: 'card_not_in_hand',
  cannot_shake: 'cannot_shake',
  cannot_bomb: 'cannot_bomb',
  no_dotan: 'no_dotan',
  invalid_choice: 'invalid_choice',
  invalid_decision: 'invalid_decision',
};

const T = { BRIGHT: 'bright', ANIMAL: 'animal', RIBBON: 'ribbon', JUNK: 'junk' };
const SUB = { RAIN: 'rain', DOUBLE: 'double', RED: 'red', BLUE: 'blue' };

// 48장: { id, month, type, subtype }. id는 그림 파일 이름과 같다(옛 id 유지: m1_animal = 1월 홍단 띠,
// m7_animal_2 = 7월 초단 띠).
export const DECK_DEF = Object.freeze([
  { id: 'm1_bright', month: 1, type: T.BRIGHT, subtype: null },
  { id: 'm1_animal', month: 1, type: T.RIBBON, subtype: SUB.RED },
  { id: 'm1_junk_1', month: 1, type: T.JUNK, subtype: null },
  { id: 'm1_junk_2', month: 1, type: T.JUNK, subtype: null },
  { id: 'm2_animal', month: 2, type: T.ANIMAL, subtype: null },
  { id: 'm2_ribbon', month: 2, type: T.RIBBON, subtype: SUB.RED },
  { id: 'm2_junk_1', month: 2, type: T.JUNK, subtype: null },
  { id: 'm2_junk_2', month: 2, type: T.JUNK, subtype: null },
  { id: 'm3_bright', month: 3, type: T.BRIGHT, subtype: null },
  { id: 'm3_ribbon', month: 3, type: T.RIBBON, subtype: SUB.RED },
  { id: 'm3_junk_1', month: 3, type: T.JUNK, subtype: null },
  { id: 'm3_junk_2', month: 3, type: T.JUNK, subtype: null },
  { id: 'm4_animal', month: 4, type: T.ANIMAL, subtype: null },
  { id: 'm4_ribbon', month: 4, type: T.RIBBON, subtype: null },
  { id: 'm4_junk_1', month: 4, type: T.JUNK, subtype: null },
  { id: 'm4_junk_2', month: 4, type: T.JUNK, subtype: null },
  { id: 'm5_animal', month: 5, type: T.ANIMAL, subtype: null },
  { id: 'm5_ribbon', month: 5, type: T.RIBBON, subtype: null },
  { id: 'm5_junk_1', month: 5, type: T.JUNK, subtype: null },
  { id: 'm5_junk_2', month: 5, type: T.JUNK, subtype: null },
  { id: 'm6_animal', month: 6, type: T.ANIMAL, subtype: null },
  { id: 'm6_ribbon', month: 6, type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm6_junk_1', month: 6, type: T.JUNK, subtype: null },
  { id: 'm6_junk_2', month: 6, type: T.JUNK, subtype: null },
  { id: 'm7_animal_1', month: 7, type: T.ANIMAL, subtype: null },
  { id: 'm7_animal_2', month: 7, type: T.RIBBON, subtype: null },
  { id: 'm7_junk_1', month: 7, type: T.JUNK, subtype: null },
  { id: 'm7_junk_2', month: 7, type: T.JUNK, subtype: null },
  { id: 'm8_bright', month: 8, type: T.BRIGHT, subtype: null },
  { id: 'm8_animal', month: 8, type: T.ANIMAL, subtype: null },
  { id: 'm8_junk_1', month: 8, type: T.JUNK, subtype: null },
  { id: 'm8_junk_2', month: 8, type: T.JUNK, subtype: null },
  { id: 'm9_animal', month: 9, type: T.ANIMAL, subtype: null },
  { id: 'm9_ribbon', month: 9, type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm9_junk_1', month: 9, type: T.JUNK, subtype: null },
  { id: 'm9_junk_2', month: 9, type: T.JUNK, subtype: null },
  { id: 'm10_animal', month: 10, type: T.ANIMAL, subtype: null },
  { id: 'm10_ribbon', month: 10, type: T.RIBBON, subtype: SUB.BLUE },
  { id: 'm10_junk_1', month: 10, type: T.JUNK, subtype: null },
  { id: 'm10_junk_2', month: 10, type: T.JUNK, subtype: null },
  { id: 'm11_bright', month: 11, type: T.BRIGHT, subtype: null },
  { id: 'm11_junk_1', month: 11, type: T.JUNK, subtype: null },
  { id: 'm11_junk_2', month: 11, type: T.JUNK, subtype: null },
  { id: 'm11_junk_d', month: 11, type: T.JUNK, subtype: SUB.DOUBLE },
  { id: 'm12_bright', month: 12, type: T.BRIGHT, subtype: SUB.RAIN },
  { id: 'm12_animal', month: 12, type: T.ANIMAL, subtype: null },
  { id: 'm12_ribbon', month: 12, type: T.RIBBON, subtype: null },
  { id: 'm12_junk_d', month: 12, type: T.JUNK, subtype: SUB.DOUBLE },
].map((c) => Object.freeze(c)));

const DECK_BY_ID = new Map(DECK_DEF.map((c) => [c.id, c]));

/** 카드 id → 카드(복사본). 없으면 null. */
export function cardById(id) {
  const c = DECK_BY_ID.get(id);
  return c ? { ...c } : null;
}

function shuffle(arr, random) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function createHwatuDeck(random = Math.random) {
  return shuffle(DECK_DEF.map((c) => ({ ...c })), random);
}

/**
 * 테스트·재현용 덱: 정해 둔 패를 앞(a 손패 → b 손패 → 바닥)부터 채우고 나머지는 월이 고르게
 * 섞이도록 채운다. 분배 순서: 앞 10장 = 첫째 손, 다음 10장 = 둘째 손, 다음 8장 = 바닥,
 * 나머지 20장 = 더미(배열 끝이 맨 위).
 */
export function buildDeck({ a = [], b = [], field = [], pile = [] } = {}) {
  const used = new Set([...a, ...b, ...field, ...pile]);
  const rest = DECK_DEF
    .map((c, i) => ({ c, slot: i % 4 }))
    .filter(({ c }) => !used.has(c.id))
    .sort((x, y) => x.slot - y.slot || x.c.month - y.c.month)
    .map(({ c }) => c.id);
  const take = (ids, n) => {
    const out = [...ids];
    while (out.length < n) out.push(rest.shift());
    return out;
  };
  const ha = take(a, 10);
  const hb = take(b, 10);
  const f = take(field, 8);
  const p = [...rest, ...pile];
  return [...ha, ...hb, ...f, ...p].map((id) => cardById(id));
}

// ── 점수 ────────────────────────────────────────────────────────
const HONGDAN_MONTHS = [1, 2, 3];
const CHEONGDAN_MONTHS = [6, 9, 10];
const CHODAN_MONTHS = [4, 5, 7];
const GODORI_MONTHS = [2, 4, 8];

const piValue = (c) => (c.type === T.JUNK ? (c.subtype === SUB.DOUBLE ? 2 : 1) : 0);

export function calculateScore(captures = []) {
  const brights = captures.filter((c) => c.type === T.BRIGHT);
  const animals = captures.filter((c) => c.type === T.ANIMAL);
  const ribbons = captures.filter((c) => c.type === T.RIBBON);

  const gwangCount = brights.length;
  const hasRain = brights.some((c) => c.subtype === SUB.RAIN);
  let gwangScore = 0;
  if (gwangCount === 3) gwangScore = hasRain ? 2 : 3;
  else if (gwangCount === 4) gwangScore = 4;
  else if (gwangCount >= 5) gwangScore = 15;

  const animCount = animals.length;
  const animScore = animCount >= 5 ? animCount - 4 : 0;
  const godoriScore = GODORI_MONTHS.every((m) => animals.some((c) => c.month === m)) ? 5 : 0;

  const ribCount = ribbons.length;
  const ribScore = ribCount >= 5 ? ribCount - 4 : 0;
  const has = (months, subtype) => months.every((m) => ribbons.some((r) => r.month === m && r.subtype === subtype));
  const hongdanBonus = has(HONGDAN_MONTHS, SUB.RED) ? 3 : 0;
  const cheongdanBonus = has(CHEONGDAN_MONTHS, SUB.BLUE) ? 3 : 0;
  const chodanBonus = has(CHODAN_MONTHS, null) ? 3 : 0;

  const piTotal = captures.reduce((s, c) => s + piValue(c), 0);
  const piScore = piTotal >= 10 ? piTotal - 9 : 0;

  const total = gwangScore + animScore + godoriScore + ribScore + hongdanBonus + cheongdanBonus + chodanBonus + piScore;
  return {
    total, gwangScore, gwangCount, hasRain, animScore, animCount, godoriScore,
    ribScore, ribCount, hongdanBonus, cheongdanBonus, chodanBonus, piScore, piTotal,
  };
}

// ── 공통 도우미 ─────────────────────────────────────────────────
const clone = (s) => JSON.parse(JSON.stringify(s));
const other = (s, p) => s.players.find((x) => x !== p);
const ofMonth = (list, month) => list.filter((c) => c.month === month);
const removeIds = (list, ids) => list.filter((c) => !ids.includes(c.id));
const turnsLeft = (s, p) => (s.hands[p]?.length ?? 0) + (s.dotan?.[p] ?? 0);
const noTurnsLeft = (s) => s.players.every((p) => turnsLeft(s, p) === 0);
const fail = (reason) => ({ ok: false, reason });
const done = (state) => ({ ok: true, state });

/** 점수를 다시 계산한 새 상태. */
export function rescore(state) {
  return {
    ...state,
    scores: Object.fromEntries(state.players.map((p) => [p, calculateScore(state.captures[p] ?? [])])),
  };
}

// 같은 종류(종류·세부 종류)면 어느 쪽을 먹어도 같다 → 묻지 않는다.
const sameKind = (x, y) => x.type === y.type && (x.subtype ?? null) === (y.subtype ?? null);

// 자동 선택·코치용 패 가치: 광 > 열끗 > 띠 > 쌍피 > 피.
function cardValue(c) {
  if (!c) return 0;
  if (c.type === T.BRIGHT) return 5;
  if (c.type === T.ANIMAL) return 4;
  if (c.type === T.RIBBON) return 3;
  return c.subtype === SUB.DOUBLE ? 2 : 1;
}

function monthCounts(cards) {
  const counts = {};
  for (const c of cards) counts[c.month] = (counts[c.month] ?? 0) + 1;
  return counts;
}

// ── 판 만들기 ───────────────────────────────────────────────────
function dealOnce(deck, [p1, p2]) {
  const d = deck.map((c) => ({ ...c }));
  return {
    hands: { [p1]: d.slice(0, 10), [p2]: d.slice(10, 20) },
    field: d.slice(20, 28),
    deck: d.slice(28),
  };
}

const chongtongMonth = (hand) => {
  const counts = monthCounts(hand);
  const m = Object.keys(counts).map(Number).sort((a, b) => a - b).find((k) => counts[k] === 4);
  return m ?? null;
};

/**
 * 새 판. opts: { random, starter, perPointBet, gameId, decks(테스트: 차례로 쓸 덱 목록) }
 * 바닥 같은 월 4장, 두 사람 모두 총통이면 다시 나눈다(redeals에 사유를 남김).
 */
export function createGostopGameState(p1, p2, opts = {}) {
  const random = opts.random ?? Math.random;
  const players = [p1, p2];
  const starter = players.includes(opts.starter) ? opts.starter : players[Math.floor(random() * 2)];
  const redeals = [];
  let dealt = null;
  let chongtong = null;
  for (let attempt = 0; attempt < 100; attempt++) {
    const deck = opts.decks?.[attempt] ?? createHwatuDeck(random);
    const d = dealOnce(deck, players);
    if (Object.values(monthCounts(d.field)).some((n) => n >= 4)) {
      redeals.push('field_four');
      continue;
    }
    const holders = players
      .map((p) => ({ player: p, month: chongtongMonth(d.hands[p]) }))
      .filter((h) => h.month != null);
    if (holders.length === 2) {
      redeals.push('double_chongtong');
      continue;
    }
    dealt = d;
    chongtong = holders[0] ?? null;
    break;
  }
  if (!dealt) dealt = dealOnce(opts.decks?.at(-1) ?? createHwatuDeck(random), players); // 사실상 도달 불가

  const zero = () => ({ [p1]: 0, [p2]: 0 });
  const state = {
    version: GOSTOP_VERSION,
    gameId: opts.gameId ?? null,
    perPointBet: Math.max(0, Number(opts.perPointBet) || 0),
    players,
    starter,
    current: chongtong ? chongtong.player : starter,
    phase: chongtong ? 'chongtong' : 'playing',
    chongtong,
    redeals,
    deck: dealt.deck,
    field: dealt.field,
    hands: dealt.hands,
    captures: { [p1]: [], [p2]: [] },
    dotan: zero(),
    goCount: zero(),
    goScore: zero(),
    shakes: { [p1]: [], [p2]: [] },
    bombs: zero(),
    ppeok: {},
    pending: null,
    turnCtx: null,
    turn: 1,
    seq: 1,
    lastTurn: { kind: 'deal', seq: 1, by: null, events: [], redeals },
    result: null,
  };
  return rescore(state);
}

// ── 공통 검사 ───────────────────────────────────────────────────
function guard(state, player, phase) {
  if (!state || state.version !== GOSTOP_VERSION) return REASONS.invalid_phase;
  if (state.phase === 'finished' || state.phase === 'nagari') return REASONS.game_over;
  if (!state.players.includes(player)) return REASONS.not_in_game;
  if (phase && state.phase !== phase) return REASONS.invalid_phase;
  if (state.current !== player) return REASONS.not_your_turn;
  return null;
}

/** 지금 낼 수 있는 특수 수: 흔들 수 있는 월, 폭탄 월, 도탄 수. */
export function legalMoves(state, player) {
  const hand = state.hands[player] ?? [];
  const counts = monthCounts(hand);
  const shaken = state.shakes?.[player] ?? [];
  const months = Object.keys(counts).map(Number).sort((a, b) => a - b);
  return {
    shakeable: months.filter((m) => counts[m] >= 3 && ofMonth(state.field, m).length === 0 && !shaken.includes(m)),
    bombable: months.filter((m) => counts[m] === 3 && ofMonth(state.field, m).length === 1),
    dotan: state.dotan?.[player] ?? 0,
  };
}

function newCtx(state, player, kind, auto) {
  return {
    kind, by: player, auto: !!auto,
    played: null, mode: null, pairWith: [],
    flipped: null,
    captured: [], stolen: [], events: [], shown: [],
    steal: 0,
    scoreBefore: state.scores[player]?.total ?? 0,
  };
}

function capture(s, player, list) {
  const ids = list.map((c) => c.id);
  s.field = removeIds(s.field, ids);
  s.captures[player] = [...s.captures[player], ...list];
  s.turnCtx.captured.push(...list);
}

// ── 동작: 패 내기 ───────────────────────────────────────────────
/** 손패 한 장 내기. { cardId, shake?: 흔들기 선언, targetId?: 두 장 중 고를 바닥 패 } */
export function playCard(state, player, { cardId, shake = false, targetId = null } = {}, { auto = false } = {}) {
  const bad = guard(state, player, 'playing');
  if (bad) return fail(bad);
  const card = (state.hands[player] ?? []).find((c) => c.id === cardId);
  if (!card) return fail(REASONS.card_not_in_hand);
  if (shake && !legalMoves(state, player).shakeable.includes(card.month)) return fail(REASONS.cannot_shake);

  const s = clone(state);
  s.turnCtx = newCtx(s, player, 'play', auto);
  const ctx = s.turnCtx;
  if (shake) {
    s.shakes[player] = [...s.shakes[player], card.month];
    ctx.events.push('shake');
    ctx.shown = ofMonth(s.hands[player], card.month);
  }
  s.hands[player] = removeIds(s.hands[player], [card.id]);
  ctx.played = card;
  const matches = ofMonth(s.field, card.month);
  if (matches.length === 0) {
    ctx.mode = 'alone';
    s.field.push(card);
  } else if (matches.length === 1) {
    ctx.mode = 'pair';
    ctx.pairWith = [matches[0].id];
    s.field.push(card);
  } else if (matches.length === 2) {
    const target = matches.find((c) => c.id === targetId);
    if (target || sameKind(matches[0], matches[1])) {
      ctx.mode = 'double';
      ctx.pairWith = [(target ?? matches[0]).id];
      s.field.push(card);
    } else {
      s.phase = 'choice';
      s.pending = { kind: 'hand', card, options: matches };
      return done(s);
    }
  } else {
    ctx.mode = 'sweep';
    ctx.pairWith = matches.map((c) => c.id);
    s.field.push(card);
  }
  return done(flipStep(s));
}

/** 폭탄: 손패 같은 월 3장 + 바닥 1장. 피 1장, 폭탄 ×2(이기면), 도탄 2번. */
export function playBomb(state, player, month, { auto = false } = {}) {
  const bad = guard(state, player, 'playing');
  if (bad) return fail(bad);
  if (!legalMoves(state, player).bombable.includes(Number(month))) return fail(REASONS.cannot_bomb);
  const m = Number(month);
  const s = clone(state);
  s.turnCtx = newCtx(s, player, 'bomb', auto);
  const ctx = s.turnCtx;
  const handCards = ofMonth(s.hands[player], m);
  ctx.shown = handCards;
  s.hands[player] = removeIds(s.hands[player], handCards.map((c) => c.id));
  s.field.push(...handCards);
  capture(s, player, ofMonth(s.field, m));
  ctx.events.push('bomb');
  ctx.steal += 1;
  ctx.bombMonth = m;
  s.bombs[player] += 1;
  s.dotan[player] += DOTAN_PER_BOMB;
  takePpeokMarker(s, m);
  return done(flipStep(s));
}

/** 도탄: 손패를 내지 않고 더미만 뒤집는다. */
export function playDotan(state, player, { auto = false } = {}) {
  const bad = guard(state, player, 'playing');
  if (bad) return fail(bad);
  if ((state.dotan?.[player] ?? 0) <= 0) return fail(REASONS.no_dotan);
  const s = clone(state);
  s.turnCtx = newCtx(s, player, 'dotan', auto);
  s.dotan[player] -= 1;
  return done(flipStep(s));
}

/** 두 장 중 하나 고르기(손패 choice/hand, 뒤집은 패 choice/deck). */
export function choose(state, player, fieldCardId, { auto = false } = {}) {
  const bad = guard(state, player, 'choice');
  if (bad) return fail(bad);
  const pending = state.pending;
  const chosen = pending?.options?.find((c) => c.id === fieldCardId);
  if (!chosen) return fail(REASONS.invalid_choice);
  const s = clone(state);
  s.phase = 'playing';
  s.pending = null;
  if (auto) s.turnCtx.auto = true;
  if (pending.kind === 'hand') {
    const ctx = s.turnCtx;
    ctx.played = pending.card;
    ctx.mode = 'double';
    ctx.pairWith = [chosen.id];
    s.field.push(pending.card);
    return done(flipStep(s));
  }
  s.field.push(pending.card);
  capture(s, player, [pending.card, s.field.find((c) => c.id === chosen.id)]);
  return done(resolveTurn(s));
}

// 뻑 더미를 가져가면 표시를 지우고 피 1장.
function takePpeokMarker(s, month) {
  if (s.ppeok?.[month] == null) return;
  delete s.ppeok[month];
  s.turnCtx.events.push('ppeok_take');
  s.turnCtx.steal += 1;
}

// 더미 한 장을 뒤집고 낸 패와 함께 정리한다.
function flipStep(s) {
  const ctx = s.turnCtx;
  const played = ctx.played;
  const flip = s.deck.length ? s.deck.pop() : null;
  ctx.flipped = flip;

  if (played && flip && flip.month === played.month && ctx.mode !== 'sweep') {
    if (ctx.mode === 'alone') {
      s.field.push(flip);
      capture(s, ctx.by, [played, flip]);
      ctx.events.push('jjok');
      ctx.steal += 1;
    } else if (ctx.mode === 'pair') {
      s.field.push(flip);
      s.ppeok[played.month] = ctx.by;
      ctx.events.push('ppeok');
    } else {
      // double → 따닥: 바닥 남은 한 장까지 네 장 모두
      s.field.push(flip);
      capture(s, ctx.by, ofMonth(s.field, played.month));
      ctx.events.push('ttadak');
      ctx.steal += 1;
    }
    return resolveTurn(s);
  }

  if (played) {
    if (ctx.mode === 'pair' || ctx.mode === 'double') {
      capture(s, ctx.by, [played, ...s.field.filter((c) => ctx.pairWith.includes(c.id))]);
    } else if (ctx.mode === 'sweep') {
      capture(s, ctx.by, ofMonth(s.field, played.month));
      takePpeokMarker(s, played.month);
    }
  }

  if (flip) {
    const matches = ofMonth(s.field, flip.month);
    if (matches.length === 0) {
      s.field.push(flip);
    } else if (matches.length === 1) {
      s.field.push(flip);
      capture(s, ctx.by, [flip, matches[0]]);
    } else if (matches.length === 2) {
      if (sameKind(matches[0], matches[1])) {
        s.field.push(flip);
        capture(s, ctx.by, [flip, matches[0]]);
      } else {
        s.phase = 'choice';
        s.pending = { kind: 'deck', card: flip, options: matches };
        return s;
      }
    } else {
      s.field.push(flip);
      capture(s, ctx.by, ofMonth(s.field, flip.month));
      takePpeokMarker(s, flip.month);
    }
  }
  return resolveTurn(s);
}

// 상대 피 n장(일반 피 먼저, 없으면 쌍피).
function stealPi(s, thief, count) {
  const victim = other(s, thief);
  const stolen = [];
  for (let i = 0; i < count; i++) {
    const junk = s.captures[victim].filter((c) => c.type === T.JUNK);
    if (!junk.length) break;
    const pick = junk.find((c) => c.subtype !== SUB.DOUBLE) ?? junk[0];
    s.captures[victim] = removeIds(s.captures[victim], [pick.id]);
    s.captures[thief] = [...s.captures[thief], pick];
    stolen.push(pick);
  }
  return stolen;
}

// 턴 끝: 쓸 판정(마지막 턴 제외) → 피 뺏기 → 점수 → 고/스톱·자동 스톱·나가리·다음 차례.
function resolveTurn(s) {
  const ctx = s.turnCtx;
  const p = ctx.by;
  const lastTurnOfGame = noTurnsLeft(s);
  if (s.field.length === 0 && !lastTurnOfGame) {
    ctx.events.push('sseul');
    ctx.steal += 1;
  }
  ctx.stolen = stealPi(s, p, ctx.steal);
  s = rescore(s);
  s.seq += 1;
  const { steal: _steal, ...shown } = ctx;
  s.lastTurn = { ...shown, seq: s.seq, scoreAfter: s.scores[p].total };
  s.turnCtx = null;
  s.pending = null;
  s.turn += 1;

  const score = s.scores[p].total;
  if (score >= WIN_SCORE && score > (s.goScore[p] ?? 0)) {
    if (turnsLeft(s, p) === 0) return settle(s, p, 'auto_stop');
    s.phase = 'go_stop';
    s.current = p;
    return s;
  }
  if (lastTurnOfGame) return nagari(s);
  return nextTurn(s, p);
}

function nextTurn(s, from) {
  const opp = other(s, from);
  s.phase = 'playing';
  s.current = turnsLeft(s, opp) > 0 ? opp : from;
  return s;
}

function nagari(s) {
  s.phase = 'nagari';
  s.current = null;
  s.result = {
    reason: 'nagari',
    winner: null,
    loser: null,
    points: { base: 0, go: 0, total: 0 },
    multipliers: [],
    multiplier: 1,
    perPointBet: s.perPointBet,
    amount: 0,
    goCount: { ...s.goCount },
    scores: { ...s.scores },
  };
  return s;
}

// ── 고/스톱 ─────────────────────────────────────────────────────
export function declare(state, player, decision, { auto = false } = {}) {
  const bad = guard(state, player, 'go_stop');
  if (bad) return fail(bad);
  if (decision !== 'go' && decision !== 'stop') return fail(REASONS.invalid_decision);
  let s = clone(state);
  if (decision === 'stop') return done(settle(s, player, 'stop', { auto }));
  s.goCount[player] += 1;
  s.goScore[player] = s.scores[player].total;
  s.seq += 1;
  s.lastTurn = { kind: 'go', by: player, auto, seq: s.seq, goCount: s.goCount[player], events: ['go'] };
  s = nextTurn(s, player);
  return done(s);
}

/** 총통 선언(10점 즉시 승리) 또는 거절. */
export function decideChongtong(state, player, declareIt, { auto = false } = {}) {
  const bad = guard(state, player, 'chongtong');
  if (bad) return fail(bad);
  const s = clone(state);
  if (declareIt) return done(settle(s, player, 'chongtong', { auto }));
  s.phase = 'playing';
  s.current = s.starter;
  s.seq += 1;
  s.lastTurn = { kind: 'chongtong_decline', by: player, auto, seq: s.seq, events: [] };
  return done(s);
}

/** 잠수 기권: 상대가 자기 실제 점수·배수로 이긴다. */
export function forfeit(state, loser) {
  if (!state || state.version !== GOSTOP_VERSION) return fail(REASONS.invalid_phase);
  if (state.phase === 'finished' || state.phase === 'nagari') return fail(REASONS.game_over);
  if (!state.players.includes(loser)) return fail(REASONS.not_in_game);
  const s = rescore(clone(state));
  s.pending = null;
  s.turnCtx = null;
  return done(settle(s, other(s, loser), 'forfeit'));
}

// ── 정산 ────────────────────────────────────────────────────────
/**
 * 이 사람이 지금 이겼다면 받을 정산(점수·배수 분해·금액).
 * opts.extraGo / extraPoints: "고 하고 n점 더 나면" 미리보기.
 */
export function computeSettlement(state, winner, reason = 'stop', { extraGo = 0, extraPoints = 0 } = {}) {
  const loser = other(state, winner);
  const ws = calculateScore(state.captures[winner] ?? []);
  const ls = calculateScore(state.captures[loser] ?? []);
  const perPointBet = state.perPointBet ?? 0;
  if (reason === 'chongtong') {
    return {
      reason, winner, loser,
      points: { base: CHONGTONG_POINTS, go: 0, total: CHONGTONG_POINTS },
      multipliers: [], multiplier: 1, perPointBet,
      amount: CHONGTONG_POINTS * perPointBet,
      chongtongMonth: state.chongtong?.month ?? null,
      winnerScore: ws, loserScore: ls,
      goCount: { ...state.goCount },
    };
  }
  const goN = (state.goCount?.[winner] ?? 0) + extraGo;
  const base = ws.total + extraPoints;
  const multipliers = [];
  if (goN >= 3) multipliers.push({ code: 'go', count: goN, factor: 2 ** (goN - 2) });
  const shakeN = state.shakes?.[winner]?.length ?? 0;
  if (shakeN > 0) multipliers.push({ code: 'shake', count: shakeN, factor: 2 ** shakeN });
  const bombN = state.bombs?.[winner] ?? 0;
  if (bombN > 0) multipliers.push({ code: 'bomb', count: bombN, factor: 2 ** bombN });
  if (ws.piScore > 0 && ls.piTotal <= PIBAK_MAX_PI) multipliers.push({ code: 'pibak', count: 1, factor: 2 });
  if (ws.gwangScore > 0 && ls.gwangCount === 0) multipliers.push({ code: 'gwangbak', count: 1, factor: 2 });
  if ((state.goCount?.[loser] ?? 0) > 0) multipliers.push({ code: 'gobak', count: 1, factor: 2 });
  const multiplier = multipliers.reduce((m, x) => m * x.factor, 1);
  const total = base + goN;
  return {
    reason, winner, loser,
    points: { base, go: goN, total },
    multipliers, multiplier, perPointBet,
    amount: total * multiplier * perPointBet,
    winnerScore: ws, loserScore: ls,
    goCount: { ...state.goCount },
  };
}

// 판을 끝낸다. 마지막 턴에 자동 스톱이면 그 턴의 연출(lastTurn)에 표시만 덧붙인다.
function settle(s, winner, reason, { auto = false } = {}) {
  s.result = { ...computeSettlement(s, winner, reason), auto };
  s.phase = 'finished';
  s.current = null;
  if (reason === 'auto_stop' && s.lastTurn?.by === winner && s.lastTurn.kind !== 'deal') {
    s.lastTurn = { ...s.lastTurn, events: [...(s.lastTurn.events ?? []), 'auto_stop'] };
  } else {
    s.seq += 1;
    s.lastTurn = { kind: reason, by: winner, auto, seq: s.seq, events: [reason] };
  }
  return s;
}

/** 고/스톱 패널: 지금 스톱 vs 고 하고 1점 더 나서 스톱. */
export function goStopPreview(state, player) {
  return {
    stopNow: computeSettlement(state, player, 'stop'),
    afterGo: computeSettlement(state, player, 'stop', { extraGo: 1, extraPoints: 1 }),
  };
}

// ── 코치·자동 행동 ──────────────────────────────────────────────
// 손패 한 장의 가치: 먹을 수 있는 패의 값(+점수 증가), 못 먹으면 버리는 패가 쌀수록 낫다.
function playGain(state, player, c) {
  const matches = ofMonth(state.field, c.month);
  const before = calculateScore(state.captures[player]).total;
  const scoreWith = (extra) => calculateScore([...state.captures[player], ...extra]).total - before;
  if (matches.length === 0) return -1 - cardValue(c) * 0.1;
  if (matches.length === 1) return cardValue(c) + cardValue(matches[0]) + scoreWith([c, matches[0]]) * 3;
  if (matches.length === 2) {
    return Math.max(...matches.map((m) => cardValue(c) + cardValue(m) + scoreWith([c, m]) * 3));
  }
  return matches.reduce((sum, m) => sum + cardValue(m), cardValue(c)) + 2 + scoreWith([c, ...matches]) * 3;
}

/** 코치 추천 수(자동 행동도 같은 수를 둔다). { type: 'play'|'bomb'|'dotan', cardId?, month? } */
export function recommendMove(state, player) {
  const moves = legalMoves(state, player);
  const hand = state.hands[player] ?? [];
  let best = null;
  for (const m of moves.bombable) {
    const gain = ofMonth(state.field, m).concat(ofMonth(hand, m)).reduce((s, c) => s + cardValue(c), 0) + 3;
    if (!best || gain > best.gain) best = { type: 'bomb', month: m, gain };
  }
  for (const c of [...hand].sort((x, y) => (x.id < y.id ? -1 : 1))) {
    const gain = playGain(state, player, c);
    if (!best || gain > best.gain) best = { type: 'play', cardId: c.id, gain };
  }
  if (moves.dotan > 0 && (!best || best.gain <= 0)) return { type: 'dotan' };
  if (!best) return moves.dotan > 0 ? { type: 'dotan' } : null;
  const { gain: _gain, ...move } = best;
  return move;
}

/** 두 장 중 점수가 더 오르는 쪽(같으면 값이 큰 패). */
export function bestChoice(state, player) {
  const { card, options } = state.pending;
  const caps = state.captures[player] ?? [];
  const ranked = [...options].sort((x, y) =>
    calculateScore([...caps, card, y]).total - calculateScore([...caps, card, x]).total ||
    cardValue(y) - cardValue(x) || (x.id < y.id ? -1 : 1));
  return ranked[0].id;
}

/** 마감 시 자동 행동: 패 = 코치 추천(흔들기 안 함), 선택 = 점수 높은 쪽, 고/스톱 = 스톱, 총통 = 선언. */
export function autoAction(state) {
  const p = state.current;
  switch (state.phase) {
    case 'chongtong': return { type: 'chongtong', declare: true };
    case 'go_stop': return { type: 'decide', decision: 'stop' };
    case 'choice': return { type: 'choose', cardId: bestChoice(state, p) };
    case 'playing': {
      const move = recommendMove(state, p);
      if (!move) return null;
      if (move.type === 'bomb') return { type: 'bomb', month: move.month };
      if (move.type === 'dotan') return { type: 'dotan' };
      return { type: 'play', cardId: move.cardId };
    }
    default: return null;
  }
}

/** 자동 행동을 적용한다(lastTurn.auto = true). */
export function applyAuto(state) {
  const a = autoAction(state);
  const p = state.current;
  const opts = { auto: true };
  if (!a) return fail(REASONS.invalid_phase);
  switch (a.type) {
    case 'chongtong': return decideChongtong(state, p, a.declare, opts);
    case 'decide': return declare(state, p, a.decision, opts);
    case 'choose': return choose(state, p, a.cardId, opts);
    case 'bomb': return playBomb(state, p, a.month, opts);
    case 'dotan': return playDotan(state, p, opts);
    default: return playCard(state, p, { cardId: a.cardId }, opts);
  }
}

// ── 직렬화 ──────────────────────────────────────────────────────
/**
 * 한 사람용 view. 상대 손패·더미 순서·상대 총통 월은 보내지 않는다.
 * extra: 모듈이 붙이는 값(turnDeadline 등)은 state에 이미 있다.
 */
export function serializeFor(state, viewer) {
  const s = state;
  const players = s.players ?? [];
  const isActor = s.current === viewer && !['finished', 'nagari'].includes(s.phase);
  const projection = Object.fromEntries(players.map((p) => {
    const st = computeSettlement(s, p, 'stop');
    return [p, { points: st.points, multipliers: st.multipliers, multiplier: st.multiplier, amount: st.amount }];
  }));
  const ct = s.chongtong
    ? { player: s.chongtong.player, month: s.chongtong.player === viewer ? s.chongtong.month : null }
    : null;
  return {
    version: s.version,
    gameId: s.gameId ?? null,
    seq: s.seq ?? 0,
    turn: s.turn ?? 1,
    phase: s.phase,
    players,
    starter: s.starter ?? null,
    current: s.current ?? null,
    perPointBet: s.perPointBet ?? 0,
    stake: s.perPointBet ?? 0,
    hand: s.hands?.[viewer] ?? [],
    handCount: Object.fromEntries(players.map((p) => [p, s.hands?.[p]?.length ?? 0])),
    deckCount: s.deck?.length ?? 0,
    field: s.field ?? [],
    captures: s.captures ?? {},
    scores: s.scores ?? {},
    dotan: s.dotan ?? {},
    goCount: s.goCount ?? {},
    goScore: s.goScore ?? {},
    shakes: s.shakes ?? {},
    bombs: s.bombs ?? {},
    ppeok: s.ppeok ?? {},
    pending: s.pending ?? null,
    chongtong: ct,
    redeals: s.redeals ?? [],
    lastTurn: s.lastTurn ?? null,
    moves: isActor && s.phase === 'playing' ? legalMoves(s, viewer) : null,
    coach: isActor && s.phase === 'playing' ? recommendMove(s, viewer) : null,
    projection,
    goPreview: isActor && s.phase === 'go_stop' ? goStopPreview(s, viewer) : null,
    result: s.result ?? null,
    turnDeadline: s.turnDeadline ?? null,
    turnMs: s.turnMs ?? null,
    autoStreak: s.autoStreak ?? {},
    series: s.series ?? null,
    serverNow: Date.now(),
  };
}
