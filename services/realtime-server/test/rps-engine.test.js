import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveHanabagiRound } from '../src/rps-engine.js';

test('Hanabagi awards the point only to the sole correct guess', () => {
  assert.deepEqual(
    resolveHanabagiRound({ fingers: 2, guess: 5 }, { fingers: 3, guess: 4 }),
    { total: 5, p1Hit: true, p2Hit: false, roundWinner: 'p1' },
  );
  assert.deepEqual(
    resolveHanabagiRound({ fingers: 2, guess: 4 }, { fingers: 3, guess: 5 }),
    { total: 5, p1Hit: false, p2Hit: true, roundWinner: 'p2' },
  );
});

test('Hanabagi is a draw when both or neither player guesses the total', () => {
  assert.equal(
    resolveHanabagiRound({ fingers: 0, guess: 3 }, { fingers: 3, guess: 3 }).roundWinner,
    'draw',
  );
  assert.equal(
    resolveHanabagiRound({ fingers: 5, guess: 0 }, { fingers: 5, guess: 0 }).roundWinner,
    'draw',
  );
});
