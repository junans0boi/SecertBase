import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import express from 'express';
import test from 'node:test';
import { DatePlanService } from '../src/modules/date-plan/application.js';
import {
  DatePlanError, decodeCursor, encodeCursor, normalizeLimit, normalizeMemo, normalizePlanDate,
  normalizePlanTime, normalizeTitle,
} from '../src/modules/date-plan/domain.js';
import { createDatePlanRouter } from '../src/modules/date-plan/http-router.js';

const rejects = (fn, status, reason) => assert.throws(fn, (e) => e instanceof DatePlanError && e.status === status && e.reason === reason);

test('validation rules', () => {
  assert.equal(normalizeTitle('  카페 가요 '), '카페 가요');
  rejects(() => normalizeTitle('  '), 400, 'invalid_title');
  rejects(() => normalizeTitle('가'.repeat(81)), 400, 'title_too_long');
  assert.equal(normalizeMemo('  '), null);
  rejects(() => normalizeMemo('x'.repeat(501)), 400, 'memo_too_long');
  assert.equal(normalizePlanDate('2026-12-24'), '2026-12-24');
  rejects(() => normalizePlanDate('2026-02-30'), 400, 'invalid_plan_date');
  assert.equal(normalizePlanTime(undefined), null);
  assert.equal(normalizePlanTime('18:30'), '18:30');
  rejects(() => normalizePlanTime('24:00'), 400, 'invalid_plan_time');
  assert.equal(normalizeLimit('500'), 50);
  rejects(() => normalizeLimit('0'), 400, 'invalid_limit');
});

test('cursor round trips and rejects garbage', () => {
  const raw = encodeCursor({ plan_date: '2026-12-24', sort_time: '18:30:00', id: 7 });
  assert.deepEqual(decodeCursor(raw), { date: '2026-12-24', time: '18:30:00', id: 7 });
  assert.equal(decodeCursor(undefined), null);
  rejects(() => decodeCursor('nope'), 400, 'invalid_cursor');
});

test('service rejects when there is no active couple (no plan query is issued)', async () => {
  const sqls = [];
  const service = DatePlanService({ queryFn: async (sql) => { sqls.push(sql); return { rows: [] }; } });
  await assert.rejects(
    service.list({ userId: 5 }, {}),
    (e) => e.status === 403 && e.reason === 'active_couple_required',
  );
  assert.ok(sqls.every((s) => !s.includes('date_plans')));
});

test('router maps auth, scope override and domain errors', async () => {
  const service = {
    list: async () => ({ plans: [], next_cursor: null }),
    get: async () => { throw new DatePlanError(404, 'plan_not_found'); },
  };
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { if (req.get('x-user')) req.auth = { userId: Number(req.get('x-user')) }; next(); });
  app.use('/api', createDatePlanRouter({ service }));
  const server = createServer(app).listen(0);
  await new Promise((r) => server.once('listening', r));
  const base = `http://127.0.0.1:${server.address().port}/api`;
  try {
    assert.equal((await fetch(`${base}/date-plans`)).status, 401);
    assert.equal((await fetch(`${base}/date-plans?user_id=9`, { headers: { 'x-user': '1' } })).status, 403);
    assert.equal((await fetch(`${base}/date-plans`, { headers: { 'x-user': '1' } })).status, 200);
    const missing = await fetch(`${base}/date-plans/3`, { headers: { 'x-user': '1' } });
    assert.equal(missing.status, 404);
    assert.equal((await missing.json()).reason, 'plan_not_found');
  } finally {
    await new Promise((r) => server.close(r));
  }
});
