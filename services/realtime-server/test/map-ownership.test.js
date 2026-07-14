import test from 'node:test';
import assert from 'node:assert/strict';

import {
  canEditMapPin,
  normalizeMapEditorUserId,
} from '../src/map-ownership.js';

test('normalizeMapEditorUserId accepts only positive integer user ids', () => {
  assert.equal(normalizeMapEditorUserId('7'), 7);
  assert.equal(normalizeMapEditorUserId(7), 7);
  assert.equal(normalizeMapEditorUserId('0'), null);
  assert.equal(normalizeMapEditorUserId('abc'), null);
  assert.equal(normalizeMapEditorUserId(1.5), null);
});

test('canEditMapPin allows the stored author user id only', () => {
  assert.equal(canEditMapPin({ user_id: 4, created_by: 'U4' }, 4, 'U4'), true);
  assert.equal(canEditMapPin({ user_id: 4, created_by: 'U4' }, 5, 'U5'), false);
});

test('canEditMapPin falls back to UserCode for legacy pins without user_id', () => {
  assert.equal(
    canEditMapPin({ user_id: null, created_by: 'ABCD12' }, 9, 'ABCD12'),
    true
  );
  assert.equal(
    canEditMapPin({ user_id: null, created_by: 'ABCD12' }, 9, 'ZZZZ99'),
    false
  );
});
