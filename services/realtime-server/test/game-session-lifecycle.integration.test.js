/**
 * game-session-lifecycle.integration.test.js
 *
 * Public seams confirmed by user:
 *  - backend: game:lobby:join resumes an occupied active game (yut/uno)
 *  - backend: game:session:enter/leave tracks game-view occupancy
 *  - backend: last viewer leaving deletes active game state
 *
 * Uses a real in-process Socket.IO server with a Map-based fake Redis.
 * Does NOT connect to production DB or Redis.
 */

import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import { Server } from 'socket.io';
import { io as createClient } from 'socket.io-client';
import { installSocketAuthentication } from '../src/backend-access.js';
import {
  registerGameSessionHandlers,
  resolveLobbyJoinForResume,
  cleanupGameSessionOnDisconnect,
} from '../src/game-session.js';

const secret = 'game-session-test-secret-at-least-32x';
const roomCode = 'test-room-ABCD';

class FakeRedis {
  constructor(initial = {}) {
    this._s = new Map(Object.entries(initial));
  }
  async get(key) { return this._s.get(key) ?? null; }
  async set(key, val) { this._s.set(key, val); }
  async del(key) { this._s.delete(key); return 1; }
}

const normalizeAck = (ack) => (typeof ack === 'function' ? ack : () => {});
const listen = (s) => new Promise((r) => s.listen(0, '127.0.0.1', r));
const mkToken = (userId) => jwt.sign({ userId }, secret);

const YUT_STATE = JSON.stringify({
  id: 'game-1',
  playersOrder: ['user1', 'user2'],
  phase: 'play',
  currentTurn: 'user1',
  characters: {},
  bgm: null,
  startRolls: {},
  pendingMoves: [],
  hasBonusThrow: false,
  lastThrow: null,
  winner: null,
  equippedItems: {},
  players: {
    user1: { pieces: [{ position: 0, carried: [] }] },
    user2: { pieces: [{ position: 5, carried: [] }] },
  },
});

const UNO_STATE = JSON.stringify({
  players: ['user1', 'user2'],
  hands: {
    user1: [{ suit: 'red', value: '5' }, { suit: 'blue', value: '7' }],
    user2: [{ suit: 'green', value: '3' }],
  },
  discardPile: [{ suit: 'yellow', value: '9' }],
  currentPlayer: 'user1',
  drawStack: 0,
});

const MARBLE_STATE = JSON.stringify({
  id: 'marble-1',
  playersOrder: ['user1', 'user2'],
  phase: 'throwing',
  currentTurn: 'user1',
  players: {
    user1: { pieces: [{ id: 0, position: 3, finished: false }], coins: 4_500_000 },
    user2: { pieces: [{ id: 0, position: 12, finished: false }], coins: 5_000_000 },
  },
  lands: {},
});

const GOSTOP_STATE = JSON.stringify({
  gameId: 'gostop-test-1',
  phase: 'playing',
  players: ['user1', 'user2'],
  currentPlayerIdx: 0,
  firstPlayerIdx: 0,
  deck: [{ id: 'm9_junk_1', month: 9, type: 'junk', subtype: null }],
  field: [{ id: 'm3_junk_1', month: 3, type: 'junk', subtype: null }],
  hands: {
    user1: [{ id: 'm2_ribbon', month: 2, type: 'ribbon', subtype: 'red' }],
    user2: [{ id: 'm4_animal', month: 4, type: 'animal', subtype: null }],
  },
  captures: { user1: [], user2: [] },
  goCount: { user1: 0, user2: 0 },
  baseMultiplier: 1,
  shakeMultiplier: 1,
  bombMultiplier: 1,
  shakers: [],
  shakeQueue: [],
  shakePlayerId: null,
  lastEvents: [],
  pending: null,
  scores: { user1: { total: 0 }, user2: { total: 0 } },
  winner: null,
  loser: null,
  settlement: null,
  turn: 1,
  perPointBet: 100,
});

function buildServer(redis) {
  const httpServer = createServer();
  const io = new Server(httpServer, { transports: ['websocket'] });
  installSocketAuthentication(io, secret, async (uid) => ({
    userId: `user${uid}`,
    roomCode,
  }));
  io.on('connection', (socket) => {
    registerGameSessionHandlers(socket, { io, redis });

    socket.on('session:join', async (_, ackRaw) => {
      await socket.join(socket.data.roomCode);
      normalizeAck(ackRaw)({ ok: true });
    });

    socket.on('game:lobby:join', async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode: rc, userId } = socket.data;
      if (!rc || !userId) return ack({ ok: false, reason: 'not_joined' });
      const { gameType } = payload ?? {};
      const resume = await resolveLobbyJoinForResume(socket, io, redis, {
        roomCode: rc, gameType, userId,
      });
      if (resume) return ack({ ok: true, ...resume });
      ack({ ok: true, status: 'waiting', lobby: { gameType, host: userId, players: [userId] } });
    });

    socket.on('disconnect', () => cleanupGameSessionOnDisconnect(socket, io, redis));
  });
  return { httpServer, io };
}

const connect = (url, userId) =>
  new Promise((res, rej) => {
    const c = createClient(url, {
      transports: ['websocket'],
      auth: { token: mkToken(userId) },
      reconnection: false,
    });
    c.once('connect', () => res(c));
    c.once('connect_error', rej);
  });

const sessionJoin = (c) => c.timeout(2000).emitWithAck('session:join', {});
const lobbyJoin = (c, gt) => c.timeout(2000).emitWithAck('game:lobby:join', { gameType: gt });
const sessionEnter = (c, gt) => c.timeout(2000).emitWithAck('game:session:enter', { gameType: gt });
const sessionLeave = (c, gt) => c.timeout(2000).emitWithAck('game:session:leave', { gameType: gt });

// ── Test 1 ────────────────────────────────────────────────────────────────────
test('active yut with viewer A → B lobby join returns resumed', async () => {
  const redis = new FakeRedis({ [`yut:${roomCode}:game`]: YUT_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const cA = await connect(url, 1);
  const cB = await connect(url, 2);
  try {
    await sessionJoin(cA);
    await sessionJoin(cB);
    await sessionEnter(cA, 'yut');

    const result = await lobbyJoin(cB, 'yut');
    assert.equal(result.ok, true);
    assert.equal(result.status, 'resumed', `expected resumed, got ${result.status}`);
    assert.equal(result.gameType, 'yut');
    assert.ok(result.state, 'state must be present');
    assert.ok(await redis.get(`yut:${roomCode}:game`), 'game state must be preserved');
  } finally {
    cA.disconnect(); cB.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

// ── Test 2 ────────────────────────────────────────────────────────────────────
test('B reserved in subroom before ack → A leave does not delete state', async () => {
  const redis = new FakeRedis({ [`yut:${roomCode}:game`]: YUT_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const cA = await connect(url, 1);
  const cB = await connect(url, 2);
  try {
    await sessionJoin(cA);
    await sessionJoin(cB);
    await sessionEnter(cA, 'yut');

    const result = await lobbyJoin(cB, 'yut');
    assert.equal(result.status, 'resumed');

    await sessionLeave(cA, 'yut');
    assert.ok(await redis.get(`yut:${roomCode}:game`),
      'state must survive when B is still in subroom');
  } finally {
    cA.disconnect(); cB.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

// ── Test 3 ────────────────────────────────────────────────────────────────────
test('last viewer leaves → state deleted', async () => {
  const redis = new FakeRedis({ [`yut:${roomCode}:game`]: YUT_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const cA = await connect(url, 1);
  try {
    await sessionJoin(cA);
    await sessionEnter(cA, 'yut');
    await sessionLeave(cA, 'yut');
    assert.equal(await redis.get(`yut:${roomCode}:game`), null,
      'state must be deleted when last viewer leaves');
  } finally {
    cA.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

// ── Test 4 ────────────────────────────────────────────────────────────────────
test('stale state with no viewers → B gets normal waiting lobby and state deleted', async () => {
  const redis = new FakeRedis({ [`yut:${roomCode}:game`]: YUT_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const cB = await connect(url, 2);
  try {
    await sessionJoin(cB);
    const result = await lobbyJoin(cB, 'yut');
    assert.equal(result.ok, true);
    assert.equal(result.status, 'waiting', `expected waiting, got ${result.status}`);
    assert.equal(await redis.get(`yut:${roomCode}:game`), null, 'stale state must be deleted');
  } finally {
    cB.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

// ── Test 5 ────────────────────────────────────────────────────────────────────
// Device-switch E2E: same userId active on phone, opens the same game on tablet.
test('device switch: same userId second socket gets resumed result', async () => {
  const redis = new FakeRedis({ [`yut:${roomCode}:game`]: YUT_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const phone = await connect(url, 1);   // first device (socket1)
  const tablet = await connect(url, 1);  // second device, same userId
  try {
    await sessionJoin(phone);
    await sessionJoin(tablet);
    await sessionEnter(phone, 'yut');    // phone is viewing the active game

    // Tablet emits lobby:join for the same game — should get resumed
    const result = await lobbyJoin(tablet, 'yut');
    assert.equal(result.ok, true);
    assert.equal(result.status, 'resumed',
      'second device of same user must resume the active game');
    assert.ok(await redis.get(`yut:${roomCode}:game`), 'state must be preserved');
  } finally {
    phone.disconnect(); tablet.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

// ── Test 6 (original 5) ───────────────────────────────────────────────────────
test('same user two sockets → leaving one does not delete state', async () => {
  const redis = new FakeRedis({ [`yut:${roomCode}:game`]: YUT_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const s1 = await connect(url, 1);
  const s2 = await connect(url, 1);
  try {
    await sessionJoin(s1);
    await sessionJoin(s2);
    await sessionEnter(s1, 'yut');
    await sessionEnter(s2, 'yut');
    await sessionLeave(s1, 'yut');
    assert.ok(await redis.get(`yut:${roomCode}:game`),
      'state must survive when second socket still present');
  } finally {
    s1.disconnect(); s2.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

// ── Test 7 ────────────────────────────────────────────────────────────────────
test('UNO resume exposes only the joining user hand, not partner hand', async () => {
  const redis = new FakeRedis({ [`uno:${roomCode}:game`]: UNO_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const cA = await connect(url, 1); // user1
  const cB = await connect(url, 2); // user2
  try {
    await sessionJoin(cA);
    await sessionJoin(cB);
    await sessionEnter(cA, 'uno');

    const result = await lobbyJoin(cB, 'uno');
    assert.equal(result.status, 'resumed');

    const s = result.state;
    assert.deepEqual(s.hand, [{ suit: 'green', value: '3' }],
      'B (user2) should receive only their own hand');
    assert.equal(s.hands, undefined, 'raw hands object must not be in resume state');
    assert.ok(s.handCount, 'handCount must be present');
    assert.equal(s.handCount.user1, 2, 'user1 hand count must be correct');
    assert.equal(s.handCount.user2, 1, 'user2 hand count must be correct');
  } finally {
    cA.disconnect(); cB.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

test('active marble with viewer A → B lobby join returns resumed', async () => {
  const redis = new FakeRedis({ [`marble:${roomCode}:game`]: MARBLE_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const cA = await connect(url, 1);
  const cB = await connect(url, 2);
  try {
    await sessionJoin(cA);
    await sessionJoin(cB);
    await sessionEnter(cA, 'marble');

    const result = await lobbyJoin(cB, 'marble');
    assert.equal(result.ok, true);
    assert.equal(result.status, 'resumed', `expected resumed, got ${result.status}`);
    assert.equal(result.gameType, 'marble');
    assert.equal(result.state.phase, 'throwing');
    assert.deepEqual(result.state.players, ['user1', 'user2']);
    assert.ok(await redis.get(`marble:${roomCode}:game`), 'game state must be preserved');
  } finally {
    cA.disconnect(); cB.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});

test('GoStop resume exposes only the joining user hand and keeps the game state', async () => {
  const redis = new FakeRedis({ [`gostop:${roomCode}:game`]: GOSTOP_STATE });
  const { httpServer, io } = buildServer(redis);
  await listen(httpServer);
  const url = `http://127.0.0.1:${httpServer.address().port}`;
  const cA = await connect(url, 1);
  const cB = await connect(url, 2);
  try {
    await sessionJoin(cA);
    await sessionJoin(cB);
    await sessionEnter(cA, 'gostop');

    const result = await lobbyJoin(cB, 'gostop');
    assert.equal(result.status, 'resumed');
    assert.equal(result.gameType, 'gostop');
    assert.deepEqual(result.state.hands.user1, [
      { id: 'back' },
    ]);
    assert.deepEqual(result.state.hands.user2, [
      { id: 'm4_animal', month: 4, type: 'animal', subtype: null },
    ]);
    assert.equal(result.state.shakeQueue, undefined);
    assert.ok(await redis.get(`gostop:${roomCode}:game`));
  } finally {
    cA.disconnect(); cB.disconnect();
    await io.close(); await new Promise((r) => httpServer.close(r));
  }
});
