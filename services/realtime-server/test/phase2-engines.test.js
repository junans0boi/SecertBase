import test from 'node:test';
import assert from 'node:assert/strict';

import {
  initPenaltyGame,
  resolvePenaltyRound,
} from '../src/penalty-engine.js';

test('Penalty Shootout: saved when kicker and keeper exact 3x3 target match', () => {
  let game = initPenaltyGame('p1', 'p2');
  game = resolvePenaltyRound(game, 0, 0);
  assert.equal(game.rounds[0].isGoal, false); // top-left vs top-left => saved

  game = resolvePenaltyRound(game, 4, 4);
  assert.equal(game.rounds[1].isGoal, false); // center vs center => saved

  game = resolvePenaltyRound(game, 0, 1);
  assert.equal(game.rounds[2].isGoal, true); // top-left vs top-center => goal!

  game = resolvePenaltyRound(game, 5, 0);
  assert.equal(game.rounds[3].isGoal, true); // right-mid vs top-left => goal!
});

test('Penalty Shootout: ends after the fourth kick pair when a 2-goal lead cannot be caught', () => {
  let game = initPenaltyGame('p1', 'p2');
  const shots = [
    [0, 1], // p1 goal
    [0, 0], // p2 save
    [0, 0], // p1 save
    [0, 0], // p2 save
    [0, 0], // p1 save
    [0, 0], // p2 save
    [0, 1], // p1 goal: p1 leads 2-0
    [0, 0], // p2 save: p2 has only one kick left
  ];

  for (const [kickerDir, keeperDir] of shots) {
    game = resolvePenaltyRound(game, kickerDir, keeperDir);
  }

  assert.equal(game.status, 'finished');
  assert.deepEqual(game.scores, { p1: 2, p2: 0 });
  assert.equal(game.result.winner, 'p1');
  assert.equal(game.rounds.length, 8);
});

test('Penalty Shootout: keeps playing when the trailing player can still tie', () => {
  let game = initPenaltyGame('p1', 'p2');
  const shots = [
    [0, 1], // p1 goal
    [0, 0], // p2 save
    [0, 0], // p1 save
    [0, 0], // p2 save
    [0, 0], // p1 save
    [0, 0], // p2 save
    [0, 1], // p1 goal: p1 leads 2-0 with two kicks each left
  ];

  for (const [kickerDir, keeperDir] of shots) {
    game = resolvePenaltyRound(game, kickerDir, keeperDir);
  }

  assert.equal(game.status, 'playing');
  assert.equal(game.result, null);
  assert.deepEqual(game.scores, { p1: 2, p2: 0 });
});

// Bowling Engine tests
import {
  initBowlingGame,
  rollFrame,
  calculateBowlingScore,
  isBowlingFinished,
  nextRollContext,
} from '../src/bowling-engine.js';

test('Bowling Engine: nextRollContext tracks frame position and standing pins', () => {
  assert.deepEqual(nextRollContext([]), { frame: 0, rollInFrame: 0, standing: 10 });
  assert.deepEqual(nextRollContext([5]), { frame: 0, rollInFrame: 1, standing: 5 });
  assert.deepEqual(nextRollContext([5, 3]), { frame: 1, rollInFrame: 0, standing: 10 });
  assert.deepEqual(nextRollContext([10]), { frame: 1, rollInFrame: 0, standing: 10 });
  // 10th frame: strike earns bonus rolls
  const nineStrikes = Array(9).fill(10);
  assert.deepEqual(nextRollContext(nineStrikes), { frame: 9, rollInFrame: 0, standing: 10 });
  assert.deepEqual(nextRollContext([...nineStrikes, 10]), { frame: 9, rollInFrame: 1, standing: 10 });
  assert.deepEqual(nextRollContext([...nineStrikes, 10, 4]), { frame: 9, rollInFrame: 2, standing: 6 });
  assert.equal(nextRollContext([...nineStrikes, 3, 4]), null);
});

test('Bowling Engine: records per-roll aim/curve history for client replay', () => {
  let game = initBowlingGame('p1', 'p2');
  const first = game.turn;
  game = rollFrame(game, first, 5, { aim: 0.3, curve: -0.4 });
  assert.equal(game.history.length, 1);
  assert.deepEqual(game.history[0], {
    playerId: first,
    rollIndex: 0,
    pins: 5,
    aim: 0.3,
    curve: -0.4,
  });
  game = rollFrame(game, first, 2, { aim: -0.1, curve: 0.2 });
  assert.equal(game.history.length, 2);
  assert.equal(game.history[1].rollIndex, 1);
});

test('Bowling Engine: second roll cannot knock more pins than are standing', () => {
  let game = initBowlingGame('p1', 'p2');
  const first = game.turn;
  game = rollFrame(game, first, 5);
  game = rollFrame(game, first, 9); // cheating/desync: only 5 pins remain
  assert.equal(game.rolls[first][1], 5);
  assert.equal(calculateBowlingScore(game.rolls[first]), 10);
});

test('Bowling Engine: strike keeps turn in 10th frame for bonus rolls', () => {
  let game = initBowlingGame('p1', 'p2');
  // Both players bowl 9 open frames, arriving at the 10th.
  for (let f = 0; f < 9; f++) {
    game = rollFrame(game, game.turn, 1);
    game = rollFrame(game, game.turn, 1);
    game = rollFrame(game, game.turn, 1);
    game = rollFrame(game, game.turn, 1);
  }
  const tenth = game.turn;
  game = rollFrame(game, tenth, 10); // strike in 10th → same player keeps rolling
  assert.equal(game.turn, tenth);
  game = rollFrame(game, tenth, 10);
  assert.equal(game.turn, tenth);
  game = rollFrame(game, tenth, 10); // third roll closes the frame
  assert.notEqual(game.turn, tenth);
});

test('Bowling Engine: score calculation with strikes and spares', () => {
  // Perfect game score calculation
  const perfectRolls = Array(12).fill(10);
  assert.equal(calculateBowlingScore(perfectRolls), 300);

  // All spares (5 + 5 each frame, plus final 5)
  const spareRolls = Array(21).fill(5);
  assert.equal(calculateBowlingScore(spareRolls), 150);

  // Open frame game: 10 frames of (3, 4) = 70
  const openRolls = Array(20).fill(3).map((v, i) => i % 2 === 0 ? 3 : 4);
  assert.equal(calculateBowlingScore(openRolls), 70);
});

test('Bowling Engine: full game simulation and winner determination', () => {
  let game = initBowlingGame('p1', 'p2');
  const p1 = 'p1';
  const p2 = 'p2';

  // Both players play open frames for 10 frames
  for (let f = 0; f < 10; f++) {
    game = rollFrame(game, game.turn, 5);
    game = rollFrame(game, game.turn, 3);
    game = rollFrame(game, game.turn, 2);
    game = rollFrame(game, game.turn, 4);
  }

  assert.equal(isBowlingFinished(game), true);
  assert.equal(game.status, 'finished');
  assert.ok(game.result.winner);
});
