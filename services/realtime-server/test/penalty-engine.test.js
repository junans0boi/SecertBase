import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AUTO_PICK_FORFEIT,
  MAX_KICKS_PER_PLAYER,
  PENALTY_REVEAL_MS,
  PENALTY_TURN_MS,
  SUDDEN_DEATH_PAIRS_BY_CELLS,
  autoPickMissing,
  forfeitPenalty,
  initPenaltyGame,
  isLegacyPenaltyState,
  isValidChoice,
  maskPenaltyState,
  resolvePenaltyRound,
  submitPenaltyChoice,
} from '../src/penalty-engine.js';

// 결정적 난수(mulberry32).
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

const first = (kicker) => ({ random: () => (kicker === 'A' ? 0.1 : 0.9) });
const pair = (g, aGoal, bGoal) => {
  g = resolvePenaltyRound(g, 0, aGoal ? 1 : 0);
  return resolvePenaltyRound(g, 0, bGoal ? 1 : 0);
};

test('init: the first kicker is random (injected) and the first deadline is startsAt + 20 s', () => {
  const a = initPenaltyGame('A', 'B', { random: () => 0.1, startsAt: 5_000, gameId: 'g1' });
  assert.equal(a.kicker, 'A');
  assert.equal(a.keeper, 'B');
  assert.equal(a.firstKicker, 'A');
  assert.equal(a.turnDeadline, 5_000 + PENALTY_TURN_MS);
  assert.equal(a.gameId, 'g1');
  assert.equal(a.cells, 3, 'a game created without options has 3 cells');
  assert.deepEqual(a.players, ['A', 'B']);
  const b = initPenaltyGame('A', 'B', { random: () => 0.9 });
  assert.equal(b.kicker, 'B');
  assert.equal(b.keeper, 'A');
  assert.equal(initPenaltyGame('A', 'B', { firstKicker: 'B', random: () => 0 }).kicker, 'B');
});

test('init: only 3 or 6 cells; anything else falls back to 3', () => {
  assert.equal(initPenaltyGame('A', 'B', { cells: 6 }).cells, 6);
  assert.equal(initPenaltyGame('A', 'B', { cells: 9 }).cells, 3);
  assert.equal(initPenaltyGame('A', 'B', { cells: '6' }).cells, 3);
});

test('choice validation: 0 ≤ choice < cells', () => {
  assert.equal(isValidChoice(3, 0), true);
  assert.equal(isValidChoice(3, 2), true);
  assert.equal(isValidChoice(3, 3), false);
  assert.equal(isValidChoice(6, 5), true);
  assert.equal(isValidChoice(6, 6), false);
  assert.equal(isValidChoice(3, -1), false);
  assert.equal(isValidChoice(3, 1.5), false);
  assert.equal(isValidChoice(3, '1'), false);
});

test('3 cells: same direction is a save, a different direction is a goal', () => {
  let g = initPenaltyGame('A', 'B', first('A'));
  g = resolvePenaltyRound(g, 0, 0);
  assert.equal(g.rounds[0].isGoal, false);
  g = resolvePenaltyRound(g, 2, 1);
  assert.equal(g.rounds[1].isGoal, true);
  assert.deepEqual(g.scores, { A: 0, B: 1 });
  assert.equal(g.kicker, 'A', 'kicker and keeper alternate');
});

test('6 cells: top and bottom of the same column are different cells', () => {
  let g = initPenaltyGame('A', 'B', { ...first('A'), cells: 6 });
  g = resolvePenaltyRound(g, 0, 3);
  assert.equal(g.rounds[0].isGoal, true);
  g = resolvePenaltyRound(g, 5, 5);
  assert.equal(g.rounds[1].isGoal, false);
});

test('submit: both choices resolve the round, a resubmit or out-of-range choice is refused', () => {
  let g = initPenaltyGame('A', 'B', first('A'));
  assert.equal(submitPenaltyChoice(g, 'A', 3).reason, 'invalid_choice');
  assert.equal(submitPenaltyChoice(g, 'C', 1).reason, 'not_a_player');
  let r = submitPenaltyChoice(g, 'A', 2, { now: 1_000 });
  assert.equal(r.ok, true);
  assert.equal(r.resolved, false);
  g = r.game;
  assert.equal(submitPenaltyChoice(g, 'A', 1).reason, 'already_submitted');
  r = submitPenaltyChoice(g, 'B', 2, { now: 1_000 });
  assert.equal(r.resolved, true);
  assert.equal(r.game.rounds[0].isGoal, false);
  assert.equal(r.game.turnDeadline, 1_000 + PENALTY_REVEAL_MS + PENALTY_TURN_MS);
  assert.deepEqual(r.game.submissions, {});
});

test('public state hides pending directions but keeps past rounds', () => {
  let g = initPenaltyGame('A', 'B', first('A'));
  g = submitPenaltyChoice(g, 'A', 1).game;
  g = submitPenaltyChoice(g, 'B', 0).game;
  g = submitPenaltyChoice(g, 'B', 2).game;
  const view = maskPenaltyState(g);
  assert.deepEqual(view.submissions, { B: true });
  assert.equal(view.rounds[0].kickerDir, 1);
  assert.equal(view.rounds[0].keeperDir, 0);
  assert.equal(JSON.stringify(view).includes('"B":2'), false);
});

test('ends early when the trailing player cannot catch up', () => {
  let g = initPenaltyGame('p1', 'p2', { random: () => 0 });
  for (const [k, gk] of [[0, 1], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 1], [0, 0]]) {
    g = resolvePenaltyRound(g, k, gk);
  }
  assert.equal(g.status, 'finished');
  assert.deepEqual(g.scores, { p1: 2, p2: 0 });
  assert.equal(g.result.winner, 'p1');
  assert.equal(g.rounds.length, 8);
});

test('keeps playing while the trailing player can still tie', () => {
  let g = initPenaltyGame('p1', 'p2', { random: () => 0 });
  for (const [k, gk] of [[0, 1], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 1]]) {
    g = resolvePenaltyRound(g, k, gk);
  }
  assert.equal(g.status, 'playing');
  assert.equal(g.result, null);
});

test('5:5 continues into sudden death, judged only after both kick', () => {
  let g = initPenaltyGame('A', 'B', first('A'));
  for (let i = 0; i < MAX_KICKS_PER_PLAYER; i++) g = pair(g, true, true);
  assert.equal(g.status, 'playing');
  assert.equal(g.suddenDeath, true);
  g = resolvePenaltyRound(g, 0, 1);
  assert.equal(g.status, 'playing', 'B still gets the reply kick');
  g = resolvePenaltyRound(g, 0, 0);
  assert.equal(g.status, 'finished');
  assert.equal(g.result.winner, 'A');
});

for (const cells of [3, 6]) {
  test(`${cells} cells: after ${SUDDEN_DEATH_PAIRS_BY_CELLS[cells]} sudden death pairs it is a draw`, () => {
    let g = initPenaltyGame('A', 'B', { ...first('A'), cells });
    for (let i = 0; i < MAX_KICKS_PER_PLAYER + SUDDEN_DEATH_PAIRS_BY_CELLS[cells] - 1; i++) g = pair(g, true, true);
    assert.equal(g.status, 'playing');
    g = pair(g, true, true);
    assert.equal(g.status, 'finished');
    assert.equal(g.result.winner, 'draw');
    assert.equal(g.result.reason, 'draw');
  });
}

test('timer: missing choices are picked at random and the round resolves', () => {
  let g = initPenaltyGame('A', 'B', first('A'));
  g = submitPenaltyChoice(g, 'A', 1).game;
  const r = autoPickMissing(g, { random: () => 0.99, now: 9_000 });
  assert.deepEqual(r.autoPicked, ['B']);
  assert.equal(r.forfeitBy, null);
  assert.equal(r.game.rounds.length, 1);
  assert.equal(r.game.rounds[0].keeperDir, 2);
  assert.equal(r.game.rounds[0].autoKeeper, true);
  assert.equal(r.game.rounds[0].autoKicker, false);
  assert.equal(r.game.autoPicks.B, 1);
  assert.equal(r.game.autoPicks.A, 0);
  assert.equal(r.game.turnDeadline, 9_000 + PENALTY_REVEAL_MS + PENALTY_TURN_MS);
  assert.equal('autoSubmitted' in r.game, false);
});

test('timer: auto picks stay inside 6 cells', () => {
  const g = initPenaltyGame('A', 'B', { ...first('A'), cells: 6 });
  const r = autoPickMissing(g, { random: () => 0.9999 });
  assert.equal(r.game.rounds[0].kickerDir, 5);
  assert.equal(r.game.rounds[0].keeperDir, 5);
});

test(`timer: ${AUTO_PICK_FORFEIT} auto picks in a row forfeit, a real choice resets the count`, () => {
  let g = initPenaltyGame('A', 'B', first('A'));
  const rnd = seeded(1);
  // A는 계속 직접 고르고 B는 계속 잠수.
  for (let i = 0; i < AUTO_PICK_FORFEIT - 1; i++) {
    g = submitPenaltyChoice(g, 'A', 0).game;
    g = autoPickMissing(g, { random: rnd }).game;
  }
  assert.equal(g.autoPicks.B, AUTO_PICK_FORFEIT - 1);
  // B가 한 번 직접 고르면 다시 0.
  const reset = submitPenaltyChoice(g, 'B', 1).game;
  assert.equal(reset.autoPicks.B, 0);
  g = submitPenaltyChoice(g, 'A', 0).game;
  const r = autoPickMissing(g, { random: rnd });
  assert.equal(r.forfeitBy, 'B');
  assert.equal(r.game.status, 'finished');
  assert.equal(r.game.result.winner, 'A');
  assert.equal(r.game.result.loser, 'B');
  assert.equal(r.game.result.reason, 'forfeit');
  assert.equal(r.game.rounds.length, AUTO_PICK_FORFEIT - 1, 'the forfeiting round is not played');
});

test('timer: both players idle three times ends the game without a winner', () => {
  let g = initPenaltyGame('A', 'B', first('A'));
  let r;
  for (let i = 0; i < AUTO_PICK_FORFEIT; i++) {
    r = autoPickMissing(g, { random: seeded(i) });
    g = r.game;
  }
  assert.equal(r.abandoned, true);
  assert.equal(g.status, 'finished');
  assert.equal(g.result.winner, 'draw');
  assert.equal(g.result.reason, 'abandoned');
});

test('forfeit names the other player as winner', () => {
  const g = forfeitPenalty(initPenaltyGame('A', 'B'), 'A');
  assert.equal(g.result.winner, 'B');
  assert.equal(g.result.loser, 'A');
  assert.equal(g.status, 'finished');
});

test('legacy (9 cell) states are detected for cleanup', () => {
  assert.equal(isLegacyPenaltyState(initPenaltyGame('A', 'B')), false);
  assert.equal(isLegacyPenaltyState(initPenaltyGame('A', 'B', { cells: 6 })), false);
  const old = { status: 'playing', round: 1, kicker: 'A', keeper: 'B', submissions: {}, scores: { A: 0, B: 0 }, rounds: [] };
  assert.equal(isLegacyPenaltyState(old), true, 'no cells → legacy');
  const outOfRange = initPenaltyGame('A', 'B');
  outOfRange.rounds = [{ kicker: 'A', keeper: 'B', kickerDir: 7, keeperDir: 0, isGoal: true }];
  assert.equal(isLegacyPenaltyState(outOfRange), true);
  const pending = { ...initPenaltyGame('A', 'B'), submissions: { A: 8 } };
  assert.equal(isLegacyPenaltyState(pending), true);
  assert.equal(isLegacyPenaltyState(null), true);
});

// ── 균형 테스트: 두 사람이 무작위로 고를 때 ─────────────────────────────────
function simulate(cells, games, seed) {
  const rnd = seeded(seed);
  let kicks = 0, saves = 0, draws = 0, firstKickerWins = 0;
  for (let i = 0; i < games; i++) {
    let g = initPenaltyGame('A', 'B', { cells, random: rnd });
    while (g.status === 'playing') {
      g = submitPenaltyChoice(g, g.kicker, Math.floor(rnd() * cells)).game;
      g = submitPenaltyChoice(g, g.keeper, Math.floor(rnd() * cells)).game;
    }
    kicks += g.rounds.length;
    saves += g.rounds.filter((r) => !r.isGoal).length;
    if (g.result.winner === 'draw') draws += 1;
    else if (g.result.winner === g.firstKicker) firstKickerWins += 1;
  }
  return { saveRate: saves / kicks, drawRate: draws / games, firstKickerRate: firstKickerWins / (games - draws) };
}

test('balance: 3 cells → save rate 30–36 %, final draw < 3 %', () => {
  const { saveRate, drawRate } = simulate(3, 20_000, 37);
  assert.ok(saveRate >= 0.30 && saveRate <= 0.36, `save rate ${saveRate}`);
  assert.ok(drawRate < 0.03, `draw rate ${drawRate}`);
});

test('balance: 6 cells → save rate 14–20 %, final draw < 3 %', () => {
  const { saveRate, drawRate } = simulate(6, 20_000, 38);
  assert.ok(saveRate >= 0.14 && saveRate <= 0.20, `save rate ${saveRate}`);
  assert.ok(drawRate < 0.03, `draw rate ${drawRate}`);
});

test('balance: the first kicker gains no large edge', () => {
  for (const cells of [3, 6]) {
    const { firstKickerRate } = simulate(cells, 10_000, 40 + cells);
    assert.ok(firstKickerRate > 0.45 && firstKickerRate < 0.55, `${cells} cells first kicker win rate ${firstKickerRate}`);
  }
});
