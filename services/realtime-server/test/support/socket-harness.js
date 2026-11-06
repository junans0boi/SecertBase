// 소켓 회귀 테스트 공용 하네스: 실제 socket.js·엔진을 쓰고 DB·Redis·푸시만 메모리로 바꾼다.
// 게임별 테스트 파일은 여기서 fixture를 가져다 쓴다.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { registerHooks } from 'node:module';
import jwt from 'jsonwebtoken';
import { Server } from 'socket.io';
import { io as createClient } from 'socket.io-client';

// Only external boundaries are replaced. Authentication, handlers and game
// engines below are the production modules; no DB, Redis or FCM is contacted.
export const secret = 'socket-game-regression-secret-32-characters';
export const boundary = {};
globalThis.__socketGameRegression = boundary;
const replacements = new Map([
  ['../../src/config.js', `export const config = { JWT_SECRET: ${JSON.stringify(secret)}, PUBLIC_FEATURE_SET: 'legacy' };`],
  ['../../src/db.js', 'export const query = (...args) => globalThis.__socketGameRegression.query(...args); export const transaction = (...args) => globalThis.__socketGameRegression.transaction(...args);'],
  ['../../src/redis.js', 'export const redis = new Proxy({}, { get: (_, key) => (...args) => globalThis.__socketGameRegression.redis[key](...args) });'],
  ['../../src/modules/notifications/index.js', 'export const notifier = { notifyPartner: (...args) => globalThis.__socketGameRegression.notifyPartner(...args) };'],
].map(([path, source]) => [new URL(path, import.meta.url).href, source]));
const hooks = registerHooks({
  load(url, context, nextLoad) {
    const source = replacements.get(url);
    return source === undefined ? nextLoad(url, context) : { format: 'module', source, shortCircuit: true };
  },
});
export const { registerSocketHandlers } = await import('../../src/socket.js');
export const { createMarbleGameState } = await import('../../src/marble-engine.js');
export const { createYutGameState } = await import('../../src/yut-engine.js');
export const { getUserLevel } = await import('../../src/level-engine.js');
export const { createUnoGameState } = await import('../../src/uno-engine.js');
hooks.deregister();

export class MemoryRedis {
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

export const flush = async () => { for (let i = 0; i < 10; i++) await new Promise(setImmediate); };
let roomSequence = 0;
export async function fixture(t, { players = 2 } = {}) {
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
  const call = (index, event, payload) => clients[index].timeout(2000).emitWithAck(event, payload);
  return { redis, roomCode, clients, events, invites, results, call, tick };
}

