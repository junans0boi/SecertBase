// game-session.js
// Game-view occupancy tracking and lobby-join resume resolution.
// Accepts io and redis explicitly so tests can inject fakes.

import { serializeOneCardFor } from './uno-engine.js';
import { serializeYutGame } from './yut-engine.js';
import { serializeFor as serializeGostopGameFor } from './gostop-engine.js';
import { serializeMarbleGame } from './marble-engine.js';

export const viewerRoomKey = (roomCode, gameType) =>
  `game-view:${roomCode}:${gameType}`;

// Games with durable Redis state and per-user serialization that can be resumed.
export const RESUMABLE_GAME_TYPES = new Set(['yut', 'marble', 'uno', 'gostop']);

export const activeGameKey = (roomCode, gameType) => {
  if (gameType === 'yut') return `yut:${roomCode}:game`;
  if (gameType === 'uno') return `uno:${roomCode}:game`;
  if (gameType === 'gostop') return `gostop:${roomCode}:game`;
  if (gameType === 'marble') return `marble:${roomCode}:game`;
  return null;
};

// 마지막 뷰어가 나간 뒤 상태를 지우기까지의 유예 시간. 두 사람이 동시에 잠깐
// 앱을 내려도(백그라운드 전환, 네트워크 순단) 진행 중인 판이 사라지지 않게 한다.
// 잠수 기권 시간(90초)보다 길게 잡아, 차례인 사람이 나가 버린 판은 삭제되기 전에
// 기권패로 정산된다(지는 쪽이 나가서 정산을 피하는 구멍 차단).
export const SESSION_CLEANUP_GRACE_MS = 150_000;
const cleanupKey = (roomCode, gameType) => `${roomCode}:${gameType}`;

export const getViewerCount = (io, roomCode, gameType) => {
  const room = io.sockets.adapter.rooms.get(viewerRoomKey(roomCode, gameType));
  return room ? room.size : 0;
};

// Per-user one card (uno) view — never exposes the opponent's hand or the card
// the opponent just drew. Same shape as the game:uno:state event.
export const serializeUnoGameFor = (game, userId) => serializeOneCardFor(game, userId);

// Check for an active game that can be resumed by this socket.
// Side effect: joins the socket to the viewer subroom BEFORE returning to prevent
// the race where the last current viewer leaves before this socket finishes mounting.
// Returns { status: 'resumed', gameType, state } or null (caller creates a normal lobby).
export const resolveLobbyJoinForResume = async (socket, io, redis, { roomCode, gameType, userId }, scheduler = null) => {
  // Primary guard: only resumable types. activeGameKey is a secondary lookup.
  if (!RESUMABLE_GAME_TYPES.has(gameType)) return null;
  const key = activeGameKey(roomCode, gameType);
  if (!key) return null;

  const rawState = await redis.get(key);
  if (!rawState) return null;

  const viewerCount = getViewerCount(io, roomCode, gameType);
  const game = JSON.parse(rawState);
  const keepPendingSettlement = gameType === 'gostop' &&
    game.settlementStatus === 'pending';

  // 유예 중(정리 예약됨)인 판은 이어하기 대상이다. 예약이 없고 뷰어도 없으면 오래된 상태다.
  const graceActive = scheduler?.isPending?.(cleanupKey(roomCode, gameType)) ?? false;
  if (viewerCount === 0 && !keepPendingSettlement && !graceActive) {
    // Active state exists but nobody is viewing — stale. Delete it so normal lobby proceeds.
    await redis.del(key).catch(() => {});
    return null;
  }

  // Reserve this socket in the subroom before acking to close the last-viewer race window.
  scheduler?.cancel(cleanupKey(roomCode, gameType));
  await socket.join(viewerRoomKey(roomCode, gameType));
  socket.data.viewingGame = gameType;

  let state = null;
  if (gameType === 'yut') {
    state = serializeYutGame(game);
  } else if (gameType === 'uno') {
    state = serializeUnoGameFor(game, userId);
  } else if (gameType === 'gostop') {
    state = serializeGostopGameFor(game, userId);
  } else if (gameType === 'marble') {
    state = serializeMarbleGame(game);
  }

  return { status: 'resumed', gameType, state };
};

// Register game:session:enter and game:session:leave for a socket.
export const registerGameSessionHandlers = (socket, { io, redis, scheduler = null }) => {
  socket.on('game:session:enter', async (payload, ackRaw) => {
    const ack = typeof ackRaw === 'function' ? ackRaw : () => {};
    const roomCode = socket.data.roomCode;
    if (!roomCode || !socket.data.userId) return ack({ ok: false, reason: 'not_joined' });
    const gameType = payload?.gameType;
    if (!RESUMABLE_GAME_TYPES.has(gameType)) return ack({ ok: false, reason: 'invalid_game_type' });
    scheduler?.cancel(cleanupKey(roomCode, gameType));
    await socket.join(viewerRoomKey(roomCode, gameType));
    socket.data.viewingGame = gameType;
    ack({ ok: true });
  });

  socket.on('game:session:leave', async (payload, ackRaw) => {
    const ack = typeof ackRaw === 'function' ? ackRaw : () => {};
    const roomCode = socket.data.roomCode;
    if (!roomCode) return ack({ ok: false, reason: 'not_joined' });
    const gameType = payload?.gameType ?? socket.data.viewingGame;
    if (!gameType) return ack({ ok: true });
    await socket.leave(viewerRoomKey(roomCode, gameType));
    if (socket.data.viewingGame === gameType) socket.data.viewingGame = undefined;
    await _maybeCleanupGame(io, redis, roomCode, gameType, scheduler);
    ack({ ok: true });
  });
};

// Call from the disconnect handler.
// By the time disconnect fires, the socket has already left all rooms,
// so getViewerCount correctly reflects the remaining count.
export const cleanupGameSessionOnDisconnect = async (socket, io, redis, scheduler = null) => {
  const roomCode = socket.data.roomCode;
  const gameType = socket.data.viewingGame;
  if (!roomCode || !gameType) return;
  await _maybeCleanupGame(io, redis, roomCode, gameType, scheduler);
};

// scheduler가 있으면 유예 후 다시 확인하고 지운다. 없으면(단위 테스트) 즉시 지운다.
const _maybeCleanupGame = async (io, redis, roomCode, gameType, scheduler = null) => {
  if (getViewerCount(io, roomCode, gameType) > 0) return;
  if (scheduler) {
    scheduler.schedule(
      cleanupKey(roomCode, gameType),
      () => _maybeCleanupGame(io, redis, roomCode, gameType, null),
      SESSION_CLEANUP_GRACE_MS,
    );
    return;
  }
  const key = activeGameKey(roomCode, gameType);
  if (!key) return;
  if (gameType === 'gostop') {
    const raw = await redis.get(key).catch(() => null);
    if (raw) {
      try {
        if (JSON.parse(raw).settlementStatus === 'pending') return;
      } catch (_) {
        // Malformed state is safe to clean up below.
      }
    }
  }
  await redis.del(key).catch(() => {});
};
