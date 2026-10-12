import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { registerHooks } from 'node:module';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import { Server } from 'socket.io';
import { io as createClient } from 'socket.io-client';

// Only external boundaries are replaced. Authentication, handlers and game
// engines below are the production modules; no DB, Redis or FCM is contacted.
const secret = 'socket-game-regression-secret-32-characters';
const boundary = {};
globalThis.__socketGameRegression = boundary;
const replacements = new Map([
  ['../src/config.js', `export const config = { JWT_SECRET: ${JSON.stringify(secret)}, PUBLIC_FEATURE_SET: 'legacy' };`],
  ['../src/db.js', 'export const query = (...args) => globalThis.__socketGameRegression.query(...args); export const transaction = (...args) => globalThis.__socketGameRegression.transaction(...args);'],
  ['../src/redis.js', 'export const redis = new Proxy({}, { get: (_, key) => (...args) => globalThis.__socketGameRegression.redis[key](...args) });'],
  ['../src/modules/notifications/index.js', 'export const notifier = { notifyPartner: (...args) => globalThis.__socketGameRegression.notifyPartner(...args) };'],
].map(([path, source]) => [new URL(path, import.meta.url).href, source]));
const hooks = registerHooks({
  load(url, context, nextLoad) {
    const source = replacements.get(url);
    return source === undefined ? nextLoad(url, context) : { format: 'module', source, shortCircuit: true };
  },
});
const { registerSocketHandlers } = await import('../src/socket.js');
const { createMarbleGameState } = await import('../src/marble-engine.js');
const { createYutGameState } = await import('../src/yut-engine.js');
const { getUserLevel } = await import('../src/level-engine.js');
hooks.deregister();

class MemoryRedis {
  values = new Map();
  async get(key) {
    const item = this.values.get(key);
    if (!item || item.expiresAt <= Date.now()) { this.values.delete(key); return null; }
    return item.value;
  }
  async set(key, value, ...args) {
    if (args.includes('NX') && await this.get(key) !== null) return null;
    const seconds = args[args.indexOf('EX') + 1];
    this.values.set(key, { value, expiresAt: args.includes('EX') ? Date.now() + seconds * 1000 : Infinity });
    return 'OK';
  }
  async del(key) { return Number(this.values.delete(key)); }
}

const flush = async () => { for (let i = 0; i < 10; i++) await new Promise(setImmediate); };
let roomSequence = 0;
async function fixture(t, { players = 2 } = {}) {
  const roomCode = `socket-regression-${++roomSequence}`;
  const redis = new MemoryRedis();
  const invites = [];
  const levels = new Map();
  const results = [];
  boundary.redis = redis;
  boundary.notifyPartner = async (...args) => { invites.push(args); return { sent: 1 }; };
  boundary.query = async (sql, params) => {
    if (sql.includes('JOIN Users u ON u.UserId')) return { rows: [{ CoupleId: 1, RoomCode: roomCode, UserCode: params[0] === 11 ? 'ALPHA-code' : 'BETA-code', Nickname: 'Player' }] };
    if (sql.includes('User1Code')) return { rows: [{ User1Code: 'ALPHA-code', User2Code: 'BETA-code' }] };
    if (sql.includes('SELECT CoupleId FROM Couples')) return { rows: [{ CoupleId: 1 }] };
    if (sql.includes('INSERT INTO game_results')) { results.push(params); return { rows: [] }; }
    if (sql.includes('UserCode IN')) return { rows: [{ UserId: 11, UserCode: 'ALPHA-code' }, { UserId: 22, UserCode: 'BETA-code' }] };
    if (sql.includes('SELECT level, xp')) return { rows: [levels.get(params[0]) ?? { level: 1, xp: 0 }] };
    return { rows: [] };
  };
  boundary.transaction = async run => run({ execute: async (sql, params) => {
    if (sql.includes('SELECT level, xp')) return [[levels.get(params[0]) ?? { level: 1, xp: 0 }]];
    if (sql.includes('UPDATE user_levels')) levels.set(params[2], { level: params[0], xp: params[1] });
    return [[]];
  } });
  const httpServer = createServer();
  const io = new Server(httpServer, { transports: ['websocket'], pingInterval: 3_600_000, pingTimeout: 3_600_000 });
  // Advance only the game's timer boundary. Socket.IO keeps real timers so its
  // transport close callbacks cannot be cancelled by a global clock reset.
  const pendingTimers = new Set();
  registerSocketHandlers(io, { timerApi: {
    setTimeout(fn, delay) {
      const handle = { fn, deadline: Date.now() + delay, unref() {} };
      pendingTimers.add(handle);
      return handle;
    },
    clearTimeout(handle) { pendingTimers.delete(handle); },
  } });
  const tick = ms => {
    t.mock.timers.tick(ms);
    for (const handle of pendingTimers) {
      if (handle.deadline <= Date.now()) {
        pendingTimers.delete(handle);
        handle.fn();
      }
    }
  };
  await new Promise(resolve => httpServer.listen(0, '127.0.0.1', resolve));
  const clients = [];
  t.after(async () => {
    t.mock.timers.reset();
    clients.forEach(client => client.disconnect());
    await new Promise(resolve => io.close(resolve));
    await flush();
    assert.equal(pendingTimers.size, 0, 'server close must clear pending game timers');
  });
  for (const userId of [11, 22].slice(0, players)) {
    const client = createClient(`http://127.0.0.1:${httpServer.address().port}`, {
      transports: ['websocket'], reconnection: false,
      auth: { token: jwt.sign({ userId }, secret) },
    });
    clients.push(client);
    await new Promise((resolve, reject) => { client.once('connect', resolve); client.once('connect_error', reject); });
    assert.equal((await client.timeout(2000).emitWithAck('session:join', {})).ok, true);
  }
  const events = [];
  clients[0].on('game:telepathy:result', event => events.push(event));
  const call = (index, event, payload) => clients[index].timeout(2000).emitWithAck(event, payload);
  return { redis, roomCode, clients, events, invites, results, call, tick };
}

const options = ['tea', 'coffee'];
test('telepathy publishes choices at its 60 second deadline without waiting forever', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  assert.equal((await f.call(0, 'game:telepathy:select', { choice: 'tea', options })).waiting, true);
  f.tick(59_999);
  await flush();
  assert.equal(f.events.length, 0);
  f.tick(1);
  await flush();
  assert.equal(f.events.length, 1, 'expiry must emit a result through the real socket handler');
  assert.deepEqual(f.events[0].choices, { 'ALPHA-code': 'tea' });
  assert.equal(f.events[0].success, false, 'one answer alone cannot count as a match');
  assert.equal(f.events[0].selected, null);
});

test('late telepathy answer completes the retained round and retries do not broadcast another result', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  await f.call(0, 'game:telepathy:select', { choice: 'tea', options });
  f.tick(61_000);
  await flush();
  const late = await f.call(1, 'game:telepathy:select', { choice: 'tea', options });
  assert.equal(late.result?.success, true);
  assert.deepEqual(late.result.choices, { 'ALPHA-code': 'tea', 'BETA-code': 'tea' });
  assert.equal(late.result.sessionId, f.events[0].sessionId, 'late result belongs to the expired session');
  await flush();
  const retry = await f.call(1, 'game:telepathy:select', { choice: 'tea', options, sessionId: late.result.sessionId });
  assert.deepEqual(retry.result, late.result, 'retry must return the completed result rather than create an orphaned session');
  await flush();
  assert.equal(f.events.length, 2, 'one expiry and one completion, never a duplicate room result');
  f.tick(60_000);
  await flush();
  assert.equal(f.events.length, 2);
});

test('reselecting does not extend the deadline and a new question cannot receive an old expiry', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  const first = await f.call(0, 'game:telepathy:select', { choice: 'tea', options });
  f.tick(30_000);
  const duplicate = await f.call(0, 'game:telepathy:select', { choice: 'tea', options });
  assert.equal(duplicate.deadlineAt, first.deadlineAt);
  f.tick(10_000);
  const next = await f.call(0, 'game:telepathy:select', { choice: 'sea', options: ['sea', 'mountain'] });
  f.tick(20_000);
  await flush();
  assert.equal(f.events.length, 0);
  const stale = await f.call(1, 'game:telepathy:select', { choice: 'tea', options, sessionId: first.sessionId });
  assert.equal(stale.reason, 'stale_session');
  f.tick(40_000);
  await flush();
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].sessionId, next.sessionId);
  assert.deepEqual(f.events[0].choices, { 'ALPHA-code': 'sea' });
});

test('legacy telepathy clients can start another completed question with identical options', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:telepathy:select', { choice: 'tea', options });
  const first = await f.call(1, 'game:telepathy:select', { choice: 'tea', options });
  const next = await f.call(0, 'game:telepathy:select', { choice: 'coffee', options });
  assert.equal(next.waiting, true);
  const second = await f.call(1, 'game:telepathy:select', { choice: 'coffee', options });
  assert.equal(second.result.selected, 'coffee');
  assert.notEqual(second.result.sessionId, first.result.sessionId);
});

test('simultaneous telepathy answers complete once and the cancelled expiry never broadcasts', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  const responses = await Promise.all([
    f.call(0, 'game:telepathy:select', { choice: 'tea', options }),
    f.call(1, 'game:telepathy:select', { choice: 'coffee', options }),
  ]);
  assert.equal(responses.filter(response => response.waiting).length, 1);
  assert.equal(responses.filter(response => response.result).length, 1);
  await flush();
  assert.equal(f.events.length, 1);
  assert.deepEqual(f.events[0].choices, { 'ALPHA-code': 'tea', 'BETA-code': 'coffee' });
  assert.equal(f.events[0].success, false);
  f.tick(60_000);
  await flush();
  assert.equal(f.events.length, 1);
});

test('telepathy retains the first answer when its player disconnects before the late partner responds', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  await f.call(0, 'game:telepathy:select', { choice: 'tea', options });
  f.clients[0].disconnect();
  await flush();
  const partnerEvents = [];
  f.clients[1].on('game:telepathy:result', event => partnerEvents.push(event));
  f.tick(61_000);
  await flush();
  assert.deepEqual(partnerEvents[0].choices, { 'ALPHA-code': 'tea' });
  const late = await f.call(1, 'game:telepathy:select', { choice: 'tea', options });
  assert.equal(late.result.success, true);
  assert.deepEqual(late.result.choices, { 'ALPHA-code': 'tea', 'BETA-code': 'tea' });
});

test('joining re-arms a persisted telepathy deadline after a server restart', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  // Pre-deadline deployment state: choices exist, but no in-process timer does.
  await f.redis.set(`telepathy:${f.roomCode}:session`, JSON.stringify({
    choices: { 'ALPHA-code': 'tea' }, options, revealed: false, updatedAt: 40_000,
  }), 'EX', 3600);
  assert.equal((await f.call(0, 'session:join', {})).ok, true);
  f.tick(1);
  await flush();
  assert.equal(f.events.length, 1);
  assert.deepEqual(f.events[0].choices, { 'ALPHA-code': 'tea' });
  const late = await f.call(1, 'game:telepathy:select', { choice: 'tea', options });
  assert.equal(late.result.success, true);
});

test('legacy RPS still discards an unanswered choice after 60 seconds', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  await f.call(0, 'game:rps:select', { choice: 'rock' });
  f.tick(60_001);
  const late = await f.call(1, 'game:rps:select', { choice: 'paper' });
  assert.equal(late.waiting, true, 'RPS must not inherit the retained telepathy lifetime');
});

test('lobby invite uses JWT numeric identity and supplies the game and room destination', async t => {
  const f = await fixture(t, { players: 1 });
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'rps' })).ok, true);
  await flush();
  assert.deepEqual(f.invites, [[11, 'game_invite', { game_type: 'rps', room_code: f.roomCode }]]);
});

test('a failed invite does not fail the lobby and reopening it can retry the notification', async t => {
  const f = await fixture(t, { players: 1 });
  let attempts = 0;
  boundary.notifyPartner = async () => { attempts++; return { sent: 0, skipped: 'error' }; };
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'rps' })).ok, true);
  await flush();
  await f.call(0, 'game:lobby:leave', { gameType: 'rps' });
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'rps' })).ok, true);
  await flush();
  assert.equal(attempts, 2);
});

test('rejected invite promises are caught and the successful retry is deduped for 60 seconds', async t => {
  const f = await fixture(t, { players: 1 });
  const logs = [];
  t.mock.method(console, 'error', (...args) => logs.push(args));
  let attempts = 0;
  boundary.notifyPartner = async () => {
    if (++attempts === 1) throw new Error('transport unavailable');
    return { sent: 1 };
  };
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  assert.equal(logs.length, 1);
  await f.call(0, 'game:lobby:leave', { gameType: 'rps' });
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  await f.call(0, 'game:lobby:leave', { gameType: 'rps' });
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  assert.equal(attempts, 2, 'successful send must retain dedupe protection');
});

test('partners already present in the room do not receive an away-player invite', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  assert.equal(f.invites.length, 0);
});

test('session restore sends the bomb holder and elapsed timer from the real socket handler', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  await f.redis.set(`bomb:${f.roomCode}:game`, JSON.stringify({
    currentPlayer: 'BETA-code', duration: 30_000, startTime: 95_000,
    currentQuiz: { category: 'math' },
  }));
  const restored = await f.call(0, 'session:restore', {});
  assert.deepEqual(restored.activeGames.bomb, { currentPlayer: 'BETA-code', timer: 25, category: 'math' });
});

test('marble state delivers server total assets including invested buildings', async t => {
  const f = await fixture(t);
  const state = createMarbleGameState('ALPHA-code', 'BETA-code');
  state.lands[1] = { owner: 'ALPHA-code', level: 2 };
  await f.redis.set(`marble:${f.roomCode}:game`, JSON.stringify(state));
  const restored = await f.call(0, 'session:restore', {});
  assert.deepEqual(restored.activeGames.marble.assets, { 'ALPHA-code': 6_200_000, 'BETA-code': 5_000_000 });
});

test('claiming the last tourist property emits the monopoly win reason through sockets', async t => {
  const f = await fixture(t);
  const state = createMarbleGameState('ALPHA-code', 'BETA-code');
  state.lands[8] = { owner: 'ALPHA-code', level: 0 };
  state.pendingLandAction = { userId: 'ALPHA-code', pos: 17, type: 'claim' };
  await f.redis.set(`marble:${f.roomCode}:game`, JSON.stringify(state));
  const ended = [];
  f.clients[0].on('game:marble:ended', event => ended.push(event));
  const claimed = await f.call(0, 'game:marble:land_act', { action: 'claim', pos: 17 });
  assert.equal(claimed.ok, true);
  await flush();
  assert.deepEqual(ended, [{ winner: 'ALPHA-code', winReason: 'tourist_monopoly', finalScores: null }]);
});

test('socket yut move consumes a capture extra turn once, then hands over the next turn', async t => {
  const f = await fixture(t);
  const state = createYutGameState('ALPHA-code', 'BETA-code');
  state.currentTurn = 'ALPHA-code';
  state.phase = 'moving';
  state.pendingMoves = [1];
  state.players['ALPHA-code'].pieces[0].position = 1;
  state.players['BETA-code'].pieces[0].position = 2;
  await f.redis.set(`yut:${f.roomCode}:game`, JSON.stringify(state));
  const capture = await f.call(0, 'game:yut:move', { pieceId: 0 });
  assert.equal(capture.ok, true);
  assert.equal(capture.event.capturedCount, 1);
  assert.equal(capture.event.currentTurn, 'ALPHA-code');
  const afterCapture = JSON.parse(await f.redis.get(`yut:${f.roomCode}:game`));
  afterCapture.phase = 'moving';
  afterCapture.pendingMoves = [1];
  await f.redis.set(`yut:${f.roomCode}:game`, JSON.stringify(afterCapture));
  assert.equal((await f.call(0, 'game:yut:move', { pieceId: 0 })).ok, true);
  const restored = await f.call(0, 'session:restore', {});
  assert.equal(restored.activeGames.yut.currentTurn, 'BETA-code');
});

test('bowling completion grants winner/loser XP once through its socket handler', async t => {
  const f = await fixture(t);
  await f.redis.set(`game:${f.roomCode}:bowling`, JSON.stringify({
    status: 'playing', turn: 'BETA-code', seed: 1, history: [],
    rolls: { 'ALPHA-code': Array(20).fill(1), 'BETA-code': Array(19).fill(0) },
    scores: { 'ALPHA-code': 20, 'BETA-code': 0 }, result: null,
  }));
  assert.equal((await f.call(1, 'game:bowling:roll', { pins: 0 })).ok, true);
  await flush();
  assert.equal((await getUserLevel(11)).xp, 50);
  assert.equal((await getUserLevel(22)).xp, 20);
  assert.deepEqual(f.results, [[1, 'bowling', 'ALPHA-code', 'BETA-code', 0]]);
  assert.equal((await f.call(1, 'game:bowling:roll', { pins: 0 })).ok, false);
  assert.equal((await getUserLevel(11)).xp, 50);
});

test('penalty completion grants winner/loser XP once through its socket handler', async t => {
  const f = await fixture(t);
  await f.redis.set(`game:${f.roomCode}:penalty`, JSON.stringify({
    status: 'playing', round: 10, kicker: 'BETA-code', keeper: 'ALPHA-code',
    submissions: {}, scores: { 'ALPHA-code': 1, 'BETA-code': 0 }, result: null,
    rounds: Array.from({ length: 9 }, (_, i) => ({ kicker: i % 2 === 0 ? 'ALPHA-code' : 'BETA-code' })),
  }));
  await f.call(0, 'game:penalty:submit', { choice: 4 });
  assert.equal((await f.call(1, 'game:penalty:submit', { choice: 4 })).ok, true);
  await flush();
  assert.equal((await getUserLevel(11)).xp, 50);
  assert.equal((await getUserLevel(22)).xp, 20);
  assert.deepEqual(f.results, [[1, 'penalty', 'ALPHA-code', 'BETA-code', 0]]);
  assert.equal((await f.call(1, 'game:penalty:submit', { choice: 4 })).ok, false);
  assert.equal((await getUserLevel(11)).xp, 50);
});
