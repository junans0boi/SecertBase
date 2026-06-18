import test from 'node:test';
import assert from 'node:assert/strict';
import {
  YUT_RESULTS,
  throwYut,
  movePiece,
  getCarriedPieces,
  checkCatch,
} from '../src/yut-engine.js';

function withMockedRandom(values, run) {
  const originalRandom = Math.random;
  let index = 0;
  Math.random = () => values[index++] ?? 0.9;
  try {
    run();
  } finally {
    Math.random = originalRandom;
  }
}

test('throwYut returns mo, yut, and backdo distinctly', () => {
  withMockedRandom([0.9, 0.9, 0.9, 0.9], () => {
    const result = throwYut();
    assert.equal(result.result, YUT_RESULTS.MO);
    assert.equal(result.resultName, '모');
    assert.equal(result.bonusThrow, true);
  });

  withMockedRandom([0.1, 0.1, 0.1, 0.1], () => {
    const result = throwYut();
    assert.equal(result.result, YUT_RESULTS.YUT);
    assert.equal(result.resultName, '윷');
    assert.equal(result.bonusThrow, true);
  });

  withMockedRandom([0.1, 0.9, 0.9, 0.9], () => {
    const result = throwYut();
    assert.equal(result.result, YUT_RESULTS.BACKDO);
    assert.equal(result.resultName, '백도');
    assert.equal(result.bonusThrow, false);
  });
});

test('movePiece follows shortcut and backdo routes', () => {
  assert.deepEqual(movePiece({ position: 5, lastPos: 4 }, 1), {
    position: 21,
    lastPos: 5,
  });
  assert.deepEqual(movePiece({ position: 10, lastPos: 9 }, 3), {
    position: 23,
    lastPos: 25,
  });
  assert.deepEqual(movePiece({ position: 23, lastPos: 25 }, -1), {
    position: 25,
    lastPos: 23,
  });
});

test('getCarriedPieces carries stacked field pieces but not start pieces', () => {
  const pieces = [
    { id: 0, position: 3, finished: false },
    { id: 1, position: 3, finished: false },
    { id: 2, position: 0, finished: false },
    { id: 3, position: 0, finished: false },
  ];

  assert.deepEqual(getCarriedPieces(pieces[0], pieces).map((piece) => piece.id), [0, 1]);
  assert.deepEqual(getCarriedPieces(pieces[2], pieces).map((piece) => piece.id), [2]);
});

test('checkCatch ignores start and goal positions', () => {
  const opponentPieces = [
    { id: 0, position: 0, finished: false },
    { id: 1, position: 3, finished: false },
    { id: 2, position: 20, finished: true },
  ];

  assert.equal(checkCatch(0, opponentPieces).length, 0);
  assert.equal(checkCatch(20, opponentPieces).length, 0);
  assert.deepEqual(checkCatch(3, opponentPieces).map((piece) => piece.id), [1]);
});
