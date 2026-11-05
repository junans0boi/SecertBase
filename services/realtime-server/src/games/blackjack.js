// 블랙잭 2.0 게임 모듈. 규칙은 ../blackjack-engine.js, 소켓 계약은 docs/socket-events/blackjack.md.
//
// 이벤트(클라이언트 → 서버, 모두 ack {ok, reason?}):
//   game:blackjack:sync        현재 상태를 이 소켓에 다시 보낸다
//   game:blackjack:hit         카드 한 장
//   game:blackjack:stand       멈추기
//   game:blackjack:next_round  라운드 결과에서 "다음 라운드" 준비
// 서버 → 클라이언트:
//   game:blackjack:updated     보는 사람별 투영(serializeFor) — 상태가 바뀔 때마다
import {
  createMatch,
  hit,
  stand,
  nextRound,
  timeoutTurn,
  forfeit,
  serializeFor,
  otherPlayer,
} from "../blackjack-engine.js";

const GAME_TYPE = "blackjack";
const STATE_TTL_SEC = 3600;
const stateKey = (roomCode) => `game:${roomCode}:blackjack`;

// 방별 턴 타이머. 서버 종료 시 dispose가 정리한다.
const turnTimers = new Map(); // roomCode → { handle, timerApi }

// 테스트가 선공을 고정할 수 있게 random을 바꿀 수 있다.
let random = Math.random;
export function setBlackjackRandom(fn) {
  random = typeof fn === "function" ? fn : Math.random;
}

async function load(kit, roomCode) {
  const raw = await kit.redis.get(stateKey(roomCode));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function save(kit, roomCode, game) {
  await kit.redis.set(stateKey(roomCode), JSON.stringify(game), "EX", STATE_TTL_SEC);
}

async function emitState(kit, roomCode, game) {
  const sockets = await kit.io.in(roomCode).fetchSockets();
  const now = Date.now();
  for (const roomSocket of sockets) {
    roomSocket.emit("game:blackjack:updated", serializeFor(game, roomSocket.data.userId, { now }));
  }
}

function clearTurnTimer(roomCode) {
  const entry = turnTimers.get(roomCode);
  if (!entry) return;
  entry.timerApi.clearTimeout(entry.handle);
  turnTimers.delete(roomCode);
}

/** 판이 끝났으면 전적·결과를 한 번만 기록한다(gameId로도 멱등). */
async function finalize(kit, roomCode, game) {
  if (game.status !== "finished" || game.recorded) return game;
  const winner = game.result?.winner && game.result.winner !== "tie" ? game.result.winner : null;
  const series = await kit.series.record(roomCode, GAME_TYPE, game.players, winner);
  await kit.recordGameOutcome(roomCode, {
    winner: winner ?? "draw",
    players: game.players,
    gameType: GAME_TYPE,
    gameId: game.gameId ?? null,
  });
  return { ...game, recorded: true, series };
}

/** 상태 저장 → 기록 → 전송 → 타이머 재설정. 상태를 바꾼 모든 경로가 이것을 거친다. */
async function commit(kit, roomCode, game) {
  const finalGame = await finalize(kit, roomCode, game);
  await save(kit, roomCode, finalGame);
  await emitState(kit, roomCode, finalGame);
  scheduleTurnTimer(kit, roomCode, finalGame);
  return finalGame;
}

function scheduleTurnTimer(kit, roomCode, game) {
  clearTurnTimer(roomCode);
  if (game.status !== "playing" || game.phase !== "player_turn" || !game.turnDeadline) return;
  const expected = { gameId: game.gameId, round: game.round, turn: game.currentTurn, deadline: game.turnDeadline };
  const delay = Math.max(0, game.turnDeadline - Date.now());
  const handle = kit.timerApi.setTimeout(() => {
    if (turnTimers.get(roomCode)?.handle === handle) turnTimers.delete(roomCode);
    void kit.withRoomLock(roomCode, async () => {
      const current = await load(kit, roomCode);
      if (
        !current ||
        current.gameId !== expected.gameId ||
        current.round !== expected.round ||
        current.currentTurn !== expected.turn ||
        current.turnDeadline !== expected.deadline
      ) return;
      const { game: next, timedOut } = timeoutTurn(current, { now: Date.now() });
      if (!timedOut) return;
      await commit(kit, roomCode, next);
    }).catch((err) => console.error(`[blackjack] turn timeout failed: ${err.message}`));
  }, delay);
  handle?.unref?.();
  turnTimers.set(roomCode, { handle, timerApi: kit.timerApi });
}

async function startMatch(kit, roomCode, { players, gameId, firstPlayer = null, now = Date.now() }) {
  const series = await kit.series.get(roomCode, GAME_TYPE, players);
  const game = createMatch({
    players,
    gameId: gameId ?? kit.randomUUID(),
    firstPlayer,
    random,
    now,
    series,
  });
  return commit(kit, roomCode, game);
}

function registerAction(socket, kit, event, apply) {
  socket.on(event, async (_payload, ackRaw) => {
    const ack = kit.normalizeAck(ackRaw);
    const { roomCode, userId } = socket.data;
    if (!roomCode || !userId) {
      ack({ ok: false, reason: "not_joined" });
      return;
    }
    await kit.withRoomLock(roomCode, async () => {
      const game = await load(kit, roomCode);
      if (!game) {
        ack({ ok: false, reason: "no_game" });
        return;
      }
      const result = apply(game, userId, { now: Date.now(), random });
      if (!result.ok) {
        ack({ ok: false, reason: result.reason });
        return;
      }
      await commit(kit, roomCode, result.game);
      ack({ ok: true });
    });
  });
}

export default {
  gameType: GAME_TYPE,

  register(socket, kit) {
    socket.on("game:blackjack:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      const game = await load(kit, roomCode);
      if (!game || !game.players.includes(userId)) {
        ack({ ok: true, state: null });
        return;
      }
      const view = serializeFor(game, userId, { now: Date.now() });
      socket.emit("game:blackjack:updated", view);
      ack({ ok: true, state: view });
    });
    registerAction(socket, kit, "game:blackjack:hit", hit);
    registerAction(socket, kit, "game:blackjack:stand", stand);
    registerAction(socket, kit, "game:blackjack:next_round", nextRound);
  },

  async startFromLobby(roomCode, kit, ctx) {
    await kit.withRoomLock(roomCode, () =>
      startMatch(kit, roomCode, {
        players: ctx.players.slice(0, 2),
        gameId: ctx.gameId,
        now: ctx.startsAt ?? Date.now(),
      }),
    );
  },

  async restart(roomCode, kit, ctx) {
    // restart는 socket.js가 이미 방 잠금 안에서 부른다.
    const players = [ctx.p1, ctx.p2];
    const previous = await load(kit, roomCode);
    // 끝난 판의 첫 선공과 반대 사람이 새 판을 연다(전적은 series 저장소가 잇는다).
    const firstPlayer = previous?.openingPlayer && players.includes(previous.openingPlayer)
      ? players.find((p) => p !== previous.openingPlayer)
      : null;
    await startMatch(kit, roomCode, { players, gameId: kit.randomUUID(), firstPlayer, now: Date.now() });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const game = await load(kit, roomCode);
    if (!game || game.status === "finished" || !game.players.includes(userId)) return false;
    // 서버가 다시 켜졌으면 차례 타이머가 없다. 진행 중인 판이면 다시 건다.
    if (!turnTimers.has(roomCode)) scheduleTurnTimer(kit, roomCode, game);
    socket.emit("game:blackjack:updated", serializeFor(game, userId, { now: Date.now() }));
    return true;
  },

  afk(kit) {
    return {
      key: stateKey,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => {
        if (s.status !== "playing") return null;
        if (s.phase === "player_turn") return s.currentTurn ?? null;
        if (s.phase === "round_result") {
          // 한 사람만 준비했으면 나머지 한 사람을 기다린다.
          const missing = (s.players ?? []).filter((p) => !s.ready?.[p]);
          return missing.length === 1 ? missing[0] : null;
        }
        return null;
      },
      forfeit: async (roomCode, s, loser) => {
        // game-afk가 이미 방 잠금 안에서 부른다.
        if (!s.players?.includes(loser) || !otherPlayer(s, loser)) return;
        await commit(kit, roomCode, forfeit(s, loser, "afk"));
      },
    };
  },

  dispose() {
    for (const roomCode of [...turnTimers.keys()]) clearTurnTimer(roomCode);
  },
};
