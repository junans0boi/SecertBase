import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ZERO_REGULATION_ROUNDS,
  ZERO_SUDDEN_DEATH_CAP,
  applyZeroRound,
  createZeroMatch,
  guessRange,
  randomZeroPick,
  resolveZeroRound,
  smartZeroPick,
  validateZeroPick,
} from '../src/zero-engine.js';

test('zero: an exact guess scores 2 and beats a near miss', () => {
  assert.deepEqual(resolveZeroRound({ fingers: 3, guess: 5 }, { fingers: 2, guess: 6 }), {
    total: 5, distance: [0, 1], exact: [true, false], points: [2, 0], roundWinner: 'p1',
  });
  assert.deepEqual(resolveZeroRound({ fingers: 0, guess: 5 }, { fingers: 4, guess: 4 }), {
    total: 4, distance: [1, 0], exact: [false, true], points: [0, 2], roundWinner: 'p2',
  });
});

test('zero: when both miss the closer guess scores 1', () => {
  const r = resolveZeroRound({ fingers: 1, guess: 3 }, { fingers: 4, guess: 9 });
  assert.equal(r.total, 5);
  assert.deepEqual(r.distance, [2, 4]);
  assert.deepEqual(r.points, [1, 0]);
  assert.equal(r.roundWinner, 'p1');
  assert.deepEqual(resolveZeroRound({ fingers: 5, guess: 10 }, { fingers: 2, guess: 6 }).points, [0, 1]);
});

test('zero: equal distance scores nobody and both exact score 2 each', () => {
  const same = resolveZeroRound({ fingers: 2, guess: 3 }, { fingers: 2, guess: 5 });
  assert.deepEqual(same.distance, [1, 1]);
  assert.deepEqual(same.points, [0, 0]);
  assert.equal(same.roundWinner, 'draw');
  const both = resolveZeroRound({ fingers: 1, guess: 4 }, { fingers: 3, guess: 4 });
  assert.deepEqual(both.exact, [true, true]);
  assert.deepEqual(both.points, [2, 2]);
  assert.equal(both.roundWinner, 'draw');
});

test('zero: the guess must lie between own fingers and own fingers + 5', () => {
  assert.deepEqual(guessRange(3), { min: 3, max: 8 });
  assert.equal(validateZeroPick({ fingers: 3, guess: 3 }), 'ok');
  assert.equal(validateZeroPick({ fingers: 3, guess: 8 }), 'ok');
  assert.equal(validateZeroPick({ fingers: 0, guess: 0 }), 'ok');
  assert.equal(validateZeroPick({ fingers: 5, guess: 10 }), 'ok');
  assert.equal(validateZeroPick({ fingers: 3, guess: 2 }), 'invalid_guess');
  assert.equal(validateZeroPick({ fingers: 3, guess: 9 }), 'invalid_guess');
  assert.equal(validateZeroPick({ fingers: 2, guess: 3.5 }), 'invalid_guess');
  assert.equal(validateZeroPick({ fingers: 6, guess: 6 }), 'invalid_fingers');
  assert.equal(validateZeroPick({ fingers: -1, guess: 0 }), 'invalid_fingers');
  assert.equal(validateZeroPick({}), 'invalid_fingers');
});

test('zero: five rounds are summed and a lead after round 5 wins', () => {
  let m = createZeroMatch();
  const rounds = [[2, 0], [0, 1], [1, 0], [0, 0], [2, 2]];
  rounds.forEach((points, i) => {
    assert.equal(m.finished, false, `round ${i + 1} still in play`);
    m = applyZeroRound(m, { points });
  });
  assert.deepEqual(m.scores, [5, 3]);
  assert.equal(m.finished, true);
  assert.equal(m.winner, 'p1');
  assert.equal(m.reason, 'score');
  assert.equal(m.round, ZERO_REGULATION_ROUNDS + 1);
});

test('zero: a tie after round 5 goes to sudden death until a round is decided', () => {
  let m = createZeroMatch();
  for (const points of [[1, 0], [0, 1], [2, 2], [0, 0], [0, 1]]) m = applyZeroRound(m, { points });
  assert.deepEqual(m.scores, [3, 4]);
  assert.equal(m.finished, true, 'p2 leads after five');
  m = createZeroMatch();
  for (const points of [[1, 0], [0, 1], [2, 2], [0, 0], [0, 0]]) m = applyZeroRound(m, { points });
  assert.equal(m.finished, false);
  assert.equal(m.suddenDeath, true);
  m = applyZeroRound(m, { points: [2, 2] });
  assert.equal(m.finished, false, 'a drawn sudden death round continues');
  assert.equal(m.suddenDeathRounds, 1);
  m = applyZeroRound(m, { points: [0, 1] });
  assert.equal(m.finished, true);
  assert.equal(m.winner, 'p2');
  assert.equal(m.reason, 'sudden_death');
});

test('zero: sudden death is capped and then the match is a draw', () => {
  let m = createZeroMatch();
  for (let i = 0; i < ZERO_REGULATION_ROUNDS; i++) m = applyZeroRound(m, { points: [0, 0] });
  for (let i = 0; i < ZERO_SUDDEN_DEATH_CAP - 1; i++) {
    m = applyZeroRound(m, { points: [1, 1] });
    assert.equal(m.finished, false);
  }
  m = applyZeroRound(m, { points: [0, 0] });
  assert.equal(m.finished, true);
  assert.equal(m.winner, 'draw');
  assert.equal(m.reason, 'draw_cap');
});

test('zero: random and smart picks are always valid', () => {
  const random = seeded(7);
  for (let i = 0; i < 2000; i++) {
    assert.equal(validateZeroPick(randomZeroPick(random)), 'ok');
    assert.equal(validateZeroPick(smartZeroPick(random)), 'ok');
  }
});

// 균형 테스트(02-spec): 라운드 점수 갈림 > 65%, 한 판 평균 ≤ 7라운드. 시드 고정.
function seeded(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function simulate(policy1, policy2, matches, random) {
  let rounds = 0;
  let decisive = 0;
  let draws = 0;
  for (let g = 0; g < matches; g++) {
    let m = createZeroMatch();
    while (!m.finished) {
      const r = resolveZeroRound(policy1(random), policy2(random));
      if (r.roundWinner !== 'draw') decisive++;
      rounds++;
      m = applyZeroRound(m, r);
    }
    if (m.winner === 'draw') draws++;
  }
  return { decisiveRate: decisive / rounds, avgRounds: rounds / matches, drawRate: draws / matches };
}

for (const [label, p1, p2, seed] of [
  ['random vs random', randomZeroPick, randomZeroPick, 11],
  ['smart vs smart', smartZeroPick, smartZeroPick, 23],
  ['random vs smart', randomZeroPick, smartZeroPick, 37],
]) {
  test(`zero balance (${label}, 20k matches): rounds decide > 65% and a match averages <= 7 rounds`, () => {
    const s = simulate(p1, p2, 20_000, seeded(seed));
    assert.ok(s.decisiveRate > 0.65, `decisive ${s.decisiveRate}`);
    assert.ok(s.avgRounds <= 7, `avg rounds ${s.avgRounds}`);
    assert.ok(s.avgRounds >= 5, 'at least the five regulation rounds');
    assert.ok(s.drawRate < 0.01, `final draws ${s.drawRate}`);
  });
}
