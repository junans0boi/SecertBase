import test from 'node:test';
import assert from 'node:assert/strict';
import {
  TILE_TYPES,
  getMarbleSpecialType,
  calcUpgradeCost,
} from '../src/marble-engine.js';

test('marble special positions match the 24-tile board', () => {
  assert.deepEqual(
    [3, 9, 15, 21].map(getMarbleSpecialType),
    ['card', 'card', 'card', 'card'],
  );
  assert.equal(getMarbleSpecialType(12), 'tax');
  assert.equal(getMarbleSpecialType(1), null);
  assert.equal(Object.keys(TILE_TYPES).length, 10);
});

test('marble upgrade costs follow the house/building/landmark price table', () => {
  assert.equal(calcUpgradeCost(1, 1), 200_000);
  assert.equal(calcUpgradeCost(1, 2), 500_000);
  assert.equal(calcUpgradeCost(1, 3), 1_000_000);
});
