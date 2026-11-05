// 패널티킥 2.0 게임 모듈. 소켓 계약은 docs/socket-events/penalty.md.
//
// 서버가 로비 시작과 함께 판을 만들고(startFromLobby), 화면은 game:penalty:sync로
// 현재 상태를 받는다. 고르기는 game:penalty:submit { choice }. 상태는 언제나
// game:penalty:state(공개 투영 + serverNow)로 방 전체에 보낸다.
import { normalizeLobbyOptions } from "../lobby-options.js";
import {
  autoPickMissing,
  forfeitPenalty,
  initPenaltyGame,
  isLegacyPenaltyState,
  maskPenaltyState,
  normalizeCells,
  submitPenaltyChoice,
} from "../penalty-engine.js";

const GAME_TYPE = "penalty";
const STATE_TTL_SEC = 3600;
/** 재대결은 로비 카운트다운이 없으니 화면이 바뀔 짧은 여유만 준다. */
const RESTART_LEAD_MS = 1500;

const stateKey = (roomCode) => `game:${roomCode}:penalty`;

// roomCode → { handle, api, gameId, round }
const turnTimers = new Map();

function clearTurnTimer(roomCode) {
  const entry = turnTimers.get(roomCode);
  if (!entry) return;
  entry.api.clearTimeout(entry.handle);
  turnTimers.delete(roomCode);
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

/** 옛 형식이면 지우고 null. */
async function loadCurrentState(kit, roomCode) {
  const state = await loadState(kit, roomCode);
  if (state && isLegacyPenaltyState(state)) {
    await kit.redis.del(stateKey(roomCode));
    clearTurnTimer(roomCode);
    return null;
  }
  return state;
}

const saveState = (kit, roomCode, state) =>
  kit.redis.set(stateKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);

const publicState = (state) => ({ ...maskPenaltyState(state), serverNow: Date.now() });

function emitState(kit, roomCode, state) {
  kit.io.to(roomCode).emit("game:penalty:state", publicState(state));
}

/** 끝난 판: 전적·결과 기록 후 방송. 상태는 재대결(칸 수·선공 교대)을 위해 남겨 둔다. */
async function finishGame(kit, roomCode, state) {
  clearTurnTimer(roomCode);
  const winner = state.result?.winner;
  const decisive = winner && winner !== "draw" ? winner : null;
  const abandoned = state.result?.reason === "abandoned";
  let finished = state;
  if (!abandoned) {
    const series = await kit.series.record(roomCode, GAME_TYPE, state.players, decisive);
    finished = { ...state, series };
  }
  await saveState(kit, roomCode, finished);
  emitState(kit, roomCode, finished);
  if (!abandoned) {
    await kit.recordGameOutcome(roomCode, {
      winner: decisive,
      players: state.players,
      gameType: GAME_TYPE,
      gameId: state.gameId,
    });
  }
  return finished;
}

/** 진행 중인 판의 마감 타이머를 건다(같은 판·같은 킥이면 그대로 둔다). */
function scheduleTurnTimer(kit, roomCode, state) {
  if (!state || state.status !== "playing" || !state.turnDeadline) {
    clearTurnTimer(roomCode);
    return;
  }
  const existing = turnTimers.get(roomCode);
  if (existing && existing.gameId === state.gameId && existing.round === state.round) return;
  clearTurnTimer(roomCode);
  const entry = { api: kit.timerApi, gameId: state.gameId, round: state.round, handle: null };
  entry.handle = kit.timerApi.setTimeout(() => {
    if (turnTimers.get(roomCode) === entry) turnTimers.delete(roomCode);
    void kit
      .withRoomLock(roomCode, () => onDeadline(kit, roomCode, entry))
      .catch((err) => console.error(`[penalty] deadline failed: ${err.message}`));
  }, Math.max(0, state.turnDeadline - Date.now()));
  entry.handle.unref?.();
  turnTimers.set(roomCode, entry);
}

async function onDeadline(kit, roomCode, entry) {
  const state = await loadCurrentState(kit, roomCode);
  if (!state || state.status !== "playing") return;
  // 그사이 판정이 끝나 다음 킥이 되었거나 새 판이 시작됐으면 이 타이머는 낡았다.
  if (state.gameId !== entry.gameId || state.round !== entry.round) return;
  if (Date.now() < state.turnDeadline) {
    scheduleTurnTimer(kit, roomCode, state);
    return;
  }
  const { game } = autoPickMissing(state, { random: penalty.random, now: Date.now() });
  if (game.status === "finished") {
    await finishGame(kit, roomCode, game);
    return;
  }
  await saveState(kit, roomCode, game);
  emitState(kit, roomCode, game);
  scheduleTurnTimer(kit, roomCode, game);
}

async function createGame(kit, roomCode, players, { cells, gameId, firstKicker = null, startsAt }) {
  clearTurnTimer(roomCode);
  const series = await kit.series.get(roomCode, GAME_TYPE, players);
  const state = initPenaltyGame(players[0], players[1], {
    cells: normalizeCells(cells),
    random: penalty.random,
    gameId,
    firstKicker,
    now: Date.now(),
    startsAt,
    series,
  });
  await saveState(kit, roomCode, state);
  emitState(kit, roomCode, state);
  scheduleTurnTimer(kit, roomCode, state);
  return state;
}

const isPlayer = (state, userId) => Array.isArray(state?.players) && state.players.includes(String(userId));

const penalty = {
  gameType: GAME_TYPE,
  /** 선공·자동 선택용 난수. 테스트가 바꿔 끼운다. */
  random: Math.random,

  register(socket, kit) {
    socket.on("game:penalty:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      await kit.withRoomLock(roomCode, async () => {
        const state = await loadCurrentState(kit, roomCode);
        if (!state || !isPlayer(state, userId)) return ack({ ok: true, state: null });
        scheduleTurnTimer(kit, roomCode, state);
        const view = publicState(state);
        socket.emit("game:penalty:state", view);
        ack({ ok: true, state: view });
      });
    });

    socket.on("game:penalty:submit", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      await kit.withRoomLock(roomCode, async () => {
        const state = await loadCurrentState(kit, roomCode);
        if (!state) return ack({ ok: false, reason: "no_game" });
        const result = submitPenaltyChoice(state, userId, payload?.choice, { now: Date.now() });
        if (!result.ok) return ack({ ok: false, reason: result.reason });
        const next = result.game;
        if (next.status === "finished") {
          await finishGame(kit, roomCode, next);
        } else {
          await saveState(kit, roomCode, next);
          emitState(kit, roomCode, next);
          scheduleTurnTimer(kit, roomCode, next);
        }
        ack({ ok: true, resolved: result.resolved });
      });
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    const { cells } = normalizeLobbyOptions(GAME_TYPE, ctx.options);
    await createGame(kit, roomCode, ctx.players.map(String), {
      cells,
      gameId: ctx.gameId ?? kit.randomUUID(),
      startsAt: ctx.startsAt ?? Date.now(),
    });
  },

  async restart(roomCode, kit, ctx) {
    const previous = await loadState(kit, roomCode);
    const players = [String(ctx.p1), String(ctx.p2)];
    const legacy = !previous || isLegacyPenaltyState(previous);
    const cells = legacy ? undefined : previous.cells;
    // 선공 교대: 지난 판의 첫 킥커가 아닌 사람이 먼저 찬다.
    const lastFirst = legacy ? null : previous.firstKicker;
    const firstKicker = players.includes(lastFirst) ? players.find((p) => p !== lastFirst) : null;
    await createGame(kit, roomCode, players, {
      cells,
      gameId: kit.randomUUID(),
      firstKicker,
      startsAt: Date.now() + RESTART_LEAD_MS,
    });
  },

  async restore(roomCode, socket, kit) {
    const state = await loadCurrentState(kit, roomCode);
    if (!state || state.status !== "playing" || !isPlayer(state, socket.data.userId)) return false;
    scheduleTurnTimer(kit, roomCode, state);
    socket.emit("game:penalty:state", publicState(state));
    return true;
  },

  afk(kit) {
    return {
      key: stateKey,
      playersOf: (s) => s.players ?? Object.keys(s.scores ?? {}),
      // 안전망: 자체 20초 타이머가 먼저 자동 선택한다. 한 사람만 냈는데 타이머가
      // 사라진 경우(서버 재시작 등)에만 60초 경고·90초 기권이 동작한다.
      waitingOn: (s) => {
        if (s.status !== "playing") return null;
        const missing = [String(s.kicker), String(s.keeper)].filter((p) => s.submissions?.[p] === undefined);
        return missing.length === 1 ? missing[0] : null;
      },
      forfeit: async (roomCode, s, loser) => {
        if (s.status !== "playing" || isLegacyPenaltyState(s)) return;
        await finishGame(kit, roomCode, forfeitPenalty(s, loser));
      },
    };
  },

  dispose() {
    for (const roomCode of [...turnTimers.keys()]) clearTurnTimer(roomCode);
  },
};

export default penalty;
