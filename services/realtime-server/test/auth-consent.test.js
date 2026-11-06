import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import { createConsentRouter } from '../src/modules/auth/consent-router.js';
import {
  CONSENT_VERSIONS,
  ageOn,
  isStrongPassword,
  isValidBirthDate,
  normalizeConsents,
  recordConsents,
} from '../src/modules/auth/policy.js';

const silentLog = { error() {} };
const today = new Date('2026-11-06T03:00:00Z');

test('password policy: 8+ chars with letters and digits, never trimmed', () => {
  assert.equal(isStrongPassword('abcd1234'), true);
  assert.equal(isStrongPassword(' abc1234'), true);
  assert.equal(isStrongPassword('abcdefgh'), false);
  assert.equal(isStrongPassword('12345678'), false);
  assert.equal(isStrongPassword('abc123'), false);
  assert.equal(isStrongPassword(12345678), false);
  assert.equal(isStrongPassword(`a1${'x'.repeat(80)}`), false);
});

test('age and birth date validation (만 나이)', () => {
  assert.equal(ageOn('2012-11-06', today), 14);
  assert.equal(ageOn('2012-11-07', today), 13);
  assert.equal(ageOn('2000-03-14', today), 26);
  assert.equal(isValidBirthDate('2000-02-30', today), false);
  assert.equal(isValidBirthDate('2027-01-01', today), false);
  assert.equal(isValidBirthDate('1899-12-31', today), false);
  assert.equal(isValidBirthDate('2000-03-14', today), true);
});

test('consents: required items, optional marketing, legacy clients', () => {
  assert.deepEqual(normalizeConsents({ terms: true, privacy: true }), {
    ok: false, reason: 'consent_required',
  });
  assert.deepEqual(normalizeConsents('yes'), { ok: false, reason: 'invalid_consents' });
  const full = normalizeConsents({ terms: true, privacy: true, age14: true, marketing: false });
  assert.equal(full.ok, true);
  assert.deepEqual(full.records.map((r) => [r.type, r.agreed]), [
    ['terms', true], ['privacy', true], ['age14', true], ['marketing', false],
  ]);
  assert.equal(full.records[0].version, CONSENT_VERSIONS.terms);
  const legacy = normalizeConsents(undefined);
  assert.equal(legacy.legacy, true);
  assert.deepEqual(legacy.records.map((r) => r.type), ['terms', 'privacy']);
  assert.equal(normalizeConsents(undefined, { allowLegacy: false }).ok, false);
});

test('recordConsents writes one row per item and tolerates a pre-0050 schema', async () => {
  const calls = [];
  await recordConsents(async (sql, params) => { calls.push({ sql, params }); }, 3,
    normalizeConsents({ terms: true, privacy: true, age14: true, marketing: true }).records, 'signup');
  assert.match(calls[0].sql, /INSERT INTO user_consents/);
  assert.equal(calls[0].params.length, 20);
  assert.deepEqual(calls[0].params.slice(0, 5), [3, 'terms', CONSENT_VERSIONS.terms, 1, 'signup']);

  let missing = 0;
  await recordConsents(async () => {
    throw Object.assign(new Error('no table'), { code: 'ER_NO_SUCH_TABLE' });
  }, 3, [{ type: 'terms', agreed: true, version: 'v' }], 'signup', () => { missing++; });
  assert.equal(missing, 1);
  await assert.rejects(recordConsents(async () => {
    throw Object.assign(new Error('boom'), { code: 'ER_LOCK_DEADLOCK' });
  }, 3, [{ type: 'terms', agreed: true, version: 'v' }], 'signup'));
});

async function withServer(queryFn, run, userId = 5) {
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.auth = userId ? { userId } : undefined; next(); });
  app.use(createConsentRouter({ queryFn, now: () => today, log: silentLog }));
  const server = createServer(app).listen(0);
  await new Promise((r) => server.once('listening', r));
  try {
    const base = `http://127.0.0.1:${server.address().port}`;
    const call = async (method, path, body) => {
      const response = await fetch(base + path, {
        method,
        headers: { 'content-type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
      });
      return { status: response.status, body: await response.json() };
    };
    await run(call);
  } finally {
    await new Promise((r) => server.close(r));
  }
}

const allConsents = { terms: true, privacy: true, age14: true, marketing: false };

test('complete-signup validates, updates the profile once and records consents', async () => {
  const calls = [];
  let completed = false;
  const queryFn = async (sql, params) => {
    calls.push({ sql, params });
    if (sql.includes('UPDATE Users')) {
      if (completed) return { rows: { affectedRows: 0 } };
      completed = true;
      return { rows: { affectedRows: 1 } };
    }
    return { rows: { affectedRows: 4 } };
  };
  await withServer(queryFn, async (call) => {
    assert.equal((await call('POST', '/auth/complete-signup', { nickname: '민지' })).body.reason, 'missing_fields');
    assert.equal((await call('POST', '/auth/complete-signup', {
      nickname: '민지', birth_date: '2013-01-01', consents: allConsents,
    })).body.reason, 'under_age');
    assert.equal((await call('POST', '/auth/complete-signup', {
      nickname: '민지', birth_date: '2000-03-14', consents: { terms: true },
    })).body.reason, 'consent_required');
    assert.equal(calls.length, 0);

    const ok = await call('POST', '/auth/complete-signup', {
      nickname: ' 민지 ', birth_date: '2000-03-14', consents: allConsents,
    });
    assert.equal(ok.status, 200);
    assert.match(calls[0].sql, /SignupCompletedAt IS NULL/);
    assert.deepEqual(calls[0].params.slice(0, 3), ['민지', '민지', '2000-03-14']);
    assert.match(calls[1].sql, /INSERT INTO user_consents/);
    assert.ok(calls[1].params.includes('google_signup'));

    const again = await call('POST', '/auth/complete-signup', {
      nickname: '민지', birth_date: '2000-03-14', consents: allConsents,
    });
    assert.equal(again.status, 409);
    assert.equal(again.body.reason, 'signup_already_completed');
  });
});

test('consent history: latest per item, marketing toggle, auth required', async () => {
  const rows = [
    { consent_type: 'marketing', version: 'v2', agreed: 0, source: 'settings', agreed_at: new Date('2026-11-05T00:00:00Z') },
    { consent_type: 'marketing', version: 'v1', agreed: 1, source: 'signup', agreed_at: new Date('2026-11-01T00:00:00Z') },
    { consent_type: 'terms', version: 'v1', agreed: 1, source: 'signup', agreed_at: new Date('2026-11-01T00:00:00Z') },
  ];
  const writes = [];
  const queryFn = async (sql, params) => {
    if (sql.trim().startsWith('SELECT')) return { rows };
    writes.push(params);
    return { rows: { affectedRows: 1 } };
  };
  await withServer(queryFn, async (call) => {
    const got = await call('GET', '/user/consents');
    assert.equal(got.status, 200);
    assert.equal(got.body.consents.marketing.agreed, false);
    assert.equal(got.body.consents.marketing.version, 'v2');
    assert.equal(got.body.consents.terms.agreed, true);
    assert.equal(got.body.consents.age14, null);
    assert.deepEqual(got.body.versions, CONSENT_VERSIONS);

    assert.equal((await call('PUT', '/user/consents/marketing', { agreed: 'yes' })).status, 400);
    assert.equal((await call('PUT', '/user/consents/marketing', { agreed: true })).status, 200);
    assert.deepEqual(writes[0], [5, CONSENT_VERSIONS.marketing, 1]);
  });
  await withServer(queryFn, async (call) => {
    assert.equal((await call('GET', '/user/consents')).status, 401);
  }, null);
  await withServer(async () => {
    throw Object.assign(new Error('no table'), { code: 'ER_NO_SUCH_TABLE' });
  }, async (call) => {
    const res = await call('GET', '/user/consents');
    assert.equal(res.status, 503);
    assert.equal(res.body.reason, 'consents_unavailable');
  });
});
