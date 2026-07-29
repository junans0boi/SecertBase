import assert from 'node:assert/strict';
import test from 'node:test';
import { businessDate, businessWeekStart } from '../src/business-date.js';

test('businessDate uses the Korea calendar day across the UTC boundary', () => {
  assert.equal(businessDate(new Date('2026-07-29T14:59:59.000Z')), '2026-07-29');
  assert.equal(businessDate(new Date('2026-07-29T15:00:00.000Z')), '2026-07-30');
});

test('businessWeekStart returns the Monday containing the Korea business day', () => {
  assert.equal(businessWeekStart(new Date('2026-08-02T14:59:59.000Z')), '2026-07-27');
  assert.equal(businessWeekStart(new Date('2026-08-02T15:00:00.000Z')), '2026-08-03');
});
