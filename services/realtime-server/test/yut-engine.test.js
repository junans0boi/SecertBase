import test from 'node:test';
import assert from 'node:assert/strict';
import {
  YUT_RESULTS,
  throwYut,
  movePiece,
  getCarriedPieces,
  hasBackdoMove,
  checkCatch,
  recordCapture,
  settleTurnAfterMove,
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
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 10, lastPos: 9 }, 3), {
    position: 23,
    lastPos: 25,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 23, lastPos: 25 }, -1), {
    position: 25,
    lastPos: 23,
  });
  assert.deepEqual(movePiece({ position: 21, lastPos: 5 }, 3), {
    position: 28,
    lastPos: 23,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 23, lastPos: 22 }, 2), {
    position: 27,
    lastPos: 26,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 23, lastPos: 22 }, 3), {
    position: 20,
    lastPos: 27,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 27, lastPos: 26 }, 1), {
    position: 20,
    lastPos: 27,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 27, lastPos: 26 }, 2), {
    position: 20,
    lastPos: 20,
    finished: true,
  });
  assert.deepEqual(movePiece({ position: 23, lastPos: 25 }, 2), {
    position: 27,
    lastPos: 26,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 5, lastPos: 4 }, 5), {
    position: 29,
    lastPos: 28,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 19, lastPos: 18 }, 1), {
    position: 20,
    lastPos: 19,
    finished: false,
  });
  assert.deepEqual(movePiece({ position: 19, lastPos: 18 }, 2), {
    position: 20,
    lastPos: 20,
    finished: true,
  });
  assert.deepEqual(movePiece({ position: 20, lastPos: 19 }, 1), {
    position: 20,
    lastPos: 20,
    finished: true,
  });
  assert.deepEqual(movePiece({ position: 20, lastPos: 19 }, -1), {
    position: 19,
    lastPos: 20,
  });
});

test('nal-backdo waits on the goal square instead of returning to start', () => {
  // 첫 턴 도(1칸) 직후 빽도: 대기(0)로 빠지지 않고 도착 칸(20)에서 대기해야 한다.
  assert.deepEqual(movePiece({ position: 1, lastPos: 0 }, YUT_RESULTS.BACKDO), {
    position: 20,
    lastPos: 1,
  });
  // 도착 칸에서 다음 이동이 있어야 완주된다.
  assert.deepEqual(movePiece({ position: 20, lastPos: 1 }, 1), {
    position: 20,
    lastPos: 20,
    finished: true,
  });
});

test('hasBackdoMove returns false when backdo should become nak', () => {
  assert.equal(
    hasBackdoMove([
      { position: 0, finished: false },
      { position: 0, finished: false },
      { position: 20, finished: true },
    ]),
    false,
  );
  assert.equal(
    hasBackdoMove([
      { position: 0, finished: false },
      { position: 20, finished: false },
    ]),
    true,
  );
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

test('catch during multi-move turn keeps the extra turn until all moves settle', () => {
  const gameState = {
    playersOrder: ['A', 'B'],
    currentTurn: 'A',
    phase: 'moving',
    pendingMoves: [4, 1],
    caughtOpponentThisTurn: false,
  };

  // 윷+도 펜딩 중 첫 이동(윷)에서 잡기 발생.
  gameState.pendingMoves.splice(0, 1);
  recordCapture(gameState, 1);
  settleTurnAfterMove(gameState, 'A');
  assert.equal(gameState.phase, 'moving');
  assert.equal(gameState.currentTurn, 'A');

  // 마지막 이동(도)은 잡기 없음 — 그래도 이전 잡기의 추가 턴이 유지되어야 한다.
  gameState.pendingMoves.splice(0, 1);
  recordCapture(gameState, 0);
  settleTurnAfterMove(gameState, 'A');
  assert.equal(gameState.currentTurn, 'A');
  assert.equal(gameState.phase, 'throwing');
  // 추가 턴은 1회 소비: 플래그가 리셋되어야 한다.
  assert.equal(gameState.caughtOpponentThisTurn, false);
});

test('turn passes to opponent when no capture happened this turn', () => {
  const gameState = {
    playersOrder: ['A', 'B'],
    currentTurn: 'A',
    phase: 'moving',
    pendingMoves: [],
    caughtOpponentThisTurn: false,
  };

  recordCapture(gameState, 0);
  settleTurnAfterMove(gameState, 'A');
  assert.equal(gameState.currentTurn, 'B');
  assert.equal(gameState.phase, 'throwing');
});

test('consumed extra turn does not leak into the next settle', () => {
  const gameState = {
    playersOrder: ['A', 'B'],
    currentTurn: 'A',
    phase: 'moving',
    pendingMoves: [],
    caughtOpponentThisTurn: true,
  };

  settleTurnAfterMove(gameState, 'A');
  assert.equal(gameState.currentTurn, 'A');

  // 추가 턴에서 잡기 없이 이동을 마치면 턴이 넘어가야 한다.
  settleTurnAfterMove(gameState, 'A');
  assert.equal(gameState.currentTurn, 'B');
});

test('checkCatch ignores start; goal piece only safe when finished', () => {
  const opponentPieces = [
    { id: 0, position: 0, finished: false },
    { id: 1, position: 3, finished: false },
    { id: 2, position: 20, finished: true },
    { id: 3, position: 20, finished: false },
  ];

  assert.equal(checkCatch(0, opponentPieces).length, 0, 'start is always safe');
  assert.equal(checkCatch(20, opponentPieces).filter((p) => p.finished).length, 0, 'finished pieces are not caught');
  assert.deepEqual(checkCatch(20, opponentPieces).map((p) => p.id), [3], 'pre-finish piece at pos 20 can be caught');
  assert.deepEqual(checkCatch(3, opponentPieces).map((piece) => piece.id), [1]);
});
