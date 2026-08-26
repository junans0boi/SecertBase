import test from 'node:test';
import assert from 'node:assert/strict';
import {
  TILE_TYPES,
  getMarbleSpecialType,
  createMarbleGameState,
  movePiece,
  settleTurnAfterMove,
  calcPurchaseCost,
  calcAcquireCost,
  calcUpgradeCost,
  hasColorMonopoly,
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

test('marble state starts with one pawn and no legacy capture/audio state', () => {
  const state = createMarbleGameState('user1', 'user2');

  assert.equal(state.phase, 'roll_order');
  assert.equal(state.players.user1.pieces.length, 1);
  assert.equal(state.players.user2.pieces.length, 1);
  assert.equal(state.pendingLandAction, null);
  assert.equal('bgm' in state, false);
  assert.equal('catchBonusPending' in state, false);
});

test('marble movement wraps around the board and pays salary once at start', () => {
  const result = movePiece({ position: 22 }, 4);

  assert.deepEqual(result, {
    position: 2,
    lastPos: 22,
    passedStart: true,
    finished: false,
  });
});

test('marble turn settlement keeps a double with the same player', () => {
  const state = createMarbleGameState('user1', 'user2');
  state.currentTurn = 'user1';
  state.phase = 'moving';
  state.pendingMoves = [];
  state.hasDoubleRoll = true;

  settleTurnAfterMove(state, 'user1');

  assert.equal(state.currentTurn, 'user1');
  assert.equal(state.phase, 'throwing');
  assert.equal(state.hasDoubleRoll, false);
});

test('marble purchase, acquisition, and color monopoly use property rules', () => {
  const state = createMarbleGameState('user1', 'user2');
  state.lands[1] = { owner: 'user1', level: 1 };
  state.lands[2] = { owner: 'user1', level: 1 };

  assert.equal(calcPurchaseCost(1), 500_000);
  assert.equal(calcAcquireCost(1, 1), 1_400_000);
  assert.equal(calcAcquireCost(8, 0), 0, 'tourist spots cannot be acquired');
  assert.equal(hasColorMonopoly(state, 'user1', 1), true);
  assert.equal(hasColorMonopoly(state, 'user2', 1), false);
});
