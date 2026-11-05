// pirate-engine.js — 해적 룰렛 2.0 순수 규칙(입출력 없음, random·now 주입).
//
// 통에 구멍이 holes개(6/8/12, 짝수만) 있고 그중 하나에 폭탄이 있다. 두 사람이 번갈아
// 구멍 하나에 칼을 꽂고, 폭탄 구멍을 찌른 사람이 해적을 날려 보내고 진다.
// 폭탄 위치는 균등하므로 "폭탄이 몇 번째 찌르기에서 나오는지"도 1..holes에 균등하다.
// 선공은 홀수 번째 찌르기를 맡으니 선공이 질 확률은 ceil(holes/2)/holes —
// 짝수 holes에서만 정확히 50%다(00-analysis §5). 그래서 짝수 프리셋만 허용한다.
//
// 폭발 뒤에는 벌칙 단계: 이긴 사람이 벌칙 문구(1~30자)를 한 번 정하고,
// 진 사람이 "했어요!"를 한 번 누른다.

export const PIRATE_HOLES = Object.freeze([6, 8, 12]);
export const PIRATE_DEFAULT_HOLES = 8;
/** 한 차례 제한 시간. 지나면 서버가 남은 구멍 중 하나를 대신 찌른다. */
export const PIRATE_TURN_MS = 20_000;
/** 연속 시간 초과가 이 횟수에 이르면 기권패. */
export const PIRATE_MAX_TIMEOUTS = 3;
export const PIRATE_PENALTY_MAX = 30;
export const PIRATE_PENALTY_PRESETS = Object.freeze([
  "어깨 주물러 주기",
  "칭찬 3가지",
  "노래 한 소절",
  "오늘 설거지",
  "딱밤 한 대",
  "사진 한 장 찍어 주기",
  "소원 하나 들어주기",
  "애교 한 번",
  "아이스크림 사기",
  "10분 안마",
]);

/** 허용되지 않은 값은 기본 8로. */
export function normalizeHoles(holes) {
  return PIRATE_HOLES.includes(holes) ? holes : PIRATE_DEFAULT_HOLES;
}

/** 남은 구멍 기준 폭탄 확률(%), 반올림. 남은 구멍이 없으면 100. */
export function riskPct(remaining) {
  return remaining > 0 ? Math.round(100 / remaining) : 100;
}

/** 무작위로 고른 선공이 질 확률(정확한 값). 짝수면 0.5. */
export function firstPlayerLossProbability(holes) {
  return Math.ceil(holes / 2) / holes;
}

export function remainingOf(state) {
  return state.slots - state.pickedSlots.length;
}

export function freeSlots(state) {
  const picked = new Set(state.pickedSlots);
  const out = [];
  for (let i = 0; i < state.slots; i++) if (!picked.has(i)) out.push(i);
  return out;
}

const pickIndex = (random, n) => Math.min(n - 1, Math.floor(random() * n));

/**
 * 새 판. players는 [p1, p2](커플 순서). firstTurn을 주지 않으면 random으로 선공을 정한다.
 * startsAt은 첫 차례가 시작되는 시각(로비 카운트다운 끝). 첫 마감 = startsAt + 차례 시간.
 */
export function createPirateGame({
  players,
  holes = PIRATE_DEFAULT_HOLES,
  gameId,
  random = Math.random,
  now = Date.now(),
  startsAt = now,
  firstTurn,
  round = 1,
}) {
  if (!Array.isArray(players) || players.length !== 2 || players[0] === players[1]) {
    throw new Error("pirate needs two distinct players");
  }
  const slots = normalizeHoles(holes);
  const first = players.includes(firstTurn) ? firstTurn : players[pickIndex(random, 2)];
  return {
    gameId,
    round,
    slots,
    bombSlot: pickIndex(random, slots),
    pickedSlots: [],
    stabs: [],
    players: [...players],
    firstTurn: first,
    currentTurn: first,
    phase: "playing",
    timeouts: Object.fromEntries(players.map((p) => [p, 0])),
    turnDeadline: startsAt + PIRATE_TURN_MS,
    startedAt: now,
    winner: null,
    loser: null,
    reason: null,
    explodedAt: null,
    penalty: null,
    seq: 0,
  };
}

const otherOf = (state, player) => state.players.find((p) => p !== player) ?? null;

function explode(state, loser, { reason, now }) {
  return {
    ...state,
    phase: "exploded",
    currentTurn: null,
    turnDeadline: null,
    loser,
    winner: otherOf(state, loser),
    reason,
    explodedAt: now,
  };
}

/**
 * player가 slot을 찌른다. auto면 시간 초과로 서버가 대신 찌른 것.
 * → { ok:false, reason } | { ok:true, state, exploded }
 */
export function applyStab(state, player, slot, { auto = false, now = Date.now() } = {}) {
  if (!state || state.phase !== "playing") return { ok: false, reason: "not_playing" };
  if (!state.players.includes(player)) return { ok: false, reason: "not_a_player" };
  if (state.currentTurn !== player) return { ok: false, reason: "not_your_turn" };
  if (!Number.isInteger(slot) || slot < 0 || slot >= state.slots) return { ok: false, reason: "invalid_slot" };
  if (state.pickedSlots.includes(slot)) return { ok: false, reason: "slot_taken" };

  const timeouts = { ...state.timeouts, [player]: auto ? (state.timeouts?.[player] ?? 0) + 1 : 0 };
  let next = {
    ...state,
    pickedSlots: [...state.pickedSlots, slot],
    stabs: [...(state.stabs ?? []), { slot, by: player, auto }],
    timeouts,
    seq: (state.seq ?? 0) + 1,
  };
  if (slot === state.bombSlot) {
    next = explode(next, player, { reason: "bomb", now });
    return { ok: true, state: next, exploded: true };
  }
  next.currentTurn = otherOf(state, player);
  next.turnDeadline = now + PIRATE_TURN_MS;
  return { ok: true, state: next, exploded: false };
}

/**
 * 차례 시간이 지났을 때. 연속 시간 초과가 PIRATE_MAX_TIMEOUTS에 이르면 기권패,
 * 아니면 남은 구멍 중 하나를 무작위로 대신 찌른다.
 * → { ok:false, reason } | { ok:true, state, exploded, forfeit, slot }
 */
export function applyTimeout(state, { random = Math.random, now = Date.now() } = {}) {
  if (!state || state.phase !== "playing") return { ok: false, reason: "not_playing" };
  const player = state.currentTurn;
  const count = (state.timeouts?.[player] ?? 0) + 1;
  if (count >= PIRATE_MAX_TIMEOUTS) {
    const next = explode(
      { ...state, timeouts: { ...state.timeouts, [player]: count }, seq: (state.seq ?? 0) + 1 },
      player,
      { reason: "timeout", now },
    );
    return { ok: true, state: next, exploded: true, forfeit: true, slot: null };
  }
  const free = freeSlots(state);
  const slot = free[pickIndex(random, free.length)];
  const result = applyStab(state, player, slot, { auto: true, now });
  return { ...result, forfeit: false, slot };
}

/** 잠수 감시(90초) 기권. */
export function applyForfeit(state, loser, { now = Date.now() } = {}) {
  if (!state || state.phase !== "playing" || !state.players.includes(loser)) return { ok: false, reason: "not_playing" };
  return { ok: true, state: explode({ ...state, seq: (state.seq ?? 0) + 1 }, loser, { reason: "afk", now }) };
}

/** 벌칙 문구 검증: 문자열, 공백 정리, 1~30자(코드 포인트 기준). */
export function normalizePenaltyText(raw) {
  if (typeof raw !== "string") return { ok: false, reason: "invalid_payload" };
  // 제어 문자·줄바꿈은 공백으로, 연속 공백은 하나로.
  // eslint-disable-next-line no-control-regex
  const text = raw.replace(/[\u0000-\u001F\u007F]/g, " ").replace(/\s+/g, " ").trim();
  const length = Array.from(text).length;
  if (length === 0) return { ok: false, reason: "penalty_empty" };
  if (length > PIRATE_PENALTY_MAX) return { ok: false, reason: "penalty_too_long" };
  return { ok: true, text };
}

/** 이긴 사람이 벌칙을 정한다(한 번만). */
export function setPenalty(state, by, raw, { now = Date.now() } = {}) {
  if (!state || state.phase !== "exploded") return { ok: false, reason: "not_exploded" };
  if (by !== state.winner) return { ok: false, reason: "not_winner" };
  if (state.penalty) return { ok: false, reason: "penalty_already_set" };
  const checked = normalizePenaltyText(raw);
  if (!checked.ok) return checked;
  return {
    ok: true,
    state: { ...state, penalty: { text: checked.text, by, at: now, doneAt: null }, seq: (state.seq ?? 0) + 1 },
  };
}

/** 진 사람이 벌칙을 했다고 알린다(한 번만). */
export function completePenalty(state, by, { now = Date.now() } = {}) {
  if (!state || state.phase !== "exploded") return { ok: false, reason: "not_exploded" };
  if (by !== state.loser) return { ok: false, reason: "not_loser" };
  if (!state.penalty) return { ok: false, reason: "no_penalty" };
  if (state.penalty.doneAt) return { ok: false, reason: "penalty_already_done" };
  return {
    ok: true,
    state: { ...state, penalty: { ...state.penalty, doneAt: now }, seq: (state.seq ?? 0) + 1 },
  };
}

/** 재대결의 선공: 지난 판 선공의 상대. */
export function nextFirstTurn(previous, players) {
  const prev = previous?.firstTurn;
  if (!players.includes(prev)) return undefined;
  return players.find((p) => p !== prev);
}

/** 클라이언트에 보내는 상태. 폭발 전에는 폭탄 위치를 숨긴다. 두 사람이 같은 것을 본다. */
export function publicPirateState(state, { series = null, now = Date.now() } = {}) {
  const remaining = remainingOf(state);
  const exploded = state.phase === "exploded";
  return {
    gameId: state.gameId,
    round: state.round ?? 1,
    slots: state.slots,
    pickedSlots: [...state.pickedSlots],
    stabs: (state.stabs ?? []).map((s) => ({ ...s })),
    players: [...state.players],
    firstTurn: state.firstTurn,
    currentTurn: state.currentTurn,
    phase: state.phase,
    remaining,
    riskPct: riskPct(remaining),
    timeouts: { ...(state.timeouts ?? {}) },
    turnDeadline: state.turnDeadline,
    turnMs: PIRATE_TURN_MS,
    bombSlot: exploded ? state.bombSlot : null,
    winner: state.winner,
    loser: state.loser,
    reason: state.reason,
    penalty: state.penalty ? { ...state.penalty } : null,
    seq: state.seq ?? 0,
    series,
    serverNow: now,
  };
}
