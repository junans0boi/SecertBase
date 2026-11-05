import assert from 'node:assert/strict';
import test from 'node:test';
import { applySeriesResult, createSeriesStore, emptySeries } from '../src/games/series.js';
import { REACTION_COOLDOWN_MS, createReactionLimiter } from '../src/games/reaction.js';

test('series counts wins per player and draws, across games', () => {
  let s = emptySeries(['A', 'B']);
  s = applySeriesResult(s, ['A', 'B'], 'A');
  s = applySeriesResult(s, ['A', 'B'], 'draw');
  s = applySeriesResult(s, ['A', 'B'], null);
  s = applySeriesResult(s, ['A', 'B'], 'B');
  assert.deepEqual(s, { wins: { A: 1, B: 1 }, draws: 2, games: 4 });
});

test('series store persists per room and game type', async () => {
  const values = new Map();
  const redis = { get: async (k) => values.get(k) ?? null, set: async (k, v) => { values.set(k, v); return 'OK'; } };
  const store = createSeriesStore(redis);
  await store.record('R', 'blackjack', ['A', 'B'], 'A');
  const after = await store.record('R', 'blackjack', ['A', 'B'], 'A');
  assert.deepEqual(after.wins, { A: 2, B: 0 });
  assert.deepEqual((await store.get('R', 'penalty', ['A', 'B'])).wins, { A: 0, B: 0 });
});

test('reaction limiter enforces a per-user cooldown', () => {
  let now = 1000;
  const allow = createReactionLimiter(() => now);
  assert.equal(allow('A'), true);
  assert.equal(allow('A'), false);
  assert.equal(allow('B'), true);
  now += REACTION_COOLDOWN_MS;
  assert.equal(allow('A'), true);
});
