// game-afk.js — 턴제 게임 공통 잠수(AFK) 감시
//
// 차례인 플레이어가 TURN_ACTION_MS 동안 아무 행동도 하지 않으면 기권패로 처리한다.
// WARNING_AFTER_MS 시점에 한 번 경고를 보낸다. 게임마다 다른 부분(지금 누구를
// 기다리는지, 기권 처리 방법)은 어댑터로 주입한다.
//
// 통합 지점은 하나다: 게임 이벤트 핸들러가 끝날 때마다 refresh(roomCode, gameType)를
// 호출한다. refresh는 Redis 상태를 읽어 "기다리는 사람 + 상태 지문"이 바뀌었으면
// 타이머를 다시 건다. 상태가 바뀌지 않는 이벤트(채팅·리액션)는 시계를 되돌리지 않는다.
// 서버 타이머로 상태가 바뀐 경우(카운트다운 등)는 만료 시점에 지문이 달라 다시 건다.

export const TURN_ACTION_MS = 90_000;
export const WARNING_AFTER_MS = 60_000;

// 상태 문자열 지문(djb2). 같은 상태면 같은 값.
export function fingerprint(raw) {
  let h = 5381;
  for (let i = 0; i < raw.length; i++) h = ((h << 5) + h + raw.charCodeAt(i)) | 0;
  return `${raw.length}:${h >>> 0}`;
}

/**
 * adapters: { [gameType]: { key(roomCode), waitingOn(state) -> userId|null,
 *                           forfeit(roomCode, state, loserId) -> Promise } }
 */
export function createAfkWatcher({ io, redis, timerApi, withRoomLock, adapters, logger = console }) {
  const entries = new Map(); // `${roomCode}:${gameType}` → { waitingOn, marker, warn, end }

  const clearEntry = (id) => {
    const entry = entries.get(id);
    if (!entry) return;
    if (entry.warn) timerApi.clearTimeout(entry.warn);
    if (entry.end) timerApi.clearTimeout(entry.end);
    entries.delete(id);
  };

  const readState = async (roomCode, adapter) => {
    const raw = await redis.get(adapter.key(roomCode));
    if (!raw) return null;
    try {
      return { raw, state: JSON.parse(raw) };
    } catch {
      return null;
    }
  };

  const schedule = (roomCode, gameType, waitingOn, marker) => {
    const id = `${roomCode}:${gameType}`;
    clearEntry(id);
    const entry = { waitingOn, marker, warn: null, end: null };

    entry.warn = timerApi.setTimeout(() => {
      entry.warn = null;
      void (async () => {
        const adapter = adapters[gameType];
        const current = await readState(roomCode, adapter);
        if (!current || fingerprint(current.raw) !== marker) return;
        io.to(roomCode).emit("game:afk:warning", {
          gameType,
          player: waitingOn,
          secondsLeft: Math.round((TURN_ACTION_MS - WARNING_AFTER_MS) / 1000),
        });
      })().catch((err) => logger.error(`[afk] warning failed: ${err.message}`));
    }, WARNING_AFTER_MS);
    entry.warn.unref?.();

    entry.end = timerApi.setTimeout(() => {
      entry.end = null;
      entries.delete(id);
      void withRoomLock(roomCode, async () => {
        const adapter = adapters[gameType];
        const current = await readState(roomCode, adapter);
        if (!current) return;
        const nowWaiting = adapter.waitingOn(current.state);
        if (!nowWaiting) return;
        // 그사이 서버 쪽에서 상태가 바뀌었으면(카운트다운 종료 등) 지금부터 다시 센다.
        if (fingerprint(current.raw) !== marker || nowWaiting !== waitingOn) {
          schedule(roomCode, gameType, nowWaiting, fingerprint(current.raw));
          return;
        }
        const winner = adapter.playersOf(current.state).find((p) => p !== waitingOn) ?? null;
        io.to(roomCode).emit("game:afk:forfeit", { gameType, loser: waitingOn, winner });
        await adapter.forfeit(roomCode, current.state, waitingOn, winner);
      }).catch((err) => logger.error(`[afk] forfeit failed: ${err.message}`));
    }, TURN_ACTION_MS);
    entry.end.unref?.();

    entries.set(id, entry);
  };

  /** 이벤트 처리 직후 호출: 기다리는 사람이나 상태가 바뀌었으면 시계를 다시 건다. */
  const refresh = async (roomCode, gameType) => {
    const adapter = adapters[gameType];
    if (!adapter || !roomCode) return;
    const id = `${roomCode}:${gameType}`;
    const current = await readState(roomCode, adapter);
    const waitingOn = current ? adapter.waitingOn(current.state) : null;
    if (!waitingOn) {
      clearEntry(id);
      return;
    }
    const marker = fingerprint(current.raw);
    const existing = entries.get(id);
    if (existing && existing.waitingOn === waitingOn && existing.marker === marker) return;
    schedule(roomCode, gameType, waitingOn, marker);
  };

  const clearAll = () => {
    for (const id of [...entries.keys()]) clearEntry(id);
  };

  return { refresh, clearAll, has: (roomCode, gameType) => entries.has(`${roomCode}:${gameType}`) };
}

/** 소켓 이벤트 이름 → AFK 감시 대상 게임 종류 */
export function afkGameTypeForEvent(event, payload) {
  if (event === "game:restart:respond") return payload?.gameType ?? null;
  const match = /^game:([a-z]+):/.exec(event);
  return match ? match[1] : null;
}
