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
  assert.equal(calcAcquireCost(1, 1), 1_000_000, 'level 1 = land only: price x2');
  assert.equal(calcAcquireCost(8, 0), 0, 'tourist spots cannot be acquired');
  assert.equal(hasColorMonopoly(state, 'user1', 1), true);
  assert.equal(hasColorMonopoly(state, 'user2', 1), false);
});

test('tourist monopoly win reports tourist_monopoly reason', async () => {
  const { checkMarbleWin } = await import('../src/marble-engine.js');
  const g = createMarbleGameState('a', 'b');
  g.lands[8] = { owner: 'a', level: 0 };
  g.lands[17] = { owner: 'a', level: 0 };
  assert.deepEqual(checkMarbleWin(g), { winner: 'a', reason: 'tourist_monopoly' });
});

test('serializeMarbleGame sends authoritative total assets per player', async () => {
  const { serializeMarbleGame, calcScore } = await import('../src/marble-engine.js');
  const g = createMarbleGameState('a', 'b');
  g.lands[1] = { owner: 'a', level: 2 };
  const s = serializeMarbleGame(g);
  assert.equal(s.assets.a, calcScore(g, 'a'));
  assert.equal(s.assets.b, calcScore(g, 'b'));
});

// ── 게임 정비(#191): 1-based 레벨·특수칸 ───────────────────────────────
test('tolls follow the stored 1-based level: land, house, building, landmark', async () => {
  const { calcToll } = await import('../src/marble-engine.js');
  assert.equal(calcToll(1, 1), 20_000, '땅만 산 칸은 땅 통행료');
  assert.equal(calcToll(1, 2), 80_000);
  assert.equal(calcToll(1, 3), 250_000);
  assert.equal(calcToll(1, 4), 700_000, '랜드마크는 랜드마크 통행료');
});

test('total assets count only what was actually built', async () => {
  const { calcScore, createMarbleGameState } = await import('../src/marble-engine.js');
  const g = createMarbleGameState('a', 'b');
  g.lands[1] = { owner: 'a', level: 1 };
  assert.equal(calcScore(g, 'a'), 5_000_000 + 500_000);
  g.lands[1].level = 4;
  assert.equal(calcScore(g, 'a'), 5_000_000 + 500_000 + 200_000 + 500_000 + 1_000_000);
});

test('tourist spots cannot be upgraded and a zero balance is not bankruptcy', async () => {
  const { calcUpgradeCost, checkMarbleWin, createMarbleGameState } = await import('../src/marble-engine.js');
  assert.equal(calcUpgradeCost(8, 1), 0);
  const g = createMarbleGameState('a', 'b');
  g.players.a.coins = 0;
  assert.equal(checkMarbleWin(g), null);
  g.players.a.coins = -1;
  assert.deepEqual(checkMarbleWin(g), { winner: 'b', reason: 'bankrupt' });
});

test('jail and gate tiles are dispatched as special tiles; gate lands on a city', async () => {
  const { getMarbleSpecialType, pickGateDestination, getTileType } = await import('../src/marble-engine.js');
  assert.equal(getMarbleSpecialType(6), 'jail');
  assert.equal(getMarbleSpecialType(18), 'gate');
  for (const r of [0, 0.3, 0.99]) assert.equal(getTileType(pickGateDestination(() => r)), 'property');
});

test('equipped toll reduction is summed across slots', async () => {
  const { sumEquippedStat } = await import('../src/marble-engine.js');
  assert.equal(sumEquippedStat({ hat: { stats: { land_toll_reduce_pct: 10 } }, cape: { stats: { land_toll_reduce_pct: 5 } } }, 'land_toll_reduce_pct'), 15);
  assert.equal(sumEquippedStat(undefined, 'land_toll_reduce_pct'), 0);
});
