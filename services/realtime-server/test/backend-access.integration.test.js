import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import jwt from 'jsonwebtoken';
import { Server } from 'socket.io';
import { io as createClient } from 'socket.io-client';
import {
  installSocketFeatureGate,
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

test('Socket feature gate allows MVP games and rejects UNO with the stable response', async () => {
  const server = createServer();
  const io = new Server(server);
  io.on('connection', (socket) => {
    installSocketFeatureGate(socket, 'mvp');
    socket.on('game:yut:new', (_, ack) => ack({ ok: true }));
    socket.on('game:uno:new', (_, ack) => ack({ ok: true }));
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

    const disabled = await client.timeout(1000).emitWithAck('game:uno:new', {});
    assert.deepEqual(disabled, {
      ok: false,
      error: { code: 'FEATURE_DISABLED', feature: 'uno' },
    });
  } finally {
    client.disconnect();
    await io.close();
    await new Promise((resolve) => server.close(resolve));
  }
});
