import assert from 'node:assert/strict';
import test from 'node:test';
import { canReplaceTodayMoment, todayMomentStatus } from '../src/today-moment-policy.js';

test('a Today Moment can be replaced only before the Today Loop is revealed', () => {
  assert.equal(canReplaceTodayMoment(null), true);
  assert.equal(canReplaceTodayMoment('2026-07-29T10:00:00.000Z'), false);
});

test('todayMomentStatus describes the authenticated user perspective', () => {
  assert.equal(todayMomentStatus({ hasMine: false, hasPartner: false, viewed: false }), 'empty');
  assert.equal(todayMomentStatus({ hasMine: false, hasPartner: true, viewed: false }), 'partner_waiting');
  assert.equal(todayMomentStatus({ hasMine: true, hasPartner: false, viewed: false }), 'self_waiting');
  assert.equal(todayMomentStatus({ hasMine: true, hasPartner: true, viewed: false }), 'complete');
  assert.equal(todayMomentStatus({ hasMine: true, hasPartner: true, viewed: true }), 'viewed');
});
