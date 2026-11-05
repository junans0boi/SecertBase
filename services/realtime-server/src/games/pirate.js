// 해적 룰렛 2.0 게임 모듈(04-foundation-api.md). 규칙은 ../pirate-engine.js.
//
// 판은 로비 시작과 함께 서버가 만든다(구멍 수 = 로비 옵션 holes). 상태 키는
// `pirate:<room>:game`이고 폭발 뒤에도 지우지 않는다(벌칙 단계·복원·재대결이 쓴다).
// 모든 변화 뒤에 방 전체로 `game:pirate:state`(공개 상태)를 보내고, 연출용으로
// `slot_picked`·`exploded`·`penalty`·`penalty_done`도 보낸다. 계약: docs/socket-events/pirate.md.
import { normalizeLobbyOptions } from "../lobby-options.js";
import {
  applyForfeit,
  applyStab,
  applyTimeout,
  completePenalty,
  createPirateGame,
  nextFirstTurn,
  publicPirateState,
  remainingOf,
  riskPct,
  setPenalty,
} from "../pirate-engine.js";

const GAME_TYPE = "pirate";
const STATE_TTL_SEC = 3600;
/** 재대결은 로비 카운트다운이 없으니 첫 차례 전에 잠깐 숨을 돌린다. */
const RESTART_GRACE_MS = 1500;

export const pirateKey = (roomCode) => `pirate:${roomCode}:game`;

const turnTimers = new Map(); // roomCode → { handle, timerApi }

function clearTurnTimer(roomCode) {
  const entry = turnTimers.get(roomCode);
  if (!entry) return;
  entry.timerApi.clearTimeout(entry.handle);
  turnTimers.delete(roomCode);
}

async function readState(kit, roomCode) {
  const raw = await kit.redis.get(pirateKey(roomCode));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

const writeState = (kit, roomCode, state) =>
  kit.redis.set(pirateKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);

const pirate = {
  gameType: GAME_TYPE,
  /** 선공·폭탄 위치용 난수. 테스트가 바꿔 끼운다. */
  random: Math.random,

  register(socket, kit) {
    const joined = (ack) => {
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return null;
      }
      return { roomCode, userId };
    };

    // 화면이 열릴 때 현재 상태를 받는다(없으면 state: null → "판을 준비하는 중").
    socket.on("game:pirate:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const who = joined(ack);
      if (!who) return;
      const state = await readState(kit, who.roomCode);
      if (!state || !state.players.includes(who.userId)) {
        ack({ ok: true, state: null });
        return;
      }
      const view = await this.view(kit, who.roomCode, state);
      socket.emit("game:pirate:state", view);
      ack({ ok: true, state: view });
    });

    socket.on("game:pirate:pick", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const who = joined(ack);
      if (!who) return;
      const slot = payload?.slot;
      if (!Number.isInteger(slot)) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }
      await kit.withRoomLock(who.roomCode, async () => {
        const state = await readState(kit, who.roomCode);
        if (!state) {
          ack({ ok: false, reason: "no_game" });
          return;
        }
        if (payload?.gameId && payload.gameId !== state.gameId) {
          ack({ ok: false, reason: "stale_game" });
          return;
        }
        const result = applyStab(state, who.userId, slot, { now: Date.now() });
        if (!result.ok) {
          ack({ ok: false, reason: result.reason });
          return;
        }
        await this.commitStab(kit, who.roomCode, result.state, { slot, by: who.userId, auto: false });
        ack({ ok: true, exploded: result.exploded });
      });
    });

    // 이긴 사람이 벌칙을 정한다(한 번, 1~30자).
    socket.on("game:pirate:penalty", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const who = joined(ack);
      if (!who) return;
      await kit.withRoomLock(who.roomCode, async () => {
        const state = await readState(kit, who.roomCode);
        if (!state) {
          ack({ ok: false, reason: "no_game" });
          return;
        }
        const result = setPenalty(state, who.userId, payload?.text, { now: Date.now() });
        if (!result.ok) {
          ack({ ok: false, reason: result.reason });
          return;
        }
        await writeState(kit, who.roomCode, result.state);
        kit.io.to(who.roomCode).emit("game:pirate:penalty", {
          gameId: state.gameId,
          by: who.userId,
          text: result.state.penalty.text,
        });
        await this.broadcast(kit, who.roomCode, result.state);
        ack({ ok: true, text: result.state.penalty.text });
      });
    });

    // 진 사람이 "했어요!"를 누른다(한 번).
    socket.on("game:pirate:penalty_done", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const who = joined(ack);
      if (!who) return;
      await kit.withRoomLock(who.roomCode, async () => {
        const state = await readState(kit, who.roomCode);
        if (!state) {
          ack({ ok: false, reason: "no_game" });
          return;
        }
        const result = completePenalty(state, who.userId, { now: Date.now() });
        if (!result.ok) {
          ack({ ok: false, reason: result.reason });
          return;
        }
        await writeState(kit, who.roomCode, result.state);
        kit.io.to(who.roomCode).emit("game:pirate:penalty_done", { gameId: state.gameId, by: who.userId });
        await this.broadcast(kit, who.roomCode, result.state);
        ack({ ok: true });
      });
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    const { holes } = normalizeLobbyOptions(GAME_TYPE, ctx.options);
    await kit.withRoomLock(roomCode, async () => {
      const state = createPirateGame({
        players: ctx.players.slice(0, 2),
        holes,
        gameId: ctx.gameId ?? kit.randomUUID(),
        random: this.random,
        now: Date.now(),
        startsAt: ctx.startsAt ?? Date.now(),
      });
      await this.begin(kit, roomCode, state);
    });
  },

  // socket.js가 방 잠금을 쥔 채로 부른다(game:restart:respond) → 여기서 다시 잠그지 않는다.
  async restart(roomCode, kit, ctx) {
    const previous = await readState(kit, roomCode);
    const players = previous?.players?.length === 2 && previous.players.every((p) => ctx.orderedPlayers.includes(p))
      ? previous.players
      : [ctx.p1, ctx.p2];
    const now = Date.now();
    const state = createPirateGame({
      players,
      holes: previous?.slots,
      gameId: kit.randomUUID(),
      random: this.random,
      now,
      startsAt: now + RESTART_GRACE_MS,
      firstTurn: nextFirstTurn(previous, players),
      round: (previous?.round ?? 0) + 1,
    });
    await this.begin(kit, roomCode, state);
  },

  async restore(roomCode, socket, kit) {
    const state = await readState(kit, roomCode);
    if (!state || !state.players.includes(socket.data.userId)) return false;
    // 서버가 다시 켜졌으면 차례 타이머가 없다. 진행 중인 판이면 다시 건다.
    if (!turnTimers.has(roomCode)) this.scheduleTurn(kit, roomCode, state);
    socket.emit("game:pirate:state", await this.view(kit, roomCode, state));
    return true;
  },

  afk(kit) {
    return {
      key: pirateKey,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => (s.phase === "playing" ? s.currentTurn ?? null : null),
      forfeit: async (roomCode, s, loser) => {
        const result = applyForfeit(s, loser, { now: Date.now() });
        if (!result.ok) return;
        await this.finish(kit, roomCode, result.state, { slot: null, by: loser, auto: false });
      },
    };
  },

  dispose() {
    for (const roomCode of [...turnTimers.keys()]) clearTurnTimer(roomCode);
  },

  // ── 내부 ──────────────────────────────────────────────────────────────

  async view(kit, roomCode, state) {
    const series = await kit.series.get(roomCode, GAME_TYPE, state.players);
    return publicPirateState(state, { series, now: Date.now() });
  },

  async broadcast(kit, roomCode, state, series) {
    const view = series
      ? publicPirateState(state, { series, now: Date.now() })
      : await this.view(kit, roomCode, state);
    kit.io.to(roomCode).emit("game:pirate:state", view);
    return view;
  },

  async begin(kit, roomCode, state) {
    await writeState(kit, roomCode, state);
    await this.broadcast(kit, roomCode, state);
    this.scheduleTurn(kit, roomCode, state);
  },

  /** 찌르기 결과를 저장하고 알린다(폭발이면 정산까지). */
  async commitStab(kit, roomCode, state, { slot, by, auto }) {
    if (state.phase === "exploded") {
      await this.finish(kit, roomCode, state, { slot, by, auto });
      return;
    }
    await writeState(kit, roomCode, state);
    const remaining = remainingOf(state);
    kit.io.to(roomCode).emit("game:pirate:slot_picked", {
      gameId: state.gameId,
      slot,
      by,
      auto,
      nextTurn: state.currentTurn,
      pickedSlots: state.pickedSlots,
      remaining,
      riskPct: riskPct(remaining),
      turnDeadline: state.turnDeadline,
      serverNow: Date.now(),
    });
    await this.broadcast(kit, roomCode, state);
    this.scheduleTurn(kit, roomCode, state);
  },

  /** 폭발(또는 기권): 상태를 보존하고 결과·전적을 한 번 기록한다. */
  async finish(kit, roomCode, state, { slot, by, auto }) {
    clearTurnTimer(roomCode);
    await writeState(kit, roomCode, state);
    let series = null;
    try {
      series = await kit.series.record(roomCode, GAME_TYPE, state.players, state.winner);
    } catch (err) {
      console.error("[pirate] series record failed:", err.message);
    }
    kit.io.to(roomCode).emit("game:pirate:exploded", {
      gameId: state.gameId,
      loser: state.loser,
      winner: state.winner,
      bombSlot: state.bombSlot,
      slot,
      by,
      auto,
      reason: state.reason,
      forfeit: state.reason !== "bomb",
      series,
      at: Date.now(),
    });
    await this.broadcast(kit, roomCode, state, series);
    try {
      await kit.recordGameOutcome(roomCode, {
        winner: state.winner,
        players: state.players,
        gameType: GAME_TYPE,
        gameId: state.gameId,
      });
    } catch (err) {
      console.error("[pirate] recordGameOutcome failed:", err.message);
    }
  },

  /** 차례 마감에 자동 찌르기를 건다. 판·차례가 바뀌었으면 아무것도 하지 않는다. */
  scheduleTurn(kit, roomCode, state) {
    clearTurnTimer(roomCode);
    if (state.phase !== "playing" || !state.turnDeadline) return;
    const { gameId, seq } = state;
    const delay = Math.max(0, state.turnDeadline - Date.now());
    const entry = { timerApi: kit.timerApi, handle: null };
    entry.handle = kit.timerApi.setTimeout(() => {
      if (turnTimers.get(roomCode) === entry) turnTimers.delete(roomCode);
      void kit.withRoomLock(roomCode, async () => {
        const current = await readState(kit, roomCode);
        if (!current || current.gameId !== gameId || current.seq !== seq || current.phase !== "playing") return;
        const result = applyTimeout(current, { random: this.random, now: Date.now() });
        if (!result.ok) return;
        if (result.forfeit) {
          await this.finish(kit, roomCode, result.state, { slot: null, by: current.currentTurn, auto: true });
          return;
        }
        await this.commitStab(kit, roomCode, result.state, { slot: result.slot, by: current.currentTurn, auto: true });
      }).catch((err) => console.error("[pirate] turn timeout failed:", err.message));
    }, delay);
    entry.handle?.unref?.();
    turnTimers.set(roomCode, entry);
  },
};

export default pirate;
