import assert from 'node:assert/strict';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import { createAccountActiveChecker, requireAuth } from '../src/backend-access.js';

const SECRET = 'x'.repeat(40);
const silentLog = { error() {} };

const run = async (middleware, userId = 5) => {
  const token = jwt.sign({ userId, userCode: 'U05' }, SECRET);
  const req = { get: () => `Bearer ${token}`, query: {}, body: {}, params: {} };
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
  let nextCalled = false;
  await middleware(req, res, () => { nextCalled = true; });
  return { nextCalled, res };
};

test('deleted or missing accounts are rejected with AUTH_INVALID', async () => {
  for (const rows of [[{ IsDeleted: 1 }], []]) {
    const check = createAccountActiveChecker({ queryFn: async () => ({ rows }), log: silentLog });
    const { nextCalled, res } = await run(requireAuth(SECRET, { isAccountActive: check }));
    assert.equal(nextCalled, false);
    assert.equal(res.statusCode, 401);
    assert.equal(res.body.error.code, 'AUTH_INVALID');
  }
});

test('active accounts pass and the result is cached until invalidated', async () => {
  let queries = 0;
  const check = createAccountActiveChecker({
    queryFn: async () => { queries += 1; return { rows: [{ IsDeleted: 0 }] }; },
    log: silentLog,
  });
  const mw = requireAuth(SECRET, { isAccountActive: check });
  assert.equal((await run(mw)).nextCalled, true);
  assert.equal((await run(mw)).nextCalled, true);
  assert.equal(queries, 1);
  check.invalidate(5);
  await run(mw);
  assert.equal(queries, 2);
});

test('cache expires after the ttl', async () => {
  let t = 0;
  let queries = 0;
  const check = createAccountActiveChecker({
    queryFn: async () => { queries += 1; return { rows: [{ IsDeleted: 0 }] }; },
    ttlMs: 1000,
    now: () => t,
    log: silentLog,
  });
  await check(5);
  t = 999;
  await check(5);
  assert.equal(queries, 1);
  t = 1001;
  await check(5);
  assert.equal(queries, 2);
});

test('a database error does not lock users out (fail-open)', async () => {
  const check = createAccountActiveChecker({
    queryFn: async () => { throw new Error('db down'); },
    log: silentLog,
  });
  const { nextCalled } = await run(requireAuth(SECRET, { isAccountActive: check }));
  assert.equal(nextCalled, true);
});

test('without a checker requireAuth behaves exactly as before', async () => {
  const { nextCalled } = await run(requireAuth(SECRET));
  assert.equal(nextCalled, true);
});
