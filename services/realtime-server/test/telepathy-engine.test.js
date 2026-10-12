import test from 'node:test';
import assert from 'node:assert/strict';
import { telepathyResult } from '../src/telepathy-engine.js';

test('an incomplete telepathy session reveals its existing answer without reporting a match', () => {
  assert.deepEqual(telepathyResult({ id: 'round-1', choices: { alpha: 'tea' } }, 160_000), {
    sessionId: 'round-1', choices: { alpha: 'tea' }, success: false, selected: null, at: 160_000,
  });
});

test('matching telepathy answers reveal the shared choice', () => {
  assert.deepEqual(telepathyResult({ id: 'round-1', choices: { alpha: 'tea', beta: 'tea' } }, 161_000), {
    sessionId: 'round-1', choices: { alpha: 'tea', beta: 'tea' }, success: true, selected: 'tea', at: 161_000,
  });
});

test('different telepathy answers reveal both answers without a selected winner', () => {
  assert.deepEqual(telepathyResult({ id: 'round-1', choices: { alpha: 'tea', beta: 'coffee' } }, 161_000), {
    sessionId: 'round-1', choices: { alpha: 'tea', beta: 'coffee' }, success: false, selected: null, at: 161_000,
  });
});
