import test from 'node:test';
import assert from 'node:assert/strict';

// Penalty match logic test (Exact 3x3 match out of 9 targets)
function checkPenaltySave(kickerDir, keeperDir) {
  return kickerDir === keeperDir;
}

test('Penalty Shootout: saved when kicker and keeper exact 3x3 target match', () => {
  assert.equal(checkPenaltySave(0, 0), true); // top-left vs top-left => saved
  assert.equal(checkPenaltySave(4, 4), true); // center vs center => saved
  assert.equal(checkPenaltySave(0, 1), false); // top-left vs top-center => goal!
  assert.equal(checkPenaltySave(5, 0), false); // right-mid vs top-left => goal!
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
