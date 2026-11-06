// 고스톱(2인 맞고) 2.0 게임 모듈. 규칙은 gostop-engine.js(순수 함수), 여기는 소켓 흐름·서버 타이머·정산.
// 계약: docs/socket-events/gostop.md
//
// - 로비 시작과 함께 서버가 판을 만든다(startFromLobby). 화면은 game:gostop:sync로 상태를 받는다.
// - 상태가 바뀔 때마다 25초 마감(turnDeadline)을 다시 걸고, 만료되면 서버가 단계별 자동 행동을 한다:
//   패 = 코치 추천(흔들기 안 함), 두 장 선택 = 점수 높은 쪽, 고/스톱 = 스톱, 총통 = 선언.
//   같은 사람이 연속 3번 자동 처리되면 기권패(고/스톱 단계는 예외: 이기던 사람은 항상 스톱으로 이긴다).
// - 끝(스톱·자동 스톱·총통·기권·나가리)은 finishGostopGame 하나로:
//   끝난 상태 알림 → 정산(1점당 판돈 × 점수 × 배수, try/finally) → recordGameOutcome(gameId) → 전적 →
//   상태 삭제 + :last 요약 → game:gostop:ended(영수증의 transferred = 실제로 옮겨진 코인).
import { viewerRoomKey } from "../game-session.js";
import {
  GOSTOP_VERSION,
  applyAuto,
  choose,
  createGostopGameState,
  decideChongtong,
  declare,
  forfeit,
  playBomb,
  playCard,
  playDotan,
  serializeFor,
} from "../gostop-engine.js";

export const GAME_TYPE = "gostop";
export const TURN_MS = 25_000;
export const AUTO_FORFEIT_STREAK = 3;
export const STATE_TTL_SEC = 7200;
export const LAST_TTL_SEC = 3600;
// 1점당 판돈(로비 선택지와 같다). 그 밖의 값은 무료 판으로 만든다.
export const GOSTOP_STAKES = new Set([0, 100, 500, 1000]);
export const gostopGameKey = (roomCode) => `gostop:${roomCode}:game`;
export const gostopLastKey = (roomCode) => `gostop:${roomCode}:last`;

// 테스트가 무작위(선·셔플)를 고정할 수 있게 한 곳에 둔다.
export const gostopRuntime = { random: Math.random };

const ENDED_PHASES = new Set(["finished", "nagari"]);
const timers = new Map(); // roomCode → { handle, kit, gameId, deadline }

const clearTurnTimer = (roomCode) => {
  const entry = timers.get(roomCode);
  if (!entry) return;
  entry.kit.timerApi.clearTimeout(entry.handle);
  timers.delete(roomCode);
};

const readState = async (kit, roomCode) => {
  const raw = await kit.redis.get(gostopGameKey(roomCode));
  if (!raw) return null;
  try {
    const state = JSON.parse(raw);
    // 옛 엔진(1.x) 상태는 이어 갈 수 없다. 지우고 "판 없음"으로 본다.
    if (state?.version !== GOSTOP_VERSION) {
      await kit.redis.del(gostopGameKey(roomCode));
      return null;
    }
    return state;
  } catch {
    return null;
  }
};

const otherPlayer = (state, player) => state.players.find((p) => p !== player) ?? null;

async function emitState(kit, roomCode, state) {
  const sockets = await kit.io.in(roomCode).fetchSockets();
  for (const sock of sockets) {
    const userId = sock.data.userId;
    if (userId && state.players.includes(userId)) sock.emit("game:gostop:state", serializeFor(state, userId));
  }
}

function scheduleTurnTimer(kit, roomCode, state) {
  clearTurnTimer(roomCode);
  if (ENDED_PHASES.has(state.phase) || !state.turnDeadline) return;
  const { gameId, turnDeadline } = state;
  const handle = kit.timerApi.setTimeout(() => {
    if (timers.get(roomCode)?.handle === handle) timers.delete(roomCode);
    void kit.withRoomLock(roomCode, () => onTurnExpired(kit, roomCode, gameId, turnDeadline))
      .catch((err) => console.error(`[gostop] turn timer failed: ${err.message}`));
  }, Math.max(0, turnDeadline - Date.now()));
  handle?.unref?.();
  timers.set(roomCode, { handle, kit, gameId, deadline: turnDeadline });
}

/** 저장 + 마감시각 갱신 + 타이머 재설정. 상태가 바뀔 때마다 부른다. */
async function saveState(kit, roomCode, state, { deadline = Date.now() + TURN_MS } = {}) {
  state.turnMs = TURN_MS;
  state.turnDeadline = ENDED_PHASES.has(state.phase) ? null : deadline;
  await kit.redis.set(gostopGameKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);
  scheduleTurnTimer(kit, roomCode, state);
}

/**
 * 모든 끝의 단일 경로. state.result는 엔진이 채운 정산(점수·고·박·흔들기·폭탄·배수·금액).
 * 실제로 옮겨진 코인(상대 잔액이 모자라면 줄어든다)을 transferred로 영수증에 싣는다.
 */
export async function finishGostopGame(kit, roomCode, state) {
  clearTurnTimer(roomCode);
  state.turnDeadline = null;
  await kit.redis.set(gostopGameKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);
  // 마지막 턴 연출을 위해 끝난 상태를 먼저 보낸다.
  await emitState(kit, roomCode, state);

  const result = state.result ?? { reason: "nagari", winner: null, loser: null, amount: 0 };
  const winner = result.winner ?? null;
  const loser = winner ? otherPlayer(state, winner) : null;
  const amount = Math.max(0, Math.floor(result.amount ?? 0));
  const gameId = state.gameId ?? `legacy-${roomCode}`;
  let transferred = 0;
  let settlement = amount > 0 ? "pending" : "none";
  let series = state.series ?? null;
  try {
    if (winner && loser && amount > 0) {
      // 정산 ref는 판 id로 고정되어 멱등하다. 아이템 보너스 없이(영수증 = 실제 이동) 옮긴다.
      const wallet = await kit.settleWallet(roomCode, winner, loser, amount, `gostop:${gameId}`);
      if (wallet?.ok && wallet.result) {
        transferred = Math.max(0, Number(wallet.result.actual) || 0);
        settlement = wallet.result.alreadySettled ? "already" : transferred < amount ? "capped" : "settled";
      } else {
        settlement = "failed";
        kit.io.to(roomCode).emit("wallet:settle_failed", { gameType: GAME_TYPE, reason: wallet?.reason ?? "settle_error" });
      }
    }
    await kit.recordGameOutcome(roomCode, {
      winner: winner ?? "draw",
      players: state.players,
      gameType: GAME_TYPE,
      missionKey: GAME_TYPE,
      stake: transferred,
      gameId,
    });
    series = await kit.series.record(roomCode, GAME_TYPE, state.players, winner);
  } catch (err) {
    console.error(`[gostop] settlement failed for ${roomCode}: ${err?.message ?? err}`);
    if (settlement === "pending") {
      settlement = "failed";
      kit.io.to(roomCode).emit("wallet:settle_failed", { gameType: GAME_TYPE, reason: "settle_error" });
    }
  } finally {
    await kit.redis.del(gostopGameKey(roomCode));
    await kit.redis.set(
      gostopLastKey(roomCode),
      JSON.stringify({
        stake: state.perPointBet ?? 0,
        series,
        lastWinner: winner,
        lastStarter: state.starter ?? null,
        players: state.players,
        gameId,
      }),
      "EX",
      LAST_TTL_SEC,
    );
  }

  kit.io.to(roomCode).emit("game:gostop:ended", {
    gameId,
    reason: result.reason,
    winner,
    loser,
    receipt: { ...result, transferred, settlement },
    captures: state.captures,
    scores: state.scores,
    hands: state.hands,
    goCount: state.goCount,
    shakes: state.shakes,
    bombs: state.bombs,
    series,
    stake: state.perPointBet ?? 0,
  });
}

async function onTurnExpired(kit, roomCode, gameId, expectedDeadline) {
  const state = await readState(kit, roomCode);
  if (!state || ENDED_PHASES.has(state.phase) || state.gameId !== gameId || state.turnDeadline !== expectedDeadline) return;
  if (Date.now() < state.turnDeadline) {
    scheduleTurnTimer(kit, roomCode, state);
    return;
  }
  const player = state.current;
  const autoStreak = { ...(state.autoStreak ?? {}) };
  autoStreak[player] = (autoStreak[player] ?? 0) + 1;
  let next;
  if (state.phase !== "go_stop" && autoStreak[player] >= AUTO_FORFEIT_STREAK) {
    const r = forfeit(state, player);
    if (!r.ok) return;
    next = r.state;
  } else {
    const r = applyAuto(state);
    if (!r.ok) return;
    next = r.state;
  }
  next.autoStreak = autoStreak;
  if (ENDED_PHASES.has(next.phase)) {
    await finishGostopGame(kit, roomCode, next);
    return;
  }
  await saveState(kit, roomCode, next);
  await emitState(kit, roomCode, next);
}

async function createGame(kit, roomCode, { players, stake, gameId, starter, deadline }) {
  clearTurnTimer(roomCode);
  const perPointBet = GOSTOP_STAKES.has(Number(stake)) ? Number(stake) : 0;
  const state = createGostopGameState(players[0], players[1], {
    random: gostopRuntime.random,
    starter: players.includes(starter) ? starter : null,
    perPointBet,
    gameId,
  });
  state.autoStreak = Object.fromEntries(players.map((p) => [p, 0]));
  try {
    state.series = await kit.series.get(roomCode, GAME_TYPE, players);
  } catch {
    state.series = null;
  }
  await saveState(kit, roomCode, state, { deadline: deadline ?? Date.now() + TURN_MS });
  await emitState(kit, roomCode, state);
  return state;
}

/** 상태를 바꾸는 동작의 공통 처리(잠금 안). 끝난 판은 game_over로 거부한다. */
function registerAction(socket, kit, event, run) {
  socket.on(event, async (payload, ackRaw) => {
    const ack = kit.normalizeAck(ackRaw);
    const { roomCode, userId } = socket.data;
    if (!roomCode || !userId) {
      ack({ ok: false, reason: "not_joined" });
      return;
    }
    const body = payload && typeof payload === "object" ? payload : {};
    await kit.withRoomLock(roomCode, async () => {
      const state = await readState(kit, roomCode);
      if (!state) {
        ack({ ok: false, reason: "no_game" });
        return;
      }
      if (ENDED_PHASES.has(state.phase)) {
        ack({ ok: false, reason: "game_over" });
        return;
      }
      if (!state.players.includes(userId)) {
        ack({ ok: false, reason: "not_in_game" });
        return;
      }
      const result = run(state, userId, body);
      if (!result.ok) {
        ack({ ok: false, reason: result.reason });
        return;
      }
      const next = result.state;
      // 손으로 한 행동은 그 사람의 연속 자동 처리 횟수를 지운다.
      next.autoStreak = { ...(next.autoStreak ?? {}), [userId]: 0 };
      if (ENDED_PHASES.has(next.phase)) {
        ack({ ok: true, phase: next.phase });
        await finishGostopGame(kit, roomCode, next);
        return;
      }
      await saveState(kit, roomCode, next);
      ack({ ok: true, phase: next.phase });
      await emitState(kit, roomCode, next);
    });
  });
}

const str = (v) => (typeof v === "string" && v.length > 0 && v.length <= 32 ? v : null);
const invalid = { ok: false, reason: "invalid_payload" };

export default {
  gameType: GAME_TYPE,

  register(socket, kit) {
    socket.on("game:gostop:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      await kit.withRoomLock(roomCode, async () => {
        const state = await readState(kit, roomCode);
        if (!state) {
          ack({ ok: false, reason: "no_game" });
          return;
        }
        if (ENDED_PHASES.has(state.phase)) {
          ack({ ok: false, reason: "game_over" });
          return;
        }
        if (!state.players.includes(userId)) {
          ack({ ok: false, reason: "not_in_game" });
          return;
        }
        if (!state.turnDeadline) await saveState(kit, roomCode, state);
        else if (!timers.has(roomCode)) scheduleTurnTimer(kit, roomCode, state);
        const view = serializeFor(state, userId);
        socket.emit("game:gostop:state", view);
        ack({ ok: true, state: view });
      });
    });

    registerAction(socket, kit, "game:gostop:play", (state, userId, p) => {
      const cardId = str(p.cardId);
      if (!cardId) return invalid;
      return playCard(state, userId, { cardId, shake: p.shake === true, targetId: str(p.targetId) });
    });

    registerAction(socket, kit, "game:gostop:bomb", (state, userId, p) => {
      const month = Number(p.month);
      if (!Number.isInteger(month) || month < 1 || month > 12) return invalid;
      return playBomb(state, userId, month);
    });

    registerAction(socket, kit, "game:gostop:dotan", (state, userId) => playDotan(state, userId));

    registerAction(socket, kit, "game:gostop:choose", (state, userId, p) => {
      const cardId = str(p.cardId);
      if (!cardId) return invalid;
      return choose(state, userId, cardId);
    });

    registerAction(socket, kit, "game:gostop:decide", (state, userId, p) => {
      if (p.decision !== "go" && p.decision !== "stop") return invalid;
      return declare(state, userId, p.decision);
    });

    registerAction(socket, kit, "game:gostop:chongtong", (state, userId, p) => {
      if (typeof p.declare !== "boolean") return invalid;
      return decideChongtong(state, userId, p.declare);
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    await kit.withRoomLock(roomCode, async () => {
      const players = ctx.players.slice(0, 2);
      if (players.length !== 2) return;
      await createGame(kit, roomCode, {
        players,
        stake: ctx.stake ?? 0,
        gameId: ctx.gameId ?? kit.randomUUID(),
        starter: null, // 첫 판 선은 무작위
        deadline: (ctx.startsAt ?? Date.now()) + TURN_MS,
      });
    });
  },

  // socket.js가 game:restart:respond의 잠금 안에서 부른다(다시 잠그지 않는다).
  async restart(roomCode, kit, ctx) {
    const players = ctx.orderedPlayers?.length === 2 ? ctx.orderedPlayers : [ctx.p1, ctx.p2];
    let last = null;
    try {
      const raw = await kit.redis.get(gostopLastKey(roomCode));
      last = raw ? JSON.parse(raw) : null;
    } catch {
      last = null;
    }
    const current = await readState(kit, roomCode);
    // 판돈 판이 진행 중이면 정산 없이 덮어쓸 수 없다(지던 쪽이 판돈을 피하는 것을 막음).
    if (current && !ENDED_PHASES.has(current.phase) && (current.perPointBet ?? 0) > 0) {
      return { ok: false, reason: "game_in_progress" };
    }
    const running = current && !ENDED_PHASES.has(current.phase) ? current : null;
    const stake = running ? running.perPointBet ?? 0 : last?.stake ?? 0;
    // 이긴 사람이 선. 나가리(승자 없음)면 지난 판의 선이 그대로.
    const lastWinner = running ? null : last?.lastWinner ?? null;
    const lastStarter = running ? running.starter : last?.lastStarter ?? null;
    const starter = players.includes(lastWinner) ? lastWinner : players.includes(lastStarter) ? lastStarter : null;
    await createGame(kit, roomCode, { players, stake, gameId: kit.randomUUID(), starter });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const state = await readState(kit, roomCode);
    if (!state || ENDED_PHASES.has(state.phase) || !state.players?.includes(userId)) return false;
    // 재접속 소켓을 뷰어 방에 먼저 넣어 마지막 뷰어 정리와 경합하지 않게 한다.
    await socket.join(viewerRoomKey(roomCode, GAME_TYPE));
    socket.data.viewingGame = GAME_TYPE;
    let view = state;
    if (!state.turnDeadline || !timers.has(roomCode)) {
      await kit.withRoomLock(roomCode, async () => {
        const fresh = await readState(kit, roomCode);
        if (!fresh || ENDED_PHASES.has(fresh.phase)) return;
        if (!fresh.turnDeadline) await saveState(kit, roomCode, fresh);
        else if (!timers.has(roomCode)) scheduleTurnTimer(kit, roomCode, fresh);
        view = fresh;
      });
    }
    socket.emit("game:gostop:state", serializeFor(view, userId));
    return true;
  },

  afk(kit) {
    return {
      key: gostopGameKey,
      playersOf: (s) => s.players ?? [],
      // 고/스톱을 고민하는 사람은 잠수 기권 대상이 아니다(자체 타이머가 스톱으로 끝낸다).
      waitingOn: (s) => {
        if (s?.version !== GOSTOP_VERSION || ENDED_PHASES.has(s.phase) || s.phase === "go_stop") return null;
        return s.current ?? null;
      },
      forfeit: async (roomCode, s, loser) => {
        const r = forfeit(s, loser);
        if (!r.ok) return;
        await finishGostopGame(kit, roomCode, r.state);
      },
    };
  },

  dispose() {
    for (const roomCode of [...timers.keys()]) clearTurnTimer(roomCode);
  },
};
