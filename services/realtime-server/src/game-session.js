// game-session.js
// Game-view occupancy tracking and lobby-join resume resolution.
// Accepts io and redis explicitly so tests can inject fakes.

import { DEFAULT_UNO_MODE } from './uno-engine.js';
import { serializeYutGame } from './yut-engine.js';

export const viewerRoomKey = (roomCode, gameType) =>
  `game-view:${roomCode}:${gameType}`;

// Games with durable Redis state and per-user serialization that can be resumed.
export const RESUMABLE_GAME_TYPES = new Set(['yut', 'uno']);

export const activeGameKey = (roomCode, gameType) => {
  if (gameType === 'yut') return `yut:${roomCode}:game`;
  if (gameType === 'uno') return `uno:${roomCode}:game`;
  return null;
};

export const getViewerCount = (io, roomCode, gameType) => {
  const room = io.sockets.adapter.rooms.get(viewerRoomKey(roomCode, gameType));
  return room ? room.size : 0;
};

// Per-user UNO serialization — never exposes the opponent's hand.
// Mirrors the session:restore logic in socket.js.
export const serializeUnoGameFor = (game, userId) => {
  if (!game.hands || !game.discardPile) return null;
  const handCount = Object.fromEntries(
    Object.entries(game.hands).map(([uid, hand]) => [uid, Array.isArray(hand) ? hand.length : 0]),
  );
  return {
    gameId: 'active',
    turn: game.currentPlayer,
    mode: game.mode ?? DEFAULT_UNO_MODE,
    topCard: game.discardPile[game.discardPile.length - 1],
    declaredColor: game.declaredColor ?? null,
    drawStack: game.drawStack ?? 0,
    drawStackType: game.drawStackType ?? null,
    handCount,
    hand: game.hands[userId] ?? [],
    drawnCardId: game.drawnCardId ?? null,
    unoCallNeeded: game.unoCallNeeded ?? null,
  };
};

// Check for an active game that can be resumed by this socket.
// Side effect: joins the socket to the viewer subroom BEFORE returning to prevent
// the race where the last current viewer leaves before this socket finishes mounting.
// Returns { status: 'resumed', gameType, state } or null (caller creates a normal lobby).
export const resolveLobbyJoinForResume = async (socket, io, redis, { roomCode, gameType, userId }) => {
  // Primary guard: only resumable types. activeGameKey is a secondary lookup.
  if (!RESUMABLE_GAME_TYPES.has(gameType)) return null;
  const key = activeGameKey(roomCode, gameType);
  if (!key) return null;

  const rawState = await redis.get(key);
  if (!rawState) return null;

  const viewerCount = getViewerCount(io, roomCode, gameType);

  if (viewerCount === 0) {
    // Active state exists but nobody is viewing — stale. Delete it so normal lobby proceeds.
    await redis.del(key).catch(() => {});
    return null;
  }

  // Reserve this socket in the subroom before acking to close the last-viewer race window.
  await socket.join(viewerRoomKey(roomCode, gameType));
  socket.data.viewingGame = gameType;

  const game = JSON.parse(rawState);
  let state = null;
  if (gameType === 'yut') {
    state = serializeYutGame(game);
  } else if (gameType === 'uno') {
    state = serializeUnoGameFor(game, userId);
  }

  return { status: 'resumed', gameType, state };
};

// Register game:session:enter and game:session:leave for a socket.
export const registerGameSessionHandlers = (socket, { io, redis }) => {
  socket.on('game:session:enter', async (payload, ackRaw) => {
    const ack = typeof ackRaw === 'function' ? ackRaw : () => {};
    const roomCode = socket.data.roomCode;
    if (!roomCode || !socket.data.userId) return ack({ ok: false, reason: 'not_joined' });
    const gameType = payload?.gameType;
    if (!RESUMABLE_GAME_TYPES.has(gameType)) return ack({ ok: false, reason: 'invalid_game_type' });
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
    await _maybeCleanupGame(io, redis, roomCode, gameType);
    ack({ ok: true });
  });
};

// Call from the disconnect handler.
// By the time disconnect fires, the socket has already left all rooms,
// so getViewerCount correctly reflects the remaining count.
export const cleanupGameSessionOnDisconnect = async (socket, io, redis) => {
  const roomCode = socket.data.roomCode;
  const gameType = socket.data.viewingGame;
  if (!roomCode || !gameType) return;
  await _maybeCleanupGame(io, redis, roomCode, gameType);
};

const _maybeCleanupGame = async (io, redis, roomCode, gameType) => {
  if (getViewerCount(io, roomCode, gameType) > 0) return;
  const key = activeGameKey(roomCode, gameType);
  if (key) await redis.del(key).catch(() => {});
};
