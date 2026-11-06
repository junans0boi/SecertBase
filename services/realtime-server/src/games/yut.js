// 윷놀이 2.0 게임 모듈. 규칙은 yut-engine.js, 여기는 소켓 흐름·서버 타이머·정산.
// 계약: docs/socket-events/yut.md
//
// - 로비 시작과 함께 서버가 판을 만든다(startFromLobby). 캐릭터·배경음·판돈·말 수는 서버 로비 기록에서,
//   첫 순서는 무작위. 화면은 game:yut:sync로 상태를 받는다.
// - 상태가 바뀔 때마다 turnDeadline(30초)을 다시 걸고, 만료되면 서버가 던지고(던질 차례면)
//   남은 이동을 "최선 이동"으로 하나씩 둔다. 같은 사람이 연속 3번 자동 처리되면 기권패.
// - 승리·기권은 finishYutGame 하나로: 끝남 저장 → 정산·기록(try/finally) → 상태 삭제 → game:yut:ended.
import { query } from "../db.js";
import { getEquippedItemsInfo } from "../wallet-engine.js";
import { viewerRoomKey } from "../game-session.js";
import {
  DEFAULT_PIECE_COUNT,
  PIECE_COUNTS,
  applyMove,
  applyThrow,
  autoMove,
  coinBonusCap,
  createYutGameState,
  legalMoves,
  serializeYutState,
  yutItemEffects,
} from "../yut-engine.js";

export const GAME_TYPE = "yut";
export const TURN_MS = 30_000;
export const AUTO_FORFEIT_STREAK = 3;
export const STATE_TTL_SEC = 3600;
export const LAST_TTL_SEC = 3600;
export const YUT_CHARACTERS = Object.freeze(["honggilldong", "nolbu", "miho"]);
export const YUT_BGMS = Object.freeze(["yut1.mp3", "yut2.mp3", "yut3.mp3"]);
export const yutGameKey = (roomCode) => `yut:${roomCode}:game`;
export const yutLastKey = (roomCode) => `yut:${roomCode}:last`;

// 테스트가 무작위를 고정할 수 있게 한 곳에 둔다.
export const yutRuntime = { random: Math.random };
const random = () => yutRuntime.random();

const timers = new Map(); // roomCode → { handle, kit, gameId, deadline }

const clearTurnTimer = (roomCode) => {
  const entry = timers.get(roomCode);
  if (!entry) return;
  entry.kit.timerApi.clearTimeout(entry.handle);
  timers.delete(roomCode);
};

const readState = async (kit, roomCode) => {
  const raw = await kit.redis.get(yutGameKey(roomCode));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
};

const readLast = async (kit, roomCode) => {
  try {
    const raw = await kit.redis.get(yutLastKey(roomCode));
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

const otherPlayer = (state, player) => state.playersOrder.find((p) => p !== player) ?? null;

/**
 * 두 사람의 캐릭터(음성)를 정한다. 로비에서 고른 값(서버 기록) → 지난 판 → 기본값 순서이고,
 * 두 사람이 같은 캐릭터가 되지 않게 한다.
 */
export function assignCharacters(players, ...sources) {
  const result = {};
  for (const player of players) {
    for (const source of sources) {
      const pick = source?.[player];
      if (YUT_CHARACTERS.includes(pick) && !Object.values(result).includes(pick)) {
        result[player] = pick;
        break;
      }
    }
  }
  const defaults = ["honggilldong", "miho", "nolbu"];
  for (const player of players) {
    if (result[player]) continue;
    result[player] = defaults.find((c) => !Object.values(result).includes(c));
  }
  return result;
}

async function loadItems(players) {
  const playerStats = {};
  const equippedItems = {};
  for (const code of players) {
    try {
      const { rows } = await query("SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1", [code]);
      const numId = rows[0]?.UserId;
      // 말 스킨은 폐지: 효과도 표시도 윷 스킨(yut_yut) 하나에서만 온다(남은 옛 장착은 무시).
      const info = numId ? await getEquippedItemsInfo(numId) : {};
      equippedItems[code] = info.yut_yut ? { yut_yut: info.yut_yut } : {};
      playerStats[code] = { ...(info.yut_yut?.stats ?? {}) };
    } catch (err) {
      // 아이템 조회가 실패해도 판은 만든다(아이템 효과만 빠진다).
      console.error(`[yut] item load failed for ${code}: ${err.message}`);
      playerStats[code] = {};
      equippedItems[code] = {};
    }
  }
  return { playerStats, equippedItems };
}

async function emitState(kit, roomCode, state) {
  kit.io.to(roomCode).emit("game:yut:state", serializeYutState(state));
}

function scheduleTurnTimer(kit, roomCode, state) {
  clearTurnTimer(roomCode);
  if (state.winner || !state.turnDeadline) return;
  const { gameId, turnDeadline } = state;
  const handle = kit.timerApi.setTimeout(() => {
    if (timers.get(roomCode)?.handle === handle) timers.delete(roomCode);
    void kit.withRoomLock(roomCode, () => onTurnExpired(kit, roomCode, gameId, turnDeadline))
      .catch((err) => console.error(`[yut] turn timer failed: ${err.message}`));
  }, Math.max(0, turnDeadline - Date.now()));
  handle?.unref?.();
  timers.set(roomCode, { handle, kit, gameId, deadline: turnDeadline });
}

/** 저장 + 마감시각 갱신 + 타이머 재설정. 상태가 바뀔 때마다 부른다. */
async function saveState(kit, roomCode, state, { deadline = Date.now() + TURN_MS } = {}) {
  state.turnMs = TURN_MS;
  state.turnDeadline = state.winner ? null : deadline;
  await kit.redis.set(yutGameKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);
  scheduleTurnTimer(kit, roomCode, state);
}

/**
 * 정상 승리와 기권패의 단일 종료 경로.
 * reason: 'goal' | 'forfeit'
 */
export async function finishYutGame(kit, roomCode, state, reason, winner = state.winner) {
  clearTurnTimer(roomCode);
  const loser = otherPlayer(state, winner);
  state.winner = winner;
  state.phase = "finished";
  state.finishReason = reason;
  state.turnDeadline = null;
  await kit.redis.set(yutGameKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);

  const stake = Number(state.stake) || 0;
  const gameId = state.gameId ?? `legacy-${roomCode}`;
  // 코인 보너스는 판돈의 30%까지만(엔진이 쌓을 때 이미 자른다). 정산 때 승자에게만 지급.
  const coinBonus = stake > 0 ? Math.min(Number(state.coinBonus?.[winner]) || 0, coinBonusCap(stake)) : 0;
  let series = state.series ?? null;
  // 영수증: 실제로 옮겨진 코인. 판돈이 모자라거나(올인 캡) 정산이 실패하면 화면이 판돈 그대로를 말하지 않게 한다.
  let transferred = 0;
  let winnerGain = 0;
  let settlement = stake > 0 ? "pending" : "none";
  try {
    // 아이템 보너스용 숫자 id 조회가 실패해도 판돈 이체는 코드로 하므로 멈추지 않는다.
    let winnerNumericId;
    let loserNumericId;
    try {
      const [{ rows: winnerRows }, { rows: loserRows }] = await Promise.all([
        query("SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1", [winner]),
        query("SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1", [loser]),
      ]);
      winnerNumericId = winnerRows[0]?.UserId;
      loserNumericId = loserRows[0]?.UserId;
    } catch (err) {
      console.error(`[yut] user lookup failed for ${roomCode}: ${err?.message ?? err}`);
    }
    const preStreak = await kit.winStreak(roomCode, winner);
    // 정산 ref는 판 id로 고정되어 멱등하다.
    const wallet = await kit.settleWallet(roomCode, winner, loser, stake, `yut:${gameId}`, winnerNumericId, coinBonus, loserNumericId, preStreak);
    if (stake > 0) {
      if (wallet?.ok && wallet.result) {
        transferred = Math.max(0, Number(wallet.result.actual) || 0);
        winnerGain = Math.max(0, Number(wallet.result.winnerGain) || 0);
        settlement = wallet.result.alreadySettled ? "already" : transferred < stake ? "capped" : "settled";
      } else {
        settlement = "failed";
        kit.io.to(roomCode).emit("wallet:settle_failed", { gameType: GAME_TYPE, reason: wallet?.reason ?? "settle_error" });
      }
    }
    await kit.recordGameOutcome(roomCode, { winner, players: state.playersOrder, gameType: GAME_TYPE, missionKey: "yut", stake, gameId });
    series = await kit.series.record(roomCode, GAME_TYPE, state.playersOrder, winner);
  } catch (err) {
    console.error(`[yut] settlement failed for ${roomCode}: ${err?.message ?? err}`);
    if (settlement === "pending") {
      settlement = "failed";
      kit.io.to(roomCode).emit("wallet:settle_failed", { gameType: GAME_TYPE, reason: "settle_error" });
    }
  } finally {
    await kit.redis.del(yutGameKey(roomCode));
    await kit.redis.set(
      yutLastKey(roomCode),
      JSON.stringify({
        stake,
        series,
        characters: state.characters ?? {},
        bgm: state.bgm ?? null,
        pieceCount: state.pieceCount ?? DEFAULT_PIECE_COUNT,
        lastStarter: state.starter ?? null,
        players: state.playersOrder,
        gameId,
      }),
      "EX",
      LAST_TTL_SEC,
    );
  }

  const finished = Object.fromEntries(state.playersOrder.map((p) => [p, (state.players[p]?.pieces ?? []).filter((x) => x.finished).length]));
  kit.io.to(roomCode).emit("game:yut:ended", {
    gameId,
    winner,
    loser,
    reason,
    stake,
    coinBonus,
    transferred,
    winnerGain,
    settlement,
    finished,
    pieceCount: state.pieceCount ?? DEFAULT_PIECE_COUNT,
    pieces: Object.fromEntries(state.playersOrder.map((p) => [p, state.players[p]?.pieces ?? []])),
    characters: state.characters ?? {},
    series,
  });
}

/**
 * 시간이 지난 차례: 던질 차례면 던지고, 남은 이동을 최선 이동으로 하나씩 둔다.
 * 윷·모로 보너스 던지기가 생기면 거기서 멈추고 새 30초를 준다(돌아온 사람이 이어 할 수 있게).
 */
async function onTurnExpired(kit, roomCode, gameId, expectedDeadline) {
  const state = await readState(kit, roomCode);
  if (!state || state.winner || state.gameId !== gameId || state.turnDeadline !== expectedDeadline) return;
  if (Date.now() < state.turnDeadline) {
    scheduleTurnTimer(kit, roomCode, state);
    return;
  }
  const player = state.currentTurn;
  state.autoStreak = { ...(state.autoStreak ?? {}) };
  const streak = (state.autoStreak[player] ?? 0) + 1;
  state.autoStreak[player] = streak;
  if (streak >= AUTO_FORFEIT_STREAK) {
    await finishYutGame(kit, roomCode, state, "forfeit", otherPlayer(state, player));
    return;
  }
  const canThrow = state.phase === "throwing" || (state.phase === "moving" && state.hasBonusThrow);
  if (canThrow) {
    const thrown = applyThrow(state, player, { random, auto: true });
    if (!thrown.ok) return;
    await saveState(kit, roomCode, state);
    await emitState(kit, roomCode, state);
  }
  for (let guard = 0; guard < 12; guard++) {
    if (state.winner || state.currentTurn !== player || state.phase !== "moving" || state.hasBonusThrow) break;
    const pick = autoMove(state, player);
    if (!pick) break;
    const moved = applyMove(state, player, { pieceId: pick.pieceId, moveIndex: pick.moveIndex, backdoDir: pick.backdoDir, random, auto: true });
    if (!moved.ok) break;
    if (moved.won) {
      await emitState(kit, roomCode, state);
      await finishYutGame(kit, roomCode, state, "goal");
      return;
    }
    await saveState(kit, roomCode, state);
    await emitState(kit, roomCode, state);
  }
}

async function createGame(kit, roomCode, { players, pieces, stake, gameId, starter, characters, bgm, deadline }) {
  clearTurnTimer(roomCode);
  const firstPlayer = players.includes(starter) ? starter : players[random() < 0.5 ? 0 : 1];
  const state = createYutGameState(players[0], players[1], {
    pieces: PIECE_COUNTS.includes(pieces) ? pieces : DEFAULT_PIECE_COUNT,
    starter: firstPlayer,
    characters,
    bgm: YUT_BGMS.includes(bgm) ? bgm : YUT_BGMS[Math.floor(random() * YUT_BGMS.length) % YUT_BGMS.length],
  });
  state.gameId = gameId;
  state.stake = Number(stake) || 0;
  const items = await loadItems(players);
  state.playerStats = items.playerStats;
  state.equippedItems = items.equippedItems;
  // 판돈 게임에서도 아이템 효과는 합산 상한 안에서만(엔진이 계산).
  state.effects = Object.fromEntries(players.map((p) => [p, yutItemEffects(items.playerStats[p], state.characters?.[p])]));
  state.seq = 1;
  state.lastAction = { type: "start", by: firstPlayer, seq: 1 };
  try {
    state.series = await kit.series.get(roomCode, GAME_TYPE, players);
  } catch {
    state.series = null;
  }
  await saveState(kit, roomCode, state, { deadline: deadline ?? Date.now() + TURN_MS });
  await emitState(kit, roomCode, state);
  return state;
}

/** 진행 중인 판을 가진 소켓의 공통 처리. 승리 뒤에는 모든 윷놀이 동작을 game_over로 거부한다. */
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
      if (!state.playersOrder?.includes(userId)) {
        ack({ ok: false, reason: "not_in_game" });
        return;
      }
      const result = run(state, userId, payload && typeof payload === "object" ? payload : {});
      if (!result.ok) {
        ack({ ok: false, reason: result.reason });
        return;
      }
      // 손으로 한 행동은 그 사람의 연속 자동 처리 횟수를 지운다.
      state.autoStreak = { ...(state.autoStreak ?? {}), [userId]: 0 };
      if (state.winner) {
        ack({ ok: true, won: true, seq: state.seq });
        await emitState(kit, roomCode, state);
        await finishYutGame(kit, roomCode, state, "goal");
        return;
      }
      await saveState(kit, roomCode, state);
      ack({ ok: true, seq: state.seq, ...(result.ackExtra ?? {}) });
      await emitState(kit, roomCode, state);
    });
  });
}

const isInt = (v) => Number.isInteger(v);

export default {
  gameType: GAME_TYPE,

  register(socket, kit) {
    socket.on("game:yut:sync", async (_payload, ackRaw) => {
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
        if (!state.playersOrder?.includes(userId)) {
          ack({ ok: false, reason: "not_in_game" });
          return;
        }
        if (!state.turnDeadline) await saveState(kit, roomCode, state);
        else if (!timers.has(roomCode)) scheduleTurnTimer(kit, roomCode, state);
        const view = serializeYutState(state);
        socket.emit("game:yut:state", view);
        ack({ ok: true, state: view });
      });
    });

    registerAction(socket, kit, "game:yut:throw", (state, userId) => {
      const result = applyThrow(state, userId, { random });
      return result.ok ? { ...result, ackExtra: { throw: result.throwResult } } : result;
    });

    registerAction(socket, kit, "game:yut:move", (state, userId, payload) => {
      const { pieceId, moveIndex = 0, backdoDir = null } = payload;
      if (!isInt(pieceId) || !isInt(moveIndex) || (backdoDir !== null && !isInt(backdoDir))) {
        return { ok: false, reason: "invalid_payload" };
      }
      if (state.currentTurn !== userId) return { ok: false, reason: "not_your_turn" };
      if (!state.pendingMoves?.length) return { ok: false, reason: "must_throw_first" };
      // 화면이 보낸 이동은 서버가 계산한 후보 중 하나여야 한다(업힌 말은 무더기 안 아무 말이나).
      const chosen = state.players[userId]?.pieces?.[pieceId];
      const waiting = chosen && !chosen.finished && chosen.position === 0;
      const legal = legalMoves(state, userId).find((m) =>
        m.moveIndex === moveIndex
        && (m.pieceIds.includes(pieceId) || (waiting && m.from === 0))
        && (m.backdoDir === null || backdoDir === null || m.backdoDir === backdoDir));
      if (!legal) return { ok: false, reason: "invalid_move" };
      return applyMove(state, userId, { pieceId: legal.pieceId, moveIndex, backdoDir: backdoDir ?? legal.backdoDir, random });
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    await kit.withRoomLock(roomCode, async () => {
      const players = ctx.players.slice(0, 2);
      if (players.length !== 2) return;
      await createGame(kit, roomCode, {
        players,
        pieces: ctx.options?.pieces,
        stake: ctx.stake ?? 0,
        gameId: ctx.gameId ?? kit.randomUUID(),
        starter: null, // 첫 판은 무작위
        characters: assignCharacters(players, ctx.characterSelections),
        bgm: ctx.metadata?.yutBgm,
        deadline: (ctx.startsAt ?? Date.now()) + TURN_MS,
      });
    });
  },

  async restart(roomCode, kit, ctx) {
    const players = ctx.orderedPlayers?.length === 2 ? ctx.orderedPlayers : [ctx.p1, ctx.p2];
    const last = await readLast(kit, roomCode);
    const current = await readState(kit, roomCode);
    // 판돈이 걸린 판이 진행 중이면 정산 없이 덮어쓸 수 없다(진 쪽이 판돈을 피하는 것을 막음).
    if (current && !current.winner && (current.stake ?? 0) > 0) {
      return { ok: false, reason: "game_in_progress" };
    }
    // 진행 중인 판(무료)이 있으면 그 판 설정을, 없으면 끝난 판의 요약을 잇는다.
    const live = current && !current.winner ? current : null;
    const source = live ?? last ?? current ?? {};
    const lastStarter = live ? live.starter : (last?.lastStarter ?? current?.starter ?? null);
    const starter = players.includes(lastStarter) ? players.find((p) => p !== lastStarter) : null;
    await createGame(kit, roomCode, {
      players,
      pieces: source.pieceCount,
      stake: source.stake ?? 0,
      gameId: kit.randomUUID(),
      starter,
      characters: assignCharacters(players, source.characters),
      bgm: source.bgm,
    });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const state = await readState(kit, roomCode);
    if (!state || state.winner || !state.playersOrder?.includes(userId)) return false;
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
      socket.emit("game:yut:state", serializeYutState(fresh));
      return true;
    }
    if (!timers.has(roomCode)) scheduleTurnTimer(kit, roomCode, state);
    socket.emit("game:yut:state", serializeYutState(state));
    return true;
  },

  afk(kit) {
    return {
      key: yutGameKey,
      playersOf: (s) => s.playersOrder ?? [],
      waitingOn: (s) => (s.winner ? null : s.currentTurn ?? null),
      forfeit: async (roomCode, s, loser, winner) => {
        await finishYutGame(kit, roomCode, s, "forfeit", winner ?? otherPlayer(s, loser));
      },
    };
  },

  dispose() {
    for (const roomCode of [...timers.keys()]) clearTurnTimer(roomCode);
  },
};
