import assert from 'node:assert/strict';
import test from 'node:test';
import { clientIpKey, createRateLimiter, emailKey } from '../src/shared/rate-limit.js';

const run = (limiter, req = {}) => {
  const res = {
    headers: {},
    statusCode: 200,
    body: null,
    set(k, v) { this.headers[k] = v; return this; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
  let passed = false;
  limiter(req, res, () => { passed = true; });
  return { passed, res };
};

test('limiter allows up to max then returns 429 with Retry-After', () => {
  let t = 1_000;
  const limiter = createRateLimiter({ windowMs: 60_000, max: 2, keyFn: () => 'k', now: () => t });
  assert.equal(run(limiter).passed, true);
  assert.equal(run(limiter).passed, true);
  const blocked = run(limiter);
  assert.equal(blocked.passed, false);
  assert.equal(blocked.res.statusCode, 429);
  assert.equal(blocked.res.body.reason, 'rate_limited');
  assert.ok(Number(blocked.res.headers['Retry-After']) >= 1);
});

test('limiter resets after the window and isolates keys', () => {
  let t = 0;
  let key = 'a';
  const limiter = createRateLimiter({ windowMs: 1_000, max: 1, keyFn: () => key, now: () => t });
  assert.equal(run(limiter).passed, true);
  assert.equal(run(limiter).passed, false);
  key = 'b';
  assert.equal(run(limiter).passed, true);
  key = 'a';
  t = 1_001;
  assert.equal(run(limiter).passed, true);
});

test('null key and disabled limiter never block', () => {
  const nullKey = createRateLimiter({ windowMs: 1_000, max: 1, keyFn: () => null });
  for (let i = 0; i < 5; i += 1) assert.equal(run(nullKey).passed, true);
  const disabled = createRateLimiter({ windowMs: 1_000, max: 1, keyFn: () => 'x', enabled: false });
  for (let i = 0; i < 5; i += 1) assert.equal(run(disabled).passed, true);
});

test('ip key skips loopback and email key normalizes case', () => {
  assert.equal(clientIpKey('login')({ ip: '127.0.0.1' }), null);
  assert.equal(clientIpKey('login')({ ip: '::ffff:127.0.0.1' }), null);
  assert.equal(clientIpKey('login')({ ip: '203.0.113.7' }), 'login:ip:203.0.113.7');
  assert.equal(emailKey('login')({ body: { email: ' A@B.com ' } }), 'login:email:a@b.com');
  assert.equal(emailKey('login')({ body: {} }), null);
});
