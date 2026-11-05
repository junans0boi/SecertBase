// 원카드 2.0 게임 모듈(내부 식별자 uno). 규칙은 uno-engine.js, 여기는 소켓 흐름·서버 타이머·정산.
// 계약: docs/socket-events/onecard.md
//
// - 로비 시작과 함께 서버가 판을 만든다(startFromLobby). 화면은 game:uno:sync로 상태를 받는다.
// - 상태가 바뀔 때마다 turnDeadline(20초)을 다시 걸고, 만료되면 서버가 안전한 행동(뽑고 넘김)을 한다.
//   같은 사람이 연속 3번 자동 처리되면 기권패.
// - 승리·기권은 finishUnoGame 하나로: 끝남 저장 → 정산·기록(try/finally) → 상태 삭제 → game:uno:ended.
import { query } from "../db.js";
import { getEquippedItemsInfo, getEquippedStats } from "../wallet-engine.js";
import { viewerRoomKey } from "../game-session.js";
import {
  COLORS,
  DEFAULT_UNO_MODE,
  UNO_MODES,
  autoAction,
  callOneCard,
  catchOneCard,
  challengeDraw4,
  createUnoGameState,
  drawForTurn,
  passDrawnCard,
  playCard,
  serializeOneCardFor,
} from "../uno-engine.js";

export const GAME_TYPE = "uno";
export const TURN_MS = 20_000;
export const AUTO_FORFEIT_STREAK = 3;
export const STATE_TTL_SEC = 3600;
export const LAST_TTL_SEC = 3600;
export const unoGameKey = (roomCode) => `uno:${roomCode}:game`;
export const unoLastKey = (roomCode) => `uno:${roomCode}:last`;

// 테스트가 무작위를 고정할 수 있게 한 곳에 둔다.
export const onecardRuntime = { random: Math.random };

const timers = new Map(); // roomCode → { handle, kit, gameId, deadline }

const clearTurnTimer = (roomCode) => {
  const entry = timers.get(roomCode);
  if (!entry) return;
  entry.kit.timerApi.clearTimeout(entry.handle);
  timers.delete(roomCode);
};

const readState = async (kit, roomCode) => {
  const raw = await kit.redis.get(unoGameKey(roomCode));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
};

const otherPlayer = (state, player) => state.players.find((p) => p !== player) ?? null;

async function loadItems(players) {
  const playerStats = {};
  const equippedItems = {};
  for (const code of players) {
    try {
      const { rows } = await query("SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1", [code]);
      const numId = rows[0]?.UserId;
      playerStats[code] = numId ? await getEquippedStats(numId) : {};
      equippedItems[code] = numId ? await getEquippedItemsInfo(numId) : {};
    } catch (err) {
      // 아이템 조회가 실패해도 판은 만든다(아이템 효과만 빠진다).
      console.error(`[onecard] item load failed for ${code}: ${err.message}`);
      playerStats[code] = {};
      equippedItems[code] = {};
    }
  }
  return { playerStats, equippedItems };
}

async function emitState(kit, roomCode, state) {
  const sockets = await kit.io.in(roomCode).fetchSockets();
  for (const sock of sockets) {
    const userId = sock.data.userId;
    if (userId && state.players.includes(userId)) sock.emit("game:uno:state", serializeOneCardFor(state, userId));
  }
}

async function emitItemEffects(kit, roomCode, effects = []) {
  if (!effects.length) return;
  const sockets = await kit.io.in(roomCode).fetchSockets();
  for (const effect of effects) {
    for (const sock of sockets) {
      if (sock.data.userId === effect.player) sock.emit("game:item_effect", { stat: effect.stat, amount: 0 });
    }
  }
}

function scheduleTurnTimer(kit, roomCode, state) {
  clearTurnTimer(roomCode);
  if (state.winner || !state.turnDeadline) return;
  const { gameId, turnDeadline } = state;
  const handle = kit.timerApi.setTimeout(() => {
    if (timers.get(roomCode)?.handle === handle) timers.delete(roomCode);
    void kit.withRoomLock(roomCode, () => onTurnExpired(kit, roomCode, gameId, turnDeadline))
      .catch((err) => console.error(`[onecard] turn timer failed: ${err.message}`));
  }, Math.max(0, turnDeadline - Date.now()));
  handle?.unref?.();
  timers.set(roomCode, { handle, kit, gameId, deadline: turnDeadline });
}

/** 저장 + 마감시각 갱신 + 타이머 재설정. 상태가 바뀔 때마다 부른다. */
async function saveState(kit, roomCode, state, { deadline = Date.now() + TURN_MS } = {}) {
  state.turnMs = TURN_MS;
  state.turnDeadline = state.winner ? null : deadline;
  await kit.redis.set(unoGameKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);
  scheduleTurnTimer(kit, roomCode, state);
}

/**
 * 정상 승리와 기권패의 단일 종료 경로.
 * reason: 'empty_hand' | 'forfeit'
 */
export async function finishUnoGame(kit, roomCode, state, reason, winner = state.winner) {
  clearTurnTimer(roomCode);
  const loser = otherPlayer(state, winner);
  state.winner = winner;
  state.finishReason = reason;
  state.turnDeadline = null;
  await kit.redis.set(unoGameKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);

  const stake = state.stake ?? 0;
  const gameId = state.gameId ?? `legacy-${roomCode}`;
  let series = state.series ?? null;
  try {
    const [{ rows: winnerRows }, { rows: loserRows }] = await Promise.all([
      query("SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1", [winner]),
      query("SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1", [loser]),
    ]);
    const preStreak = await kit.winStreak(roomCode, winner);
    // 정산 ref는 판 id로 고정되어 멱등하다.
    const wallet = await kit.settleWallet(roomCode, winner, loser, stake, `uno:${gameId}`, winnerRows[0]?.UserId, 0, loserRows[0]?.UserId, preStreak);
    if (!wallet.ok) kit.io.to(roomCode).emit("wallet:settle_failed", { gameType: GAME_TYPE, reason: wallet.reason });
    await kit.recordGameOutcome(roomCode, { winner, players: state.players, gameType: GAME_TYPE, missionKey: "onecard", stake, gameId });
    series = await kit.series.record(roomCode, GAME_TYPE, state.players, winner);
  } catch (err) {
    console.error(`[onecard] settlement failed for ${roomCode}: ${err?.message ?? err}`);
    // 정산이 중간에 실패해도 두 사람에게 알린다(잔액 확인 안내).
    if (stake > 0) kit.io.to(roomCode).emit("wallet:settle_failed", { gameType: GAME_TYPE, reason: "settle_error" });
  } finally {
    await kit.redis.del(unoGameKey(roomCode));
    await kit.redis.set(
      unoLastKey(roomCode),
      JSON.stringify({ mode: state.mode, stake, series, lastStarter: state.starter ?? null, players: state.players, gameId }),
      "EX",
      LAST_TTL_SEC,
    );
  }

  const handCount = Object.fromEntries(state.players.map((p) => [p, state.hands[p]?.length ?? 0]));
  kit.io.to(roomCode).emit("game:uno:ended", {
    gameId,
    winner,
    loser,
    reason,
    hands: Object.fromEntries(state.players.map((p) => [p, state.hands[p] ?? []])),
    handCount,
    series,
    stake,
    mode: state.mode,
  });
}

async function onTurnExpired(kit, roomCode, gameId, expectedDeadline) {
  const state = await readState(kit, roomCode);
  if (!state || state.winner || state.gameId !== gameId || state.turnDeadline !== expectedDeadline) return;
  if (Date.now() < state.turnDeadline) {
    scheduleTurnTimer(kit, roomCode, state);
    return;
  }
  const player = state.currentPlayer;
  state.autoStreak = { ...(state.autoStreak ?? {}) };
  const streak = (state.autoStreak[player] ?? 0) + 1;
  state.autoStreak[player] = streak;
  if (streak >= AUTO_FORFEIT_STREAK) {
    await finishUnoGame(kit, roomCode, state, "forfeit", otherPlayer(state, player));
    return;
  }
  const result = autoAction(state, { random: onecardRuntime.random });
  if (!result.ok) return;
  await saveState(kit, roomCode, state);
  await emitItemEffects(kit, roomCode, result.itemEffects);
  await emitState(kit, roomCode, state);
}

async function createGame(kit, roomCode, { players, mode, stake, gameId, starter, deadline }) {
  clearTurnTimer(roomCode);
  const safeMode = UNO_MODES.includes(mode) ? mode : DEFAULT_UNO_MODE;
  const state = createUnoGameState(players, 7, { mode: safeMode, starter, random: onecardRuntime.random });
  state.gameId = gameId;
  state.stake = Number(stake) || 0;
  const items = await loadItems(players);
  state.playerStats = items.playerStats;
  state.equippedItems = items.equippedItems;
  try {
    state.series = await kit.series.get(roomCode, GAME_TYPE, players);
  } catch {
    state.series = null;
  }
  await saveState(kit, roomCode, state, { deadline: deadline ?? Date.now() + TURN_MS });
  await emitState(kit, roomCode, state);
  return state;
}

/** 진행 중인 판을 가진 소켓의 공통 처리. 승리 뒤에는 모든 원카드 동작을 game_over로 거부한다. */
function registerAction(socket, kit, event, run) {
  socket.on(event, async (payload, ackRaw) => {
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
      if (state.winner) {
        ack({ ok: false, reason: "game_over" });
        return;
      }
      if (!state.players.includes(userId)) {
        ack({ ok: false, reason: "not_in_game" });
        return;
      }
      const result = run(state, userId, payload ?? {});
      if (!result.ok) {
        ack({ ok: false, reason: result.reason });
        return;
      }
      // 손으로 한 행동은 그 사람의 연속 자동 처리 횟수를 지운다.
      state.autoStreak = { ...(state.autoStreak ?? {}), [userId]: 0 };
      if (state.winner) {
        ack({ ok: true, won: true });
        await emitState(kit, roomCode, state);
        await finishUnoGame(kit, roomCode, state, "empty_hand");
        return;
      }
      await saveState(kit, roomCode, state);
      ack({ ok: true, ...(result.ackExtra ?? {}) });
      await emitItemEffects(kit, roomCode, result.itemEffects);
      if (result.challenged) kit.io.to(roomCode).emit("game:uno:challenged", result.challenged);
      await emitState(kit, roomCode, state);
    });
  });
}

const random = () => onecardRuntime.random();

export default {
  gameType: GAME_TYPE,
  // 옛 앱이 보내던 로비 종류. 모드는 로비 옵션(uno.mode)을 쓴다.
  lobbyAliases: ["uno_classic", "uno_go_wild"],

  register(socket, kit) {
    socket.on("game:uno:sync", async (_payload, ackRaw) => {
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
        if (state.winner) {
          ack({ ok: false, reason: "game_over" });
          return;
        }
        if (!state.players.includes(userId)) {
          ack({ ok: false, reason: "not_in_game" });
          return;
        }
        if (!state.turnDeadline) await saveState(kit, roomCode, state);
        else if (!timers.has(roomCode)) scheduleTurnTimer(kit, roomCode, state);
        const view = serializeOneCardFor(state, userId);
        socket.emit("game:uno:state", view);
        ack({ ok: true, state: view });
      });
    });

    registerAction(socket, kit, "game:uno:play", (state, userId, payload) => {
      const cardId = typeof payload.cardId === "string" ? payload.cardId : "";
      if (!cardId) return { ok: false, reason: "invalid_payload" };
      const declaredColor = COLORS.includes(payload.declaredColor) ? payload.declaredColor : null;
      return playCard(state, userId, cardId, declaredColor, { random });
    });

    registerAction(socket, kit, "game:uno:draw", (state, userId) => {
      const result = drawForTurn(state, userId, { random });
      return result.ok ? { ...result, ackExtra: { count: result.count, canPlayDrawn: result.canPlayDrawn, penalty: result.penalty } } : result;
    });

    registerAction(socket, kit, "game:uno:pass", (state, userId) => passDrawnCard(state, userId));

    registerAction(socket, kit, "game:uno:call", (state, userId) => callOneCard(state, userId));

    registerAction(socket, kit, "game:uno:catch", (state, userId) => {
      const result = catchOneCard(state, userId, { random });
      return result.ok ? { ...result, ackExtra: { count: result.count, protected: result.protected } } : result;
    });

    registerAction(socket, kit, "game:uno:challenge", (state, userId) => {
      const result = challengeDraw4(state, userId, { random });
      if (!result.ok) return result;
      return {
        ...result,
        ackExtra: { success: result.success },
        challenged: {
          by: userId,
          challenged: result.challenged,
          success: result.success,
          drawnPlayer: result.drawnPlayer,
          drawnCount: result.drawnCount,
          nextPlayer: result.nextPlayer,
          mode: state.mode,
          drawStack: 0,
          drawStackType: null,
          declaredColor: state.declaredColor ?? null,
          handCount: Object.fromEntries(state.players.map((p) => [p, state.hands[p].length])),
          unoCallNeeded: state.unoCallNeeded ?? null,
        },
      };
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    await kit.withRoomLock(roomCode, async () => {
      const players = ctx.players.slice(0, 2);
      if (players.length !== 2) return;
      await createGame(kit, roomCode, {
        players,
        mode: ctx.options?.mode,
        stake: ctx.stake ?? 0,
        gameId: ctx.gameId ?? kit.randomUUID(),
        starter: null, // 첫 판은 무작위
        deadline: (ctx.startsAt ?? Date.now()) + TURN_MS,
      });
    });
  },

  async restart(roomCode, kit, ctx) {
    const players = ctx.orderedPlayers?.length === 2 ? ctx.orderedPlayers : [ctx.p1, ctx.p2];
    let last = null;
    try {
      const raw = await kit.redis.get(unoLastKey(roomCode));
      last = raw ? JSON.parse(raw) : null;
    } catch {
      last = null;
    }
    const current = await readState(kit, roomCode);
    // 판돈이 걸린 판이 진행 중이면 정산 없이 덮어쓸 수 없다(진 쪽이 판돈을 피하는 것을 막음).
    if (current && !current.winner && (current.stake ?? 0) > 0) {
      return { ok: false, reason: "game_in_progress" };
    }
    // 진행 중인 판(무료)이 있으면 그 판 설정을, 없으면 끝난 판의 요약을 잇는다.
    const source = (current && !current.winner ? current : null) ?? last ?? current ?? {};
    const lastStarter = last?.lastStarter ?? current?.starter ?? null;
    const starter = players.includes(lastStarter) ? players.find((p) => p !== lastStarter) : null;
    await createGame(kit, roomCode, {
      players,
      mode: source.mode,
      stake: source.stake ?? 0,
      gameId: kit.randomUUID(),
      starter,
    });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const state = await readState(kit, roomCode);
    if (!state || state.winner || !state.players?.includes(userId)) return false;
    // 재접속 소켓을 뷰어 방에 먼저 넣어 마지막 뷰어 정리와 경합하지 않게 한다.
    await socket.join(viewerRoomKey(roomCode, GAME_TYPE));
    socket.data.viewingGame = GAME_TYPE;
    if (!state.turnDeadline) {
      await kit.withRoomLock(roomCode, async () => {
        const fresh = await readState(kit, roomCode);
        if (fresh && !fresh.winner && !fresh.turnDeadline) await saveState(kit, roomCode, fresh);
      });
      const fresh = await readState(kit, roomCode);
      if (!fresh) return false;
      socket.emit("game:uno:state", serializeOneCardFor(fresh, userId));
      return true;
    }
    if (!timers.has(roomCode)) scheduleTurnTimer(kit, roomCode, state);
    socket.emit("game:uno:state", serializeOneCardFor(state, userId));
    return true;
  },

  afk(kit) {
    return {
      key: unoGameKey,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => (s.winner ? null : s.currentPlayer ?? null),
      forfeit: async (roomCode, s, loser, winner) => {
        await finishUnoGame(kit, roomCode, s, "forfeit", winner ?? otherPlayer(s, loser));
      },
    };
  },

  dispose() {
    for (const roomCode of [...timers.keys()]) clearTurnTimer(roomCode);
  },
};
