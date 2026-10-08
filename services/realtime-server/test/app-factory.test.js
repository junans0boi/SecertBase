import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import express from 'express';
import { createApp } from '../src/app/create-app.js';
import { createRealtimeServer } from '../src/app/create-realtime-server.js';
import {
  getAuthenticatedActor,
  resolveActiveCouple,
} from '../src/shared/access-context.js';
import {
  isGameEnabled,
  isRestEnabled,
} from '../src/shared/feature-registry.js';

const config = {
  CORS_ORIGIN: ['http://127.0.0.1:7357'],
  UPLOADS_ROOT: '/tmp/secretbase-factory-test-uploads',
  PUBLIC_FEATURE_SET: 'mvp',
};

test('createApp composes health, JSON, static, CORS, and API routes', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'secretbase-factory-'));
  await writeFile(path.join(root, 'probe.txt'), 'factory-ok');
  const redis = { ping: async () => 'PONG' };
  const routes = express.Router();
  routes.post('/probe', (req, res) => res.json({ ok: true, body: req.body }));

  try {
    const app = createApp({
      config: { ...config, UPLOADS_ROOT: root },
      redis,
      routes,
    });
    const server = app.listen(0, '127.0.0.1');
    await new Promise((resolve) => server.once('listening', resolve));
    const baseUrl = `http://127.0.0.1:${server.address().port}`;

    try {
      const health = await fetch(`${baseUrl}/health`);
      assert.equal(health.status, 200);
      assert.deepEqual(await health.json(), { ok: true });

      const probe = await fetch(`${baseUrl}/api/probe`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ value: 7 }),
      });
      assert.deepEqual(await probe.json(), { ok: true, body: { value: 7 } });

      const asset = await fetch(`${baseUrl}/uploads/probe.txt`);
      assert.equal(await asset.text(), 'factory-ok');
      assert.equal(asset.headers.get('access-control-allow-origin'), null);
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test('createRealtimeServer builds Socket.IO and closes its resources', async () => {
  const redis = { ping: async () => 'PONG' };
  let registeredIo;
  const app = createApp({ config, redis, routes: express.Router() });
  const realtime = createRealtimeServer({
    app,
    config,
    redis,
    registerSocketHandlers: (io) => {
      registeredIo = io;
    },
  });

  assert.ok(realtime.httpServer);
  assert.ok(realtime.io);
  assert.equal(registeredIo, realtime.io);
  await new Promise((resolve) => realtime.httpServer.listen(0, '127.0.0.1', resolve));
  await realtime.close();
  assert.equal(realtime.httpServer.listening, false);
});

test('access context trusts JWT-derived auth and rejects scope overrides', () => {
  const request = {
    auth: { userId: 7, userCode: 'OWNER7' },
    query: { user_id: '7' },
    body: {},
    params: {},
  };
  assert.deepEqual(getAuthenticatedActor(request), {
    userId: 7,
    userCode: 'OWNER7',
  });

  assert.throws(
    () =>
      getAuthenticatedActor({
        ...request,
        query: { user_id: '999' },
      }),
    /CLIENT_SCOPE_OVERRIDE/,
  );
});

test('feature registry keeps unknown and retired entry points disabled', async () => {
  assert.equal(isRestEnabled('/api/qa/today', 'mvp'), false);
  assert.equal(isRestEnabled('/qa/today', 'mvp'), false);
  assert.equal(isRestEnabled('/api/relationship/birth-profile', 'mvp'), true);
  assert.equal(isGameEnabled('poker', 'mvp'), false);
  assert.equal(isGameEnabled('yut', 'mvp'), true);
  assert.equal(isRestEnabled('/qa/today', 'legacy'), true);
  assert.equal(await resolveActiveCouple(7, async () => ({ rows: [] })), null);
});
