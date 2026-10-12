import test from 'node:test';
import assert from 'node:assert/strict';
import { TELEPATHY_SESSION_TTL_SEC } from '../src/telepathy-engine.js';

test('telepathy session outlives a slow partner (>60s)', () => {
  assert.ok(TELEPATHY_SESSION_TTL_SEC > 60);
});
