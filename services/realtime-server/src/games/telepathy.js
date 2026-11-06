// 텔레파시 2.0 게임 모듈. 이벤트 계약: docs/socket-events/telepathy.md
//
// 밸런스 게임: 문제마다 A·B 중 하나를 둘이 몰래 고르고, 둘 다 고르면(또는 15초가 지나면)
// 함께 공개한다. 같은 쪽이면 "통했다". 서버가 문항·라운드·점수를 모두 가지고,
// 클라이언트는 `pick {round, choice}`만 보낸다. 협동 게임이라 승패 기록은 없고
// 방 시리즈(통한 비율·최고 연속)만 남긴다. 문제는 방별 셔플 가방에서 꺼낸다(1년 보관).
import { normalizeLobbyOptions } from "../lobby-options.js";
import { SERIES_TTL_SEC } from "./series.js";
import {
  TELEPATHY_BANK,
  TELEPATHY_CHOICES,
  applyTelepathySeries,
  drawQuestions,
  emptyBag,
  emptyTelepathySeries,
  judge,
  summary,
} from "../telepathy-engine.js";

export const TELEPATHY_GAME_TYPE = "telepathy";
/** 한 문제 선택 시간. */
export const TELEPATHY_TURN_MS = 15_000;
/** 공개 연출(동시 뒤집기 → 빛줄기) 동안은 다음 문제 시간을 세지 않는다. */
export const TELEPATHY_REVEAL_MS = 3_500;
/** 재대결 직후 첫 문제 전 여유. */
export const TELEPATHY_RESTART_INTRO_MS = 1_500;
/** 연속 시간 초과 몇 번이면 판을 마치는지. */
export const TELEPATHY_TIMEOUT_LIMIT = 3;
export const TELEPATHY_BAG_TTL_SEC = 365 * 24 * 3600;
const STATE_TTL_SEC = 3600;

const stateKey = (roomCode) => `game:${roomCode}:telepathy`;
const bagKey = (roomCode) => `telepathy:${roomCode}:bag`;
const seriesKey = (roomCode) => `telepathy:${roomCode}:series`;
const lastKey = (roomCode) => `telepathy:${roomCode}:last`;

// 방별 문제 타이머. 콜백은 예약할 때의 kit을 쓴다.
const timers = new Map();
let random = Math.random;
let bank = TELEPATHY_BANK;

/** 테스트용: 문제 뽑기의 무작위를 바꾼다. */
export function setTelepathyRandom(fn) {
  random = typeof fn === "function" ? fn : Math.random;
}

/** 테스트용: 문제 은행을 바꾼다(null이면 원래 은행). */
export function setTelepathyBank(next) {
  bank = Array.isArray(next) ? next : TELEPATHY_BANK;
}

const readJson = async (kit, key) => {
  const raw = await kit.redis.get(key);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
};

const loadState = (kit, roomCode) => readJson(kit, stateKey(roomCode));

async function saveState(kit, roomCode, state) {
  await kit.redis.set(stateKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);
}

async function loadSeries(kit, roomCode) {
  return { ...emptyTelepathySeries(), ...((await readJson(kit, seriesKey(roomCode))) ?? {}) };
}

function clearTimer(kit, roomCode) {
  const handle = timers.get(roomCode);
  if (!handle) return;
  timers.delete(roomCode);
  (handle.api ?? kit?.timerApi)?.clearTimeout(handle.timer);
}

const publicQuestion = (q) => (q ? { id: q.id, cat: q.cat, a: q.a, b: q.b, emojiA: q.emojiA, emojiB: q.emojiB, spicy: q.spicy } : null);

/** 모두에게 보내는 모양: 누가 골랐는지만 알리고 값은 숨긴다. 앞으로 나올 문제도 숨긴다. */
export function publicTelepathyState(state, viewer = null) {
  const playing = state.status === "playing";
  const picked = Object.fromEntries(state.players.map((p) => [p, state.picks?.[p] !== undefined]));
  const view = {
    gameId: state.gameId,
    gameType: TELEPATHY_GAME_TYPE,
    status: state.status,
    players: state.players,
    round: state.round,
    rounds: state.rounds,
    spicy: state.spicy,
    question: playing ? publicQuestion(state.questions[state.round - 1]) : null,
    picked,
    timeouts: state.timeouts,
    turnDeadline: playing ? state.turnDeadline : null,
    turnMs: TELEPATHY_TURN_MS,
    revealUntil: state.revealUntil ?? null,
    revealMs: TELEPATHY_REVEAL_MS,
    score: state.score,
    streak: state.streak,
    bestStreak: state.bestStreak,
    lastRound: state.history.at(-1) ?? null,
    history: state.history,
    result: state.result ?? null,
    series: state.series ?? null,
    serverNow: Date.now(),
  };
  const mine = viewer ? state.picks?.[viewer] : undefined;
  if (playing && mine !== undefined) view.myPick = mine;
  return view;
}

function emitState(kit, roomCode, state) {
  kit.io.to(roomCode).emit("game:telepathy:state", publicTelepathyState(state));
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
      .catch((err) => console.error(`[telepathy] deadline failed: ${err.message}`));
  }, delay);
  timer?.unref?.();
  timers.set(roomCode, { timer, api });
}

/** 방 가방에서 이번 판 문제를 꺼내고 가방을 저장한다(1년). */
async function drawForRoom(kit, roomCode, rounds, spicy) {
  const bag = (await readJson(kit, bagKey(roomCode))) ?? emptyBag();
  const drawn = drawQuestions(bag, bank, rounds, { spicy, random });
  await kit.redis.set(bagKey(roomCode), JSON.stringify(drawn.bag), "EX", TELEPATHY_BAG_TTL_SEC);
  return drawn.questions;
}

async function beginGame(kit, roomCode, { players, gameId, firstDeadline, rounds, spicy }) {
  clearTimer(kit, roomCode);
  const questions = await drawForRoom(kit, roomCode, rounds, spicy);
  const state = {
    gameId,
    players,
    status: "playing",
    rounds: questions.length,
    spicy,
    round: 1,
    questions: questions.map(publicQuestion),
    picks: {},
    timeouts: Object.fromEntries(players.map((p) => [p, 0])),
    bothTimeouts: 0,
    history: [],
    score: 0,
    streak: 0,
    bestStreak: 0,
    turnDeadline: firstDeadline,
    revealUntil: null,
    result: null,
    series: await loadSeries(kit, roomCode),
    createdAt: Date.now(),
  };
  await saveState(kit, roomCode, state);
  await kit.redis.set(lastKey(roomCode), JSON.stringify({ players, rounds, spicy }), "EX", SERIES_TTL_SEC);
  emitState(kit, roomCode, state);
  scheduleRound(kit, roomCode, state);
  return state;
}

/** 판을 마친다. 끝까지 푼 판만 시리즈에 더한다(잠수로 끝난 판은 비율을 흐리지 않게). */
async function finishGame(kit, roomCode, state, { reason, awayPlayer = null }) {
  clearTimer(kit, roomCode);
  const s = summary(state.history, state.rounds);
  state.status = "finished";
  state.turnDeadline = null;
  state.picks = {};
  state.result = {
    reason,
    awayPlayer,
    matches: s.matches,
    total: state.rounds,
    played: s.played,
    bestStreak: s.bestStreak,
    tier: s.tier,
  };
  if (reason === "complete") {
    state.series = applyTelepathySeries(await loadSeries(kit, roomCode), s);
    await kit.redis.set(seriesKey(roomCode), JSON.stringify(state.series), "EX", SERIES_TTL_SEC);
  } else {
    state.series = await loadSeries(kit, roomCode);
  }
  await saveState(kit, roomCode, state);
}

/** 두 사람 선택이 모였거나 마감이 지났을 때: 판정 → 기록 → 다음 문제 또는 종료. */
async function resolveRound(kit, roomCode, state) {
  const [p1, p2] = state.players;
  const picks = { [p1]: state.picks[p1] ?? null, [p2]: state.picks[p2] ?? null };
  const verdict = judge(picks[p1], picks[p2]);
  for (const p of state.players) state.timeouts[p] = picks[p] === null ? (state.timeouts[p] ?? 0) + 1 : 0;
  state.bothTimeouts = picks[p1] === null && picks[p2] === null ? state.bothTimeouts + 1 : 0;
  state.streak = verdict.matched ? state.streak + 1 : 0;
  state.bestStreak = Math.max(state.bestStreak, state.streak);
  if (verdict.matched) state.score += 1;
  const now = Date.now();
  state.history = [
    ...state.history,
    {
      round: state.round,
      question: state.questions[state.round - 1],
      picks,
      matched: verdict.matched,
      outcome: verdict.outcome,
      streak: state.streak,
      score: state.score,
    },
  ];
  state.picks = {};
  state.revealUntil = now + TELEPATHY_REVEAL_MS;

  const away = state.players.filter((p) => state.timeouts[p] >= TELEPATHY_TIMEOUT_LIMIT);
  if (state.bothTimeouts >= TELEPATHY_TIMEOUT_LIMIT || away.length === 2) {
    await finishGame(kit, roomCode, state, { reason: "both_away" });
  } else if (away.length === 1) {
    await finishGame(kit, roomCode, state, { reason: "away", awayPlayer: away[0] });
  } else if (state.round >= state.rounds) {
    await finishGame(kit, roomCode, state, { reason: "complete" });
  } else {
    state.round += 1;
    state.turnDeadline = state.revealUntil + TELEPATHY_TURN_MS;
    await saveState(kit, roomCode, state);
    scheduleRound(kit, roomCode, state);
  }
  emitState(kit, roomCode, state);
}

async function onDeadline(kit, roomCode, gameId, round) {
  const state = await loadState(kit, roomCode);
  if (!state || state.status !== "playing" || state.gameId !== gameId || state.round !== round) return;
  if (Date.now() < state.turnDeadline) {
    scheduleRound(kit, roomCode, state);
    return;
  }
  await resolveRound(kit, roomCode, state);
}

function previousSettings(previous, last) {
  const src = previous ?? last ?? {};
  const options = normalizeLobbyOptions(TELEPATHY_GAME_TYPE, {
    rounds: src.rounds,
    spicy: src.spicy === true ? "on" : src.spicy === false ? "off" : src.spicy,
  });
  return { rounds: options.rounds, spicy: options.spicy === "on" };
}

const telepathy = {
  gameType: TELEPATHY_GAME_TYPE,
  lobbyType: TELEPATHY_GAME_TYPE,

  register(socket, kit) {
    socket.on("game:telepathy:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const state = await loadState(kit, roomCode);
      if (!state || !state.players.includes(userId)) return ack({ ok: true, state: null });
      const view = publicTelepathyState(state, userId);
      socket.emit("game:telepathy:state", view);
      return ack({ ok: true, state: view });
    });

    socket.on("game:telepathy:pick", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const choice = payload?.choice;
      if (!TELEPATHY_CHOICES.includes(choice)) return ack({ ok: false, reason: "invalid_payload" });
      if (payload?.round !== undefined && !Number.isInteger(payload.round)) {
        return ack({ ok: false, reason: "invalid_payload" });
      }
      await kit.withRoomLock(roomCode, async () => {
        const state = await loadState(kit, roomCode);
        if (!state) return ack({ ok: false, reason: "no_game" });
        if (!state.players.includes(userId)) return ack({ ok: false, reason: "not_a_player" });
        // 지난 판 화면에서 보낸 선택은 새 판에 섞이지 않는다.
        if (payload?.gameId !== undefined && payload.gameId !== state.gameId) {
          return ack({ ok: false, reason: "stale_game", gameId: state.gameId });
        }
        if (state.status !== "playing") return ack({ ok: false, reason: "game_over" });
        if (payload?.round !== undefined && payload.round !== state.round) {
          return ack({ ok: false, reason: "stale_round", round: state.round });
        }
        const existing = state.picks[userId];
        if (existing !== undefined) return ack({ ok: true, already: true, round: state.round, choice: existing });
        state.picks[userId] = choice;
        const round = state.round;
        if (state.players.every((p) => state.picks[p] !== undefined)) {
          await resolveRound(kit, roomCode, state);
        } else {
          await saveState(kit, roomCode, state);
          emitState(kit, roomCode, state);
        }
        return ack({ ok: true, round, choice });
      });
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    const options = normalizeLobbyOptions(TELEPATHY_GAME_TYPE, ctx.options);
    await kit.withRoomLock(roomCode, async () => {
      await beginGame(kit, roomCode, {
        players: ctx.players.slice(0, 2),
        gameId: ctx.gameId ?? kit.randomUUID(),
        firstDeadline: (ctx.startsAt ?? Date.now()) + TELEPATHY_TURN_MS,
        rounds: options.rounds,
        spicy: options.spicy === "on",
      });
    });
  },

  // 재대결: socket.js가 방 잠금 안에서 부른다. 끝난 판의 문제 수·매운맛 설정을 잇는다.
  async restart(roomCode, kit, ctx) {
    const previous = await loadState(kit, roomCode);
    const last = await readJson(kit, lastKey(roomCode));
    const known = previous?.players ?? last?.players;
    const players = known?.length === 2 && known.every((p) => ctx.orderedPlayers.includes(p))
      ? known
      : [ctx.p1, ctx.p2];
    await beginGame(kit, roomCode, {
      players,
      gameId: kit.randomUUID(),
      firstDeadline: Date.now() + TELEPATHY_RESTART_INTRO_MS + TELEPATHY_TURN_MS,
      ...previousSettings(previous, last),
    });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const state = await loadState(kit, roomCode);
    if (!state || !state.players.includes(userId)) return false;
    socket.emit("game:telepathy:state", publicTelepathyState(state, userId));
    if (state.status !== "playing") return false;
    // 서버가 다시 시작돼 타이머가 사라졌으면 다시 건다.
    if (!timers.has(roomCode)) scheduleRound(kit, roomCode, state);
    return true;
  },

  afk(kit) {
    return {
      key: stateKey,
      playersOf: (s) => s.players ?? [],
      // 한 사람만 골랐을 때 나머지를 기다린다. 보통은 15초 마감이 먼저 다음 문제로 넘긴다.
      waitingOn: (s) => {
        if (s.status !== "playing") return null;
        const missing = (s.players ?? []).filter((p) => s.picks?.[p] === undefined);
        return missing.length === 1 ? missing[0] : null;
      },
      forfeit: async (roomCode, s, loser) => {
        if (s.status !== "playing") return;
        await finishGame(kit, roomCode, s, { reason: "away", awayPlayer: loser });
        emitState(kit, roomCode, s);
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

export default telepathy;
