import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import jwt from 'jsonwebtoken';
import { Server } from 'socket.io';
import { io as createClient } from 'socket.io-client';
import {
  installSocketFeatureGate,
  installSocketAuthentication,
  mvpRestFeatureGate,
  requireAuth,
} from '../src/backend-access.js';

const secret = 'integration-jwt-secret-at-least-32-characters';

const listen = (server) =>
  new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));

test('HTTP auth context ignores client user ids and REST feature gates are stable', async () => {
  const app = express();
  app.use(express.json());
  app.get('/private', requireAuth(secret), (req, res) => res.json(req.auth));
  app.get(
    '/qa/today',
    requireAuth(secret),
    mvpRestFeatureGate('mvp'),
    (_, res) => res.json({ ok: true }),
  );
  const server = createServer(app);
  await listen(server);
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const missing = await fetch(`${baseUrl}/private`);
    assert.equal(missing.status, 401);
    assert.equal((await missing.json()).error.code, 'AUTH_REQUIRED');

    const token = jwt.sign({ userId: 7, userCode: 'OWNER7' }, secret);
    const authenticated = await fetch(`${baseUrl}/private?userId=999`, {
      headers: { authorization: `Bearer ${token}` },
    });
    assert.deepEqual(await authenticated.json(), {
      userId: 7,
      userCode: 'OWNER7',
    });

    const disabled = await fetch(`${baseUrl}/qa/today`, {
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(disabled.status, 403);
    assert.deepEqual(await disabled.json(), {
      ok: false,
      error: { code: 'FEATURE_DISABLED', feature: 'qa' },
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('Socket handshake requires a valid JWT and derives the server session', async () => {
  const server = createServer();
  const io = new Server(server);
  installSocketAuthentication(io, secret, async (userId) =>
    userId === 7 ? { userId: 'OWNER7', roomCode: 'couple-7' } : null);
  io.on('connection', (socket) => socket.emit('session', socket.data));
  await listen(server);
  const url = `http://127.0.0.1:${server.address().port}`;

  const connectError = (token) => new Promise((resolve) => {
    const client = createClient(url, {
      transports: ['websocket'],
      auth: token ? { token } : {},
      reconnection: false,
    });
    client.once('connect_error', (error) => {
      client.disconnect();
      resolve(error.message);
    });
  });

  try {
    assert.equal(await connectError(null), 'AUTH_REQUIRED');
    assert.equal(await connectError('forged'), 'AUTH_INVALID');
    const expired = jwt.sign({ userId: 7 }, secret, { expiresIn: -1 });
    assert.equal(await connectError(expired), 'AUTH_INVALID');

    const token = jwt.sign({ userId: 7 }, secret);
    const client = createClient(url, {
      transports: ['websocket'], auth: { token }, reconnection: false,
    });
    const session = await new Promise((resolve, reject) => {
      client.once('session', resolve);
      client.once('connect_error', reject);
    });
    assert.deepEqual(session, { userId: 'OWNER7', roomCode: 'couple-7' });
    client.disconnect();
  } finally {
    await io.close();
    await new Promise((resolve) => server.close(resolve));
  }
});

test('Socket feature gate allows public games and rejects unknown types and heart', async () => {
  const server = createServer();
  const io = new Server(server);
  io.on('connection', (socket) => {
    installSocketFeatureGate(socket, 'mvp');
    socket.on('game:yut:new', (_, ack) => ack({ ok: true }));
    socket.on('game:uno:new', (_, ack) => ack({ ok: true }));
    socket.on('game:restart:respond', (_, ack) => ack({ ok: true }));
  });
  await listen(server);
  const client = createClient(`http://127.0.0.1:${server.address().port}`, {
    transports: ['websocket'],
  });

  try {
    await new Promise((resolve, reject) => {
      client.once('connect', resolve);
      client.once('connect_error', reject);
    });
    const allowed = await client.timeout(1000).emitWithAck('game:yut:new', {});
    assert.deepEqual(allowed, { ok: true });

    // 복구된 게임(원카드)은 통과해야 한다. 내부 식별자는 uno를 유지한다.
    const restored = await client.timeout(1000).emitWithAck('game:uno:new', {});
    assert.deepEqual(restored, { ok: true });
    const restartRestored = await client.timeout(1000).emitWithAck(
      'game:restart:respond',
      { accept: true, gameType: 'uno' },
    );
    assert.deepEqual(restartRestored, { ok: true });

    // 미공개 game type과 heart는 여전히 차단된다.
    const unknown = await client.timeout(1000).emitWithAck(
      'game:lobby:join',
      { gameType: 'poker' },
    );
    assert.deepEqual(unknown, {
      ok: false,
      error: { code: 'FEATURE_DISABLED', feature: 'poker' },
    });
    const heart = await client.timeout(1000).emitWithAck('heart:send', {});
    assert.deepEqual(heart, {
      ok: false,
      error: { code: 'FEATURE_DISABLED', feature: 'heart' },
    });
  } finally {
    client.disconnect();
    await io.close();
    await new Promise((resolve) => server.close(resolve));
  }
});
