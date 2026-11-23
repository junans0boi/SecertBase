import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import { createApp } from '../src/app/create-app.js';

const fp = 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';

async function withApp(configExtra, body) {
  const app = createApp({
    config: { CORS_ORIGIN: [], ...configExtra },
    redis: { ping: async () => 'PONG' },
    routes: express.Router(),
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try {
    await body(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

test('GET /i/:code returns the same public HTML for any code', async () => {
  await withApp({}, async base => {
    const bodies = new Set();
    for (const code of ['ABC234', 'ZZZZZZ', 'abc234', 'x', 'TOO-LONG-CODE-123', '%3Cscript%3E']) {
      const res = await fetch(`${base}/i/${code}`);
      assert.equal(res.status, 200, code);
      assert.match(res.headers.get('content-type'), /text\/html/);
      assert.match(res.headers.get('cache-control'), /no-store/);
      bodies.add(await res.text());
    }
    assert.equal(bodies.size, 1, 'response must not depend on the code');
    const html = [...bodies][0];
    assert.ok(html.includes('기지 초대장'));
    assert.ok(html.includes('secretbase://invite/'));
    assert.ok(!html.includes('<script src='), 'no external scripts');
  });
});

test('landing page exposes no personal data and sets privacy headers', async () => {
  await withApp({}, async base => {
    const res = await fetch(`${base}/i/ABC234`);
    assert.equal(res.headers.get('x-robots-tag'), 'noindex, nofollow');
    assert.match(res.headers.get('content-security-policy'), /default-src 'none'/);
    assert.ok(!(await res.text()).includes('ABC234'));
  });
});

test('GET /i/:code is rate limited per client and does not reveal anything else', async () => {
  await withApp({ BASE_INVITE_RATE_MAX: 3 }, async base => {
    const statuses = [];
    for (let i = 0; i < 5; i++) {
      // x-forwarded-for makes req.ip a non-loopback address through trust proxy.
      const res = await fetch(`${base}/i/ABC234`, { headers: { 'x-forwarded-for': '203.0.113.7' } });
      statuses.push(res.status);
    }
    assert.deepEqual(statuses, [200, 200, 200, 429, 429]);
    const other = await fetch(`${base}/i/ABC234`, { headers: { 'x-forwarded-for': '203.0.113.8' } });
    assert.equal(other.status, 200);
  });
});

test('assetlinks.json is empty without configuration', async () => {
  await withApp({}, async base => {
    const res = await fetch(`${base}/.well-known/assetlinks.json`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /application\/json/);
    assert.deepEqual(await res.json(), []);
  });
});

test('assetlinks.json is built from configured fingerprints', async () => {
  await withApp({ ANDROID_APP_LINK_SHA256: `${fp}, ${fp.replace(/AA/g, 'BB')}`, ANDROID_PACKAGE_NAME: 'com.example.app' }, async base => {
    const body = await (await fetch(`${base}/.well-known/assetlinks.json`)).json();
    assert.equal(body.length, 1);
    assert.deepEqual(body[0].relation, ['delegate_permission/common.handle_all_urls']);
    assert.equal(body[0].target.namespace, 'android_app');
    assert.equal(body[0].target.package_name, 'com.example.app');
    assert.equal(body[0].target.sha256_cert_fingerprints.length, 2);
  });
});

test('assetlinks.json ignores malformed fingerprints', async () => {
  await withApp({ ANDROID_APP_LINK_SHA256: 'not-a-fingerprint' }, async base => {
    assert.deepEqual(await (await fetch(`${base}/.well-known/assetlinks.json`)).json(), []);
  });
});
