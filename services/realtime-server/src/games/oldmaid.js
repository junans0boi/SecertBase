// 도둑잡기 2.0 게임 모듈(서버 동작 전부). 규칙은 oldmaid-engine.js.
//
// 이벤트(자세한 계약은 docs/socket-events/oldmaid.md):
//   C→S game:oldmaid:sync {}                      → 이 소켓에 현재 상태를 다시 보냄
//   C→S game:oldmaid:draw { slot | cardId:'slot-N', gameId? }
//   S→C game:oldmaid:state  사용자별 상태(내 손패는 카드, 상대 손패는 slot-N 별칭)
//   S→C game:oldmaid:drawn  사용자별 뽑기 결과(뽑은 사람=뽑은 카드, 뺏긴 사람=뺏긴 자기 카드)
import {
  drawAt,
  drawnFor,
  forfeit,
  initGame,
  opponentOf,
  parseSlot,
  projectFor,
} from "../oldmaid-engine.js";

export const GAME_TYPE = "oldmaid";
/** 한 차례 제한 시간. 지나면 서버가 상대 손패에서 무작위로 한 장을 대신 뽑는다. */
export const OLDMAID_TURN_MS = 25_000;
/** 뽑기 연출(올라옴→뒤집힘→이동)이 끝날 시간을 다음 차례 마감에 더한다. */
export const OLDMAID_DRAW_FX_MS = 1_800;
/** 재대결 직후 카드 나눠 주기 연출 시간. */
export const OLDMAID_DEAL_FX_MS = 2_000;
/** 연속 시간 초과가 이만큼이면 기권패. */
export const OLDMAID_MAX_TIMEOUTS = 3;
const TTL_SEC = 3600;

export const oldmaidKey = (roomCode) => `oldmaid:${roomCode}:game`;

const timers = new Map(); // roomCode → handle

const mod = {
  gameType: GAME_TYPE,
  /** 테스트가 바꿀 수 있는 무작위 원천. */
  random: Math.random,

  register(socket, kit) {
    socket.on("game:oldmaid:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const game = await load(kit, roomCode);
      if (!game) return ack({ ok: false, reason: "no_game" });
      socket.emit("game:oldmaid:state", view(game, userId));
      return ack({ ok: true, gameId: game.gameId, status: game.status });
    });

    socket.on("game:oldmaid:draw", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const slot = parseSlot(payload?.slot ?? payload?.cardId);
      if (slot === null) return ack({ ok: false, reason: "invalid_payload" });
      await kit.withRoomLock(roomCode, async () => {
        const game = await load(kit, roomCode);
        if (!game) return ack({ ok: false, reason: "no_game" });
        if (payload?.gameId && payload.gameId !== game.gameId) return ack({ ok: false, reason: "stale_game" });
        const result = drawAt(game, String(userId), slot, { random: mod.random, now: Date.now() });
        if (result.error) return ack({ ok: false, reason: result.error });
        await commit(kit, roomCode, result.game, result.draw);
        return ack({ ok: true });
      });
      return undefined;
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    const [p1, p2] = ctx.players ?? [];
    if (!p1 || !p2) return;
    const startsAt = Number(ctx.startsAt) || Date.now();
    await kit.withRoomLock(roomCode, () => begin(kit, roomCode, [p1, p2], {
      gameId: ctx.gameId ?? kit.randomUUID(),
      firstTurn: null,
      deadline: startsAt + OLDMAID_TURN_MS,
    }));
  },

  // 재대결: socket.js가 이미 방 잠금 안에서 부른다. 전적은 이어지고 선공은 바뀐다.
  async restart(roomCode, kit, ctx) {
    const previous = await load(kit, roomCode);
    const samePair = previous && [ctx.p1, ctx.p2].every((p) => previous.players.includes(p));
    const players = samePair ? previous.players : [ctx.p1, ctx.p2];
    const firstTurn = samePair && previous.firstTurn ? opponentOf(previous, previous.firstTurn) : null;
    await begin(kit, roomCode, players, {
      gameId: kit.randomUUID(),
      firstTurn,
      deadline: Date.now() + OLDMAID_DEAL_FX_MS + OLDMAID_TURN_MS,
    });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const game = await load(kit, roomCode);
    if (!game || game.status !== "playing" || !game.players.includes(userId)) return false;
    // 서버가 다시 켜졌으면 차례 타이머가 없다. 진행 중인 판이면 다시 건다.
    if (!timers.has(roomCode)) scheduleTurnTimer(kit, roomCode, game);
    socket.emit("game:oldmaid:state", view(game, userId));
    return true;
  },

  afk(kit) {
    return {
      key: oldmaidKey,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => (s.status === "playing" ? s.turn ?? null : null),
      forfeit: async (roomCode, s, loser) => {
        if (s.status !== "playing") return;
        await commit(kit, roomCode, forfeit(s, loser, "afk"), null);
      },
    };
  },

  dispose() {
    for (const roomCode of [...timers.keys()]) clearTurnTimer(roomCode);
  },
};

export default mod;

async function load(kit, roomCode) {
  const raw = await kit.redis.get(oldmaidKey(roomCode));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function view(game, viewerId) {
  return {
    ...projectFor(game, viewerId),
    series: game.series ?? null,
    turnDeadline: game.status === "playing" ? game.turnDeadline ?? null : null,
    turnMs: OLDMAID_TURN_MS,
    serverNow: Date.now(),
  };
}

async function begin(kit, roomCode, players, { gameId, firstTurn, deadline }) {
  clearTurnTimer(roomCode);
  const game = initGame(players[0], players[1], { random: mod.random, gameId, firstTurn });
  game.series = await kit.series.get(roomCode, GAME_TYPE, players);
  game.turnDeadline = deadline;
  await commit(kit, roomCode, game, null, { fresh: true });
}

/**
 * 상태를 저장하고 사용자별로 내보낸다. 판이 막 끝났으면 전적·결과를 한 번만 기록한다.
 * [draw]가 있으면 상태보다 먼저 사용자별 `drawn`을 보낸다(연출이 상태 갱신보다 앞선다).
 */
async function commit(kit, roomCode, game, draw, { fresh = false } = {}) {
  const justFinished = game.status === "finished" && !game.recorded;
  if (justFinished) {
    clearTurnTimer(roomCode);
    game.series = await kit.series.record(roomCode, GAME_TYPE, game.players, game.result?.winner ?? null);
    game.recorded = true;
    game.turnDeadline = null;
  } else if (game.status === "playing" && !fresh) {
    game.turnDeadline = Date.now() + (draw ? OLDMAID_DRAW_FX_MS : 0) + OLDMAID_TURN_MS;
  }
  await kit.redis.set(oldmaidKey(roomCode), JSON.stringify(game), "EX", TTL_SEC);
  const sockets = await kit.io.in(roomCode).fetchSockets();
  for (const s of sockets) {
    const userId = s.data.userId;
    if (draw) s.emit("game:oldmaid:drawn", drawnFor(game, draw, userId));
    s.emit("game:oldmaid:state", view(game, userId));
  }
  if (justFinished) {
    await kit.recordGameOutcome(roomCode, {
      winner: game.result?.winner ?? null,
      players: game.players,
      gameType: GAME_TYPE,
      gameId: game.gameId,
    });
  } else if (game.status === "playing") {
    scheduleTurnTimer(kit, roomCode, game);
  }
}

function clearTurnTimer(roomCode, timerApi) {
  const entry = timers.get(roomCode);
  if (!entry) return;
  (timerApi ?? entry.timerApi).clearTimeout(entry.handle);
  timers.delete(roomCode);
}

function scheduleTurnTimer(kit, roomCode, game) {
  clearTurnTimer(roomCode, kit.timerApi);
  const expect = { gameId: game.gameId, drawCount: game.drawCount, turn: game.turn };
  const entry = { timerApi: kit.timerApi, handle: null };
  entry.handle = kit.timerApi.setTimeout(() => {
    if (timers.get(roomCode) === entry) timers.delete(roomCode);
    void kit.withRoomLock(roomCode, () => onTimeout(kit, roomCode, expect))
      .catch((err) => console.error(`[oldmaid] turn timeout failed: ${err.message}`));
  }, Math.max(0, (game.turnDeadline ?? Date.now()) - Date.now()));
  entry.handle?.unref?.();
  timers.set(roomCode, entry);
}

/** 시간 초과: 상대 손패에서 무작위로 한 장을 대신 뽑는다. 연속 3회째면 기권패. */
async function onTimeout(kit, roomCode, expect) {
  const game = await load(kit, roomCode);
  if (!game || game.status !== "playing") return;
  if (game.gameId !== expect.gameId || game.drawCount !== expect.drawCount || game.turn !== expect.turn) return;
  if ((game.timeouts?.[game.turn] ?? 0) + 1 >= OLDMAID_MAX_TIMEOUTS) {
    await commit(kit, roomCode, forfeit(game, game.turn, "timeout"), null);
    return;
  }
  const victim = opponentOf(game, game.turn);
  const slot = Math.floor(mod.random() * game.hands[victim].length);
  const result = drawAt(game, game.turn, slot, { random: mod.random, now: Date.now(), auto: true });
  if (result.error) return;
  await commit(kit, roomCode, result.game, result.draw);
}
