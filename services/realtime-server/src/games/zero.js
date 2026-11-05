// 제로 2.0 게임 모듈. 이벤트 계약: docs/socket-events/zero.md
//
// 두 사람이 라운드마다 손가락 0~5개와 합계 예측(내 숫자 ~ 내 숫자+5)을 동시에 낸다.
// 둘 다 내면(또는 라운드 시간이 지나 자동 선택되면) 공개하고 점수를 더한다.
// 5라운드 합산 + 서든데스(zero-engine.js). 연속 자동 선택 3번이면 기권패.
import {
  ZERO_REGULATION_ROUNDS,
  ZERO_SUDDEN_DEATH_CAP,
  applyZeroRound,
  guessRange,
  randomZeroPick,
  resolveZeroRound,
  validateZeroPick,
} from "../zero-engine.js";

export const ZERO_GAME_TYPE = "zero";
/** 한 라운드 선택 시간. */
export const ZERO_TURN_MS = 20_000;
/** 공개 연출(두구두구 → 손 펼침 → 계산 → 점수) 동안은 다음 라운드 시간을 세지 않는다. */
export const ZERO_REVEAL_MS = 6_000;
/** 재대결 직후 첫 라운드 전 여유. */
export const ZERO_RESTART_INTRO_MS = 1_500;
export const ZERO_AUTO_FORFEIT = 3;
const STATE_TTL_SEC = 3600;

const stateKey = (roomCode) => `game:${roomCode}:zero`;
const lastKey = (roomCode) => `zero:${roomCode}:last`;

// 방별 라운드 타이머. 콜백은 예약할 때의 kit을 쓴다.
const timers = new Map();
let random = Math.random;

/** 테스트용: 자동 선택의 무작위를 바꾼다. */
export function setZeroRandom(fn) {
  random = typeof fn === "function" ? fn : Math.random;
}

function clearTimer(kit, roomCode) {
  const handle = timers.get(roomCode);
  if (!handle) return;
  timers.delete(roomCode);
  (handle.api ?? kit?.timerApi)?.clearTimeout(handle.timer);
}

async function loadState(kit, roomCode) {
  const raw = await kit.redis.get(stateKey(roomCode));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function saveState(kit, roomCode, state) {
  await kit.redis.set(stateKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);
}

/** 모두에게 보내는 모양: 이번 라운드에 누가 냈는지만 알리고 값은 숨긴다. */
export function publicZeroState(state, viewer = null) {
  const submitted = Object.fromEntries(state.players.map((p) => [p, state.picks?.[p] !== undefined]));
  const view = {
    gameId: state.gameId,
    gameType: ZERO_GAME_TYPE,
    status: state.status,
    players: state.players,
    round: state.round,
    maxRounds: state.maxRounds,
    suddenDeath: state.suddenDeath,
    suddenDeathRounds: state.suddenDeathRounds,
    suddenDeathCap: state.suddenDeathCap,
    scores: state.scores,
    submitted,
    autoPicks: state.autoPicks,
    turnDeadline: state.turnDeadline,
    turnMs: ZERO_TURN_MS,
    revealUntil: state.revealUntil ?? null,
    lastRound: state.history.at(-1) ?? null,
    history: state.history,
    result: state.result ?? null,
    series: state.series ?? null,
    serverNow: Date.now(),
  };
  const mine = viewer ? state.picks?.[viewer] : null;
  if (mine) view.myPick = { fingers: mine.fingers, guess: mine.guess };
  return view;
}

function emitState(kit, roomCode, state) {
  kit.io.to(roomCode).emit("game:zero:state", publicZeroState(state));
}

function matchOf(state) {
  return {
    round: state.round,
    scores: state.players.map((p) => state.scores[p] ?? 0),
    suddenDeath: state.suddenDeath,
    suddenDeathRounds: state.suddenDeathRounds,
    finished: state.status === "finished",
    winner: null,
    reason: null,
  };
}

function scheduleRound(kit, roomCode, state) {
  clearTimer(kit, roomCode);
  if (state.status !== "playing") return;
  const { gameId, round } = state;
  const delay = Math.max(0, state.turnDeadline - Date.now());
  const api = kit.timerApi;
  const timer = api.setTimeout(() => {
    if (timers.get(roomCode)?.timer === timer) timers.delete(roomCode);
    void kit
      .withRoomLock(roomCode, () => onDeadline(kit, roomCode, gameId, round))
      .catch((err) => console.error(`[zero] deadline failed: ${err.message}`));
  }, delay);
  timer?.unref?.();
  timers.set(roomCode, { timer, api });
}

function newGame({ players, gameId, firstDeadline, series }) {
  return {
    gameId,
    players,
    status: "playing",
    round: 1,
    maxRounds: ZERO_REGULATION_ROUNDS,
    suddenDeath: false,
    suddenDeathRounds: 0,
    suddenDeathCap: ZERO_SUDDEN_DEATH_CAP,
    scores: Object.fromEntries(players.map((p) => [p, 0])),
    picks: {},
    autoPicks: Object.fromEntries(players.map((p) => [p, 0])),
    history: [],
    turnDeadline: firstDeadline,
    revealUntil: null,
    result: null,
    series,
    createdAt: Date.now(),
  };
}

async function beginGame(kit, roomCode, { players, gameId, firstDeadline }) {
  const series = await kit.series.get(roomCode, ZERO_GAME_TYPE, players);
  const state = newGame({ players, gameId, firstDeadline, series });
  await saveState(kit, roomCode, state);
  emitState(kit, roomCode, state);
  scheduleRound(kit, roomCode, state);
  return state;
}

async function finishGame(kit, roomCode, state, { winner, reason, loser = null }) {
  clearTimer(kit, roomCode);
  state.status = "finished";
  state.turnDeadline = null;
  state.picks = {};
  state.result = {
    winner: winner && winner !== "draw" ? winner : null,
    loser: loser ?? (winner && winner !== "draw" ? state.players.find((p) => p !== winner) : null),
    draw: !winner || winner === "draw",
    reason,
    scores: { ...state.scores },
  };
  state.series = await kit.series.record(roomCode, ZERO_GAME_TYPE, state.players, state.result.winner);
  await saveState(kit, roomCode, state);
  await kit.redis.set(
    lastKey(roomCode),
    JSON.stringify({ players: state.players, gameId: state.gameId, finishedAt: Date.now() }),
    "EX",
    STATE_TTL_SEC,
  );
  await kit.recordGameOutcome(roomCode, {
    winner: state.result.winner ?? "draw",
    players: state.players,
    gameType: ZERO_GAME_TYPE,
    gameId: state.gameId,
  });
}

/** 두 사람의 선택이 모두 모였을 때: 판정 → 기록 → 공개 → 다음 라운드 또는 종료. */
async function resolveRound(kit, roomCode, state) {
  const [p1, p2] = state.players;
  const pick1 = state.picks[p1];
  const pick2 = state.picks[p2];
  const r = resolveZeroRound(pick1, pick2);
  const winnerId = r.roundWinner === "p1" ? p1 : r.roundWinner === "p2" ? p2 : "draw";
  const match = applyZeroRound(matchOf(state), r);
  state.scores = { [p1]: match.scores[0], [p2]: match.scores[1] };
  const record = {
    round: state.round,
    suddenDeath: state.suddenDeath,
    fingers: { [p1]: pick1.fingers, [p2]: pick2.fingers },
    guesses: { [p1]: pick1.guess, [p2]: pick2.guess },
    total: r.total,
    distance: { [p1]: r.distance[0], [p2]: r.distance[1] },
    exact: { [p1]: r.exact[0], [p2]: r.exact[1] },
    points: { [p1]: r.points[0], [p2]: r.points[1] },
    auto: { [p1]: Boolean(pick1.auto), [p2]: Boolean(pick2.auto) },
    roundWinner: winnerId,
    scores: { ...state.scores },
  };
  state.history = [...state.history, record];
  state.picks = {};
  state.round = match.round;
  state.suddenDeath = match.suddenDeath;
  state.suddenDeathRounds = match.suddenDeathRounds;
  const now = Date.now();
  state.revealUntil = now + ZERO_REVEAL_MS;

  // 연속 자동 선택 3번이면 기권패(둘 다면 무승부).
  const afk = state.players.filter((p) => (state.autoPicks[p] ?? 0) >= ZERO_AUTO_FORFEIT);
  if (match.finished) {
    await finishGame(kit, roomCode, state, {
      winner: match.winner === "p1" ? p1 : match.winner === "p2" ? p2 : "draw",
      reason: match.reason,
    });
  } else if (afk.length === 1) {
    const loser = afk[0];
    await finishGame(kit, roomCode, state, { winner: state.players.find((p) => p !== loser), loser, reason: "forfeit" });
  } else if (afk.length === 2) {
    await finishGame(kit, roomCode, state, { winner: "draw", reason: "both_away" });
  } else {
    state.turnDeadline = state.revealUntil + ZERO_TURN_MS;
    await saveState(kit, roomCode, state);
    scheduleRound(kit, roomCode, state);
  }

  kit.io.to(roomCode).emit("game:zero:round_result", {
    gameId: state.gameId,
    mode: "zero",
    ...record,
    maxRounds: state.maxRounds,
    history: state.history,
    gameWinner: state.status === "finished" ? (state.result.winner ?? "draw") : null,
    result: state.result,
    series: state.series,
    nextRound: state.status === "playing" ? state.round : null,
    nextSuddenDeath: state.suddenDeath,
    turnDeadline: state.turnDeadline,
    serverNow: now,
  });
  emitState(kit, roomCode, state);
}

async function onDeadline(kit, roomCode, gameId, round) {
  const state = await loadState(kit, roomCode);
  if (!state || state.status !== "playing" || state.gameId !== gameId || state.round !== round) return;
  if (Date.now() < state.turnDeadline) {
    scheduleRound(kit, roomCode, state);
    return;
  }
  for (const p of state.players) {
    if (state.picks[p] !== undefined) continue;
    state.picks[p] = { ...randomZeroPick(random), auto: true };
    state.autoPicks[p] = (state.autoPicks[p] ?? 0) + 1;
  }
  await resolveRound(kit, roomCode, state);
}

async function forfeitGame(kit, roomCode, state, loser, winner) {
  await finishGame(kit, roomCode, state, { winner, loser, reason: "forfeit" });
  emitState(kit, roomCode, state);
}

const zero = {
  gameType: ZERO_GAME_TYPE,
  lobbyType: ZERO_GAME_TYPE,

  register(socket, kit) {
    socket.on("game:zero:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const state = await loadState(kit, roomCode);
      if (!state || !state.players.includes(userId)) return ack({ ok: true, state: null });
      const view = publicZeroState(state, userId);
      socket.emit("game:zero:state", view);
      return ack({ ok: true, state: view });
    });

    socket.on("game:zero:pick", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const fingers = payload?.fingers;
      const guess = payload?.guess;
      const check = validateZeroPick({ fingers, guess });
      if (check === "invalid_fingers") return ack({ ok: false, reason: "invalid_payload" });
      if (check === "invalid_guess") {
        return ack({ ok: false, reason: "invalid_guess", range: Number.isInteger(fingers) ? guessRange(fingers) : null });
      }
      await kit.withRoomLock(roomCode, async () => {
        const state = await loadState(kit, roomCode);
        if (!state) return ack({ ok: false, reason: "no_game" });
        if (!state.players.includes(userId)) return ack({ ok: false, reason: "not_a_player" });
        if (state.status !== "playing") return ack({ ok: false, reason: "game_over" });
        if (payload?.round !== undefined && payload.round !== state.round) {
          return ack({ ok: false, reason: "stale_round", round: state.round });
        }
        if (state.picks[userId] !== undefined) return ack({ ok: true, already: true, round: state.round });
        state.picks[userId] = { fingers, guess };
        state.autoPicks[userId] = 0;
        const round = state.round;
        if (state.players.every((p) => state.picks[p] !== undefined)) {
          await resolveRound(kit, roomCode, state);
        } else {
          await saveState(kit, roomCode, state);
          emitState(kit, roomCode, state);
        }
        return ack({ ok: true, round });
      });
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    await kit.withRoomLock(roomCode, async () => {
      const players = ctx.players.slice(0, 2);
      await beginGame(kit, roomCode, {
        players,
        gameId: ctx.gameId ?? kit.randomUUID(),
        firstDeadline: (ctx.startsAt ?? Date.now()) + ZERO_TURN_MS,
      });
    });
  },

  async restart(roomCode, kit, ctx) {
    const previous = await loadState(kit, roomCode);
    const players = previous?.players?.length === 2 &&
      previous.players.every((p) => ctx.orderedPlayers.includes(p))
      ? previous.players
      : [ctx.p1, ctx.p2];
    await beginGame(kit, roomCode, {
      players,
      gameId: kit.randomUUID(),
      firstDeadline: Date.now() + ZERO_RESTART_INTRO_MS + ZERO_TURN_MS,
    });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const state = await loadState(kit, roomCode);
    if (!state || !state.players.includes(userId)) return false;
    socket.emit("game:zero:state", publicZeroState(state, userId));
    if (state.status !== "playing") return false;
    // 서버가 재시작돼 타이머가 사라졌으면 다시 건다.
    if (!timers.has(roomCode)) scheduleRound(kit, roomCode, state);
    return true;
  },

  afk(kit) {
    return {
      key: stateKey,
      playersOf: (s) => s.players ?? [],
      // 한 사람만 냈을 때 나머지를 기다린다. 라운드 타이머(20초)가 보통 먼저 자동 선택한다.
      waitingOn: (s) => {
        if (s.status !== "playing") return null;
        const missing = (s.players ?? []).filter((p) => s.picks?.[p] === undefined);
        return missing.length === 1 ? missing[0] : null;
      },
      forfeit: async (roomCode, s, loser, winner) => {
        if (s.status !== "playing") return;
        await forfeitGame(kit, roomCode, s, loser, winner);
      },
    };
  },

  dispose() {
    for (const [roomCode, handle] of [...timers]) {
      timers.delete(roomCode);
      handle.api?.clearTimeout(handle.timer);
    }
  },
};

export default zero;
