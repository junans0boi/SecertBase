import test from 'node:test';
import assert from 'node:assert/strict';
import {
  YUT_RESULTS,
  throwYut,
  movePiece,
  getCarriedPieces,
  applyMoveToPieces,
  hasBackdoMove,
  checkCatch,
  capturePieces,
  resolveCapture,
  resolveYutMove,
  recordCapture,
  createYutGameState,
  recordYutThrow,
  resetYutTurnThrows,
  serializeYutGame,
  settleTurnAfterMove,
  pruneUnusableBackdo,
} from '../src/yut-engine.js';
import * as Yut from '../src/yut-engine.js';

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
    assert.equal(result.resultName, '빽도');
    assert.equal(result.bonusThrow, false);
  });
});

test('turn throw history accumulates bonus throws and resets for the next turn', () => {
  const gameState = createYutGameState('A', 'B');
  const doResult = { result: YUT_RESULTS.DO, resultName: '도', nak: false };
  const yutResult = { result: YUT_RESULTS.YUT, resultName: '윷', nak: false };

  recordYutThrow(gameState, doResult);
  recordYutThrow(gameState, yutResult);

  assert.deepEqual(gameState.turnThrows, [doResult, yutResult]);
  assert.equal(gameState.lastThrow, yutResult);
  assert.deepEqual(serializeYutGame(gameState).turnThrows, [doResult, yutResult]);

  resetYutTurnThrows(gameState);
  assert.deepEqual(gameState.turnThrows, []);
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

test('a 도 after 날백도 finishes the piece and does not leave it at goal', () => {
  const piece = { id: 0, position: 1, lastPos: 0, finished: false };
  const backdo = movePiece(piece, YUT_RESULTS.BACKDO);
  piece.position = backdo.position;
  piece.lastPos = backdo.lastPos;

  const finish = movePiece(piece, YUT_RESULTS.DO);
  applyMoveToPieces([piece], finish);

  assert.deepEqual(piece, {
    id: 0,
    position: 20,
    lastPos: 20,
    finished: true,
  });
});

test('a move only carries pieces already on the selected piece', () => {
  const pieces = [
    { id: 0, position: 1, finished: false },
    { id: 1, position: 0, finished: false },
    { id: 2, position: 3, finished: false },
  ];

  assert.deepEqual(getCarriedPieces(pieces[0], pieces).map((piece) => piece.id), [0]);
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

test('a landing move resets every opponent piece on the landing square', () => {
  const mover = { id: 0, position: 2, lastPos: 1, finished: false };
  const opponentPieces = [
    { id: 0, position: 3, lastPos: 2, finished: false },
    { id: 1, position: 3, lastPos: 2, finished: false },
    { id: 2, position: 3, lastPos: 2, finished: true },
  ];
  const moveResult = movePiece(mover, YUT_RESULTS.DO);
  applyMoveToPieces([mover], moveResult);
  const captured = capturePieces(mover.position, opponentPieces);

  assert.deepEqual(captured.map((piece) => piece.id), [0, 1]);
  assert.deepEqual(opponentPieces, [
    { id: 0, position: 0, lastPos: 0, finished: false },
    { id: 1, position: 0, lastPos: 0, finished: false },
    { id: 2, position: 3, lastPos: 2, finished: true },
  ]);
});

test('resolveCapture rolls defense once for the whole stack and caps it (≤10%)', () => {
  const opponentPieces = [
    { id: 0, position: 3, lastPos: 2, finished: false },
    { id: 1, position: 3, lastPos: 2, finished: false },
  ];
  const rolls = [];
  // 100%를 달라고 해도 상한(9%)까지만: 0.08 막힘, 0.10 잡힘.
  const blocked = resolveCapture(3, opponentPieces, { resistPct: 100, safePct: 100, random: () => { rolls.push(0.08); return 0.08; } });
  assert.equal(rolls.length, 1, 'one roll, not one per piece or per item');
  assert.deepEqual(blocked.capturedPieces, []);
  assert.deepEqual(blocked.blockedPieces.map((piece) => piece.id), [0, 1]);
  assert.deepEqual(opponentPieces.map((piece) => piece.position), [3, 3]);
  const caught = resolveCapture(3, opponentPieces, { resistPct: 100, safePct: 100, random: () => 0.1 });
  assert.deepEqual(caught.capturedPieces.map((piece) => piece.id), [0, 1]);
});

test('resolveYutMove applies carried movement and capture to the game state', () => {
  const gameState = {
    playersOrder: ['A', 'B'],
    currentTurn: 'A',
    phase: 'moving',
    pendingMoves: [1],
    caughtOpponentThisTurn: false,
    players: {
      A: {
        pieces: [
          { id: 0, position: 2, lastPos: 1, finished: false },
          { id: 1, position: 2, lastPos: 1, finished: false },
        ],
      },
      B: {
        pieces: [
          { id: 0, position: 3, lastPos: 2, finished: false },
          { id: 1, position: 3, lastPos: 2, finished: false },
        ],
      },
    },
  };

  const result = resolveYutMove(gameState, 'A', { pieceId: 0 });

  assert.equal(result.ok, true);
  assert.deepEqual(result.carriedPieces.map((piece) => piece.id), [0, 1]);
  assert.deepEqual(result.capturedPieces.map((piece) => piece.id), [0, 1]);
  assert.deepEqual(gameState.players.A.pieces.map((piece) => piece.position), [3, 3]);
  assert.deepEqual(gameState.players.B.pieces.map((piece) => piece.position), [0, 0]);
  assert.equal(gameState.pendingMoves.length, 0);
  assert.equal(gameState.caughtOpponentThisTurn, true);
});

test('catch bonus and yut/mo bonus are independent: both extra throws are granted', () => {
  // 조작 순서와 무관하게 잡기 1회 = 추가 던지기 1회 (#190)
  const gameState = {
    playersOrder: ['A', 'B'],
    currentTurn: 'A',
    phase: 'moving',
    pendingMoves: [],
    hasBonusThrow: true,
    captureBonusThrows: 1,
    caughtOpponentThisTurn: true,
  };

  settleTurnAfterMove(gameState, 'A'); // 윷/모 보너스 사용
  assert.equal(gameState.currentTurn, 'A');
  settleTurnAfterMove(gameState, 'A'); // 잡기 보너스 사용
  assert.equal(gameState.currentTurn, 'A');
  assert.equal(gameState.caughtOpponentThisTurn, false);
  settleTurnAfterMove(gameState, 'A'); // 더 없음
  assert.equal(gameState.currentTurn, 'B');
});

test('two separate captures grant two extra throws', () => {
  const gameState = { playersOrder: ['A', 'B'], currentTurn: 'A', phase: 'moving', pendingMoves: [] };
  recordCapture(gameState, 1);
  recordCapture(gameState, 2);
  assert.equal(gameState.captureBonusThrows, 2);
  settleTurnAfterMove(gameState, 'A');
  settleTurnAfterMove(gameState, 'A');
  assert.equal(gameState.currentTurn, 'A');
  settleTurnAfterMove(gameState, 'A');
  assert.equal(gameState.currentTurn, 'B');
});

test('pruneUnusableBackdo discards backdo when no piece is on the board (soft-lock fix)', () => {
  const gameState = {
    pendingMoves: [-1],
    players: { A: { pieces: [
      { id: 0, position: 0, lastPos: 0, finished: false },
      { id: 1, position: 20, lastPos: 20, finished: true },
    ] } },
  };
  assert.equal(pruneUnusableBackdo(gameState, 'A'), 1);
  assert.deepEqual(gameState.pendingMoves, []);
});

test('pruneUnusableBackdo keeps backdo while another move could bring a piece out', () => {
  const gameState = {
    pendingMoves: [4, -1],
    players: { A: { pieces: [{ id: 0, position: 0, lastPos: 0, finished: false }] } },
  };
  assert.equal(pruneUnusableBackdo(gameState, 'A'), 0);
  assert.deepEqual(gameState.pendingMoves, [4, -1]);
});

test('a finishing piece does not capture an opponent waiting on the goal corner', () => {
  const gameState = {
    playersOrder: ['A', 'B'],
    currentTurn: 'A',
    phase: 'moving',
    pendingMoves: [5],
    players: {
      A: { pieces: [{ id: 0, position: 18, lastPos: 17, finished: false }] },
      B: { pieces: [{ id: 0, position: 20, lastPos: 1, finished: false }] },
    },
  };
  const result = resolveYutMove(gameState, 'A', { pieceId: 0 });
  assert.equal(result.ok, true);
  assert.equal(gameState.players.A.pieces[0].finished, true);
  assert.equal(result.capturedPieces.length, 0);
  assert.equal(gameState.players.B.pieces[0].position, 20);
});

// ── 2.0(티켓 21): 아이템 상한·빽도·방어·이동 후보·자동 이동 ─────────────────────

const seeded = (seed) => () => {
  // mulberry32: 테스트가 언제나 같은 수열을 쓰게 한다.
  seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const queue = (values) => { let i = 0; return () => values[i++] ?? 0.99; };
const MAX_ITEMS = {
  yut_control_pct: 15, yut_mo_rate_pct: 8, yut_overturn_pct: 10, yut_backdo_bonus_pct: 25, yut_backdo_shield_pct: 25,
  piece_catch_resist_pct: 15, piece_safe_zone_pct: 15,
  yut_win_coin_pct: 15, piece_catch_coin_bonus: 25, yut_catch_bonus: 300,
};

function game({ a = [], b = [], pending = [], turn = 'A', count = 4, stake = 0, effects } = {}) {
  const g = Yut.createYutGameState('A', 'B', { pieces: count, starter: turn });
  a.forEach((pos, i) => Object.assign(g.players.A.pieces[i], typeof pos === 'object' ? pos : { position: pos, lastPos: Math.max(0, pos - 1) }));
  b.forEach((pos, i) => Object.assign(g.players.B.pieces[i], typeof pos === 'object' ? pos : { position: pos, lastPos: Math.max(0, pos - 1) }));
  g.pendingMoves = pending;
  g.phase = pending.length ? 'moving' : 'throwing';
  g.stake = stake;
  g.effects = effects ?? { A: Yut.yutItemEffects({}), B: Yut.yutItemEffects({}) };
  return g;
}

test('빽도 is never upgraded to 모, even at maximum control', () => {
  // 표시 막대(0번)만 납작 = 빽도. 컨트롤 판정 난수는 0이라 도였다면 무조건 모가 된다.
  const r = throwYut({ yutControlPct: 15, yutOverturnPct: 10, isLosing: true, random: queue([0.1, 0.9, 0.9, 0.9, 0]) });
  assert.equal(r.result, YUT_RESULTS.BACKDO);
  assert.deepEqual(r.sticks, [0, 1, 1, 1]);
  const doThrow = throwYut({ yutControlPct: 15, random: queue([0.9, 0.1, 0.9, 0.9, 0]) });
  assert.equal(doThrow.result, YUT_RESULTS.MO, 'a real 도 can still be upgraded');
  assert.deepEqual(doThrow.sticks, [1, 1, 1, 1], 'sticks are redrawn to match the upgraded result');
  const geol = throwYut({ yutControlPct: 15, random: queue([0.1, 0.1, 0.1, 0.9, 0]) });
  assert.equal(geol.result, YUT_RESULTS.YUT);
  assert.deepEqual(geol.sticks, [0, 0, 0, 0]);
});

test('sticks always match the result over many boosted throws', () => {
  const random = seeded(7);
  const fx = Yut.yutItemEffects(MAX_ITEMS);
  for (let i = 0; i < 50_000; i++) {
    const r = throwYut({ yutControlPct: fx.controlPct, yutMoRatePct: fx.moRatePct, yutOverturnPct: fx.overturnPct, isLosing: i % 2 === 0, random });
    assert.equal(Yut.resultFromSticks(r.sticks), r.result);
    assert.equal(r.resultName, Yut.YUT_RESULT_NAMES[r.result]);
  }
  // 원시 값을 그대로 넘겨도 같은 상한이 다시 적용된다.
  const raw = throwYut({ yutControlPct: 100, yutMoRatePct: 100, random: queue([0.1, 0.1, 0.1, 0.9, 0.05]) });
  assert.equal(raw.result, YUT_RESULTS.GEOL, '5% roll is above the capped control chance');
});

test('throw-raising effects are summed under one cap; every other effect has its own cap', () => {
  const fx = Yut.yutItemEffects(MAX_ITEMS);
  const throwSum = fx.controlPct + fx.moRatePct + fx.overturnPct;
  assert.ok(throwSum <= Yut.THROW_ITEM_CAP_PCT + 1e-9, `sum ${throwSum}`);
  assert.ok(fx.controlPct > fx.moRatePct, 'shares keep their proportions');
  assert.equal(fx.defensePct, Yut.DEFENSE_CAP_PCT);
  assert.equal(fx.backdoBonusPct, Yut.BACKDO_BONUS_CAP_PCT);
  assert.equal(fx.calmPct, Yut.CALM_CAP_PCT);
  const small = Yut.yutItemEffects({ yut_control_pct: 1, piece_safe_zone_pct: 3 });
  assert.equal(small.controlPct, 1, 'small loadouts are untouched');
  assert.equal(small.defensePct, 3);
  assert.deepEqual(Yut.yutItemEffects({ yut_control_pct: 'x', yut_mo_rate_pct: -5 }).controlPct, 0);
});

test('a blocked capture stops the mover one square short, never on the same square', () => {
  const g = game({ a: [2], b: [5], pending: [3], effects: { A: Yut.yutItemEffects({}), B: Yut.yutItemEffects(MAX_ITEMS) } });
  const r = Yut.applyMove(g, 'A', { pieceId: 0, random: () => 0.05 });
  assert.equal(r.ok, true);
  assert.deepEqual(g.players.A.pieces[0], { id: 0, position: 4, lastPos: 3, finished: false });
  assert.equal(g.players.B.pieces[0].position, 5, 'defender survives');
  assert.deepEqual(g.lastAction.move.blocked, [0]);
  assert.equal(g.lastAction.move.blockedAt, 5);
  assert.deepEqual(g.lastAction.move.path, [2, 3, 4]);
  assert.deepEqual(r.itemEffects, [{ player: 'B', stat: 'yut_capture_protection', amount: 1 }]);
  assert.equal(g.captureBonusThrows, 0, 'no capture, no extra throw');
  assert.equal(g.currentTurn, 'B');
});

test('a block keeps the shortcut direction of the square it stops on', () => {
  // 모(5)에서 걸: 21→22→방(23). 방의 상대가 막으면 22에 서고, 다음 이동은 그대로 대각선.
  const g = game({ a: [{ position: 5, lastPos: 4 }], b: [23], pending: [3, 1], effects: { A: Yut.yutItemEffects({}), B: { ...Yut.yutItemEffects({}), defensePct: 10 } } });
  Yut.applyMove(g, 'A', { pieceId: 0, moveIndex: 0, random: () => 0 });
  assert.deepEqual(g.players.A.pieces[0], { id: 0, position: 22, lastPos: 21, finished: false });
  assert.equal(Yut.movePiece(g.players.A.pieces[0], 2).position, 28, 'continues 23 → 28 towards 찌모');
});

test('defense fails (normal capture) when the square before is also taken or is the start', () => {
  const both = game({ a: [2], b: [5, 4], pending: [3], effects: { A: Yut.yutItemEffects({}), B: { ...Yut.yutItemEffects({}), defensePct: 10 } } });
  Yut.applyMove(both, 'A', { pieceId: 0, random: () => 0 });
  assert.equal(both.players.A.pieces[0].position, 5);
  assert.equal(both.players.B.pieces[0].position, 0, 'captured on the landing square');
  assert.equal(both.players.B.pieces[1].position, 4);

  const fromStart = game({ a: [0], b: [1], pending: [1], effects: { A: Yut.yutItemEffects({}), B: { ...Yut.yutItemEffects({}), defensePct: 10 } } });
  Yut.applyMove(fromStart, 'A', { pieceId: 0, random: () => 0 });
  assert.equal(fromStart.players.A.pieces[0].position, 1);
  assert.equal(fromStart.players.B.pieces[0].position, 0);
});

test('a blocked one-step move leaves the piece where it was', () => {
  const g = game({ a: [{ position: 7, lastPos: 6 }], b: [6], pending: [-1], effects: { A: Yut.yutItemEffects({}), B: { ...Yut.yutItemEffects({}), defensePct: 10 } } });
  Yut.applyMove(g, 'A', { pieceId: 0, random: () => 0 });
  assert.deepEqual(g.players.A.pieces[0], { id: 0, position: 7, lastPos: 6, finished: false });
});

test('defense rolls once per landing and only when there is something to catch', () => {
  let calls = 0;
  const random = () => { calls += 1; return 0.5; };
  const g = game({ a: [2], b: [6, 6], pending: [3, 1], effects: { A: Yut.yutItemEffects({}), B: { ...Yut.yutItemEffects({}), defensePct: 10 } } });
  Yut.applyMove(g, 'A', { pieceId: 0, moveIndex: 1, random });
  assert.equal(calls, 0, 'empty landing square: no roll');
  Yut.applyMove(g, 'A', { pieceId: 0, moveIndex: 0, random });
  assert.equal(calls, 1);
  assert.deepEqual(g.players.B.pieces.map((p) => p.position), [0, 0, 0, 0]);
});

test('coin bonuses accrue only up to 30% of the stake per game, and never in free games', () => {
  const fx = Yut.yutItemEffects(MAX_ITEMS);
  const g = game({ a: [3], b: [5, 6, 7, 8], pending: [2], stake: 1000, effects: { A: fx, B: Yut.yutItemEffects({}) } });
  assert.equal(Yut.coinBonusCap(1000), 300);
  const r = Yut.applyMove(g, 'A', { pieceId: 0, random: () => 0.99 });
  // 잡은 말 1개 × 25 + 잡기 300 → 상한 300에서 멈춘다.
  assert.deepEqual(r.itemEffects, [
    { player: 'A', stat: 'piece_catch_coin_bonus', amount: 25 },
    { player: 'A', stat: 'yut_catch_bonus', amount: 275 },
  ]);
  assert.equal(g.coinBonus.A, 300);
  assert.equal(Yut.accrueCoinBonus(g, 'A', 150), 0, 'cap reached');
  const free = game({ stake: 0, effects: { A: fx, B: fx } });
  assert.equal(Yut.accrueCoinBonus(free, 'A', 150), 0);
  // 윷·모 보너스(판돈 15%)도 같은 상한.
  const y = game({ stake: 1000, effects: { A: fx, B: fx } });
  for (let i = 0; i < 4; i++) {
    y.phase = 'throwing'; y.pendingMoves = []; y.currentTurn = 'A';
    Yut.applyThrow(y, 'A', { random: queue([0.1, 0.1, 0.1, 0.1, 0.99, 0.99]) });
  }
  assert.equal(y.coinBonus.A, 300);
});

test('applyThrow: 낙 passes the turn; no second throw while moves are pending', () => {
  const g = game({ a: [0, 0, 0, 0] });
  const nak = Yut.applyThrow(g, 'A', { random: queue([0.1, 0.9, 0.9, 0.9]) });
  assert.equal(nak.nak, true);
  assert.equal(g.currentTurn, 'B');
  assert.deepEqual(g.turnThrows, [], 'turn history resets for the next player');
  assert.equal(g.lastAction.throw.nak, true);
  const h = game({ a: [3] });
  Yut.applyThrow(h, 'A', { random: queue([0.1, 0.1, 0.9, 0.9]) });
  assert.deepEqual(h.pendingMoves, [2]);
  assert.equal(Yut.applyThrow(h, 'A', {}).reason, 'must_move_first');
  assert.equal(Yut.applyThrow(h, 'B', {}).reason, 'not_your_turn');
  const bonus = game({ a: [3] });
  Yut.applyThrow(bonus, 'A', { random: queue([0.9, 0.9, 0.9, 0.9]) });
  assert.equal(bonus.hasBonusThrow, true);
  assert.equal(Yut.applyThrow(bonus, 'A', { random: queue([0.1, 0.1, 0.9, 0.9]) }).ok, true, '모 lets you throw again before moving');
  assert.deepEqual(bonus.pendingMoves, [5, 2]);
  assert.deepEqual(bonus.turnThrows.map((t) => t.resultName), ['모', '개']);
});

test('legalMoves: one waiting piece, stacks as one, both arrows at a backdo fork', () => {
  const g = game({ a: [0, 0, { position: 23, lastPos: 22 }, { position: 23, lastPos: 22 }], b: [3], pending: [3, -1] });
  const moves = Yut.legalMoves(g, 'A');
  const forward = moves.filter((m) => m.moveIndex === 0);
  assert.deepEqual(forward.map((m) => [m.pieceId, m.pieceIds, m.to]), [[0, [0], 3], [2, [2, 3], 20]]);
  assert.equal(forward[0].captures, 1);
  assert.deepEqual(forward[0].path, [0, 1, 2, 3]);
  const back = moves.filter((m) => m.moveIndex === 1);
  assert.deepEqual(back.map((m) => [m.pieceId, m.backdoDir, m.to]), [[2, 22, 22], [2, 25, 25]], 'no backdo for waiting pieces');
  assert.deepEqual(Yut.legalMoves(g, 'B'), [], 'only the current player gets moves');
  const fin = game({ a: [{ position: 19, lastPos: 18 }], pending: [2] });
  assert.deepEqual(Yut.legalMoves(fin, 'A').map((m) => [m.finish, m.to, m.path]), [[true, 20, [19, 20]], [false, 2, [0, 1, 2]]]);
});

test('a backdo fork move honours the chosen direction', () => {
  const g = game({ a: [{ position: 23, lastPos: 22 }], pending: [-1] });
  Yut.applyMove(g, 'A', { pieceId: 0, backdoDir: 25 });
  assert.deepEqual(g.players.A.pieces[0], { id: 0, position: 25, lastPos: 23, finished: false });
  const h = game({ a: [{ position: 23, lastPos: 22 }], pending: [-1] });
  Yut.applyMove(h, 'A', { pieceId: 0, backdoDir: 99 });
  assert.equal(h.players.A.pieces[0].position, 22, 'an invalid direction falls back to the way it came');
});

test('autoMove picks capture > goal > the most advanced piece', () => {
  const capture = game({ a: [{ position: 18, lastPos: 17 }, 2], b: [4], pending: [2] });
  assert.equal(Yut.autoMove(capture, 'A').pieceId, 1);
  const goal = game({ a: [{ position: 19, lastPos: 18 }, 2], pending: [2] });
  assert.equal(Yut.autoMove(goal, 'A').finish, true);
  const lead = game({ a: [3, { position: 12, lastPos: 11 }, 0], pending: [1] });
  assert.equal(Yut.autoMove(lead, 'A').pieceId, 1);
  const noBackdo = game({ a: [{ position: 12, lastPos: 11 }], pending: [-1, 2] });
  const pick = Yut.autoMove(noBackdo, 'A');
  assert.equal(pick.steps, 2, 'a forward move before a backdo');
  assert.equal(Yut.autoMove(game({ a: [3] }), 'A'), null, 'nothing pending');
});

test('piece count option creates 3 or 2 pieces and wins when they all finish', () => {
  for (const n of [3, 2]) {
    const g = Yut.createYutGameState('A', 'B', { pieces: n, starter: 'B' });
    assert.equal(g.players.A.pieces.length, n);
    assert.equal(g.currentTurn, 'B');
    assert.equal(Yut.serializeYutState(g).pieceCount, n);
  }
  assert.equal(Yut.createYutGameState('A', 'B', { pieces: 7 }).players.A.pieces.length, 4);
  const g = game({ count: 2, a: [{ position: 20, lastPos: 19, finished: true }, { position: 19, lastPos: 18 }], pending: [2] });
  const r = Yut.applyMove(g, 'A', { pieceId: 1 });
  assert.equal(r.won, true);
  assert.equal(g.winner, 'A');
  assert.equal(Yut.applyThrow(g, 'B', {}).reason, 'game_over');
  assert.equal(Yut.applyMove(g, 'A', { pieceId: 0 }).reason, 'game_over');
});

test('serializeYutState exposes legal moves for the current player and the deadline', () => {
  const g = game({ a: [0], pending: [1] });
  g.turnDeadline = 123; g.turnMs = 30_000;
  const view = Yut.serializeYutState(g, { now: 100 });
  assert.equal(view.legalMoves.length, 1);
  assert.equal(view.canThrow, false);
  assert.equal(view.serverNow, 100);
  assert.equal(view.turnDeadline, 123);
  assert.deepEqual(view.players, ['A', 'B']);
});

test('serializeYutState exposes the capped, effective item effects of both players', () => {
  const g = game({ effects: { A: Yut.yutItemEffects(MAX_ITEMS), B: Yut.yutItemEffects({ yut_control_pct: 1 }) } });
  const view = Yut.serializeYutState(g);
  const sum = (e) => e.controlPct + e.moRatePct + e.overturnPct;
  assert.ok(sum(view.effects.A) <= Yut.THROW_ITEM_CAP_PCT + 1e-9, 'shown numbers are the capped ones, not the raw item stats');
  assert.equal(view.effects.A.defensePct, Yut.DEFENSE_CAP_PCT);
  assert.equal(view.effects.B.controlPct, 1);
  assert.equal(view.effects.B.defensePct, 0);
});

// ── 캐릭터 능력치(티켓 27) ────────────────────────────────────────────────────

test('each character has five 1–5 stats with the same total, and a distinct identity', () => {
  const ids = Object.keys(Yut.YUT_CHARACTER_STATS);
  assert.deepEqual(ids.sort(), ['honggilldong', 'miho', 'nolbu']);
  const keys = new Set();
  for (const id of ids) {
    const stats = Yut.YUT_CHARACTER_STATS[id];
    assert.deepEqual(Object.keys(stats).sort(), [...Yut.YUT_STAT_KEYS].sort());
    for (const v of Object.values(stats)) assert.ok(Number.isInteger(v) && v >= 1 && v <= 5, `${id} ${v}`);
    assert.equal(Object.values(stats).reduce((a, b) => a + b, 0), 15, `${id} total keeps characters fair`);
    keys.add(JSON.stringify(stats));
  }
  assert.equal(keys.size, 3, 'no two characters share the same stat line');
  // 정체성: 놀부는 힘, 미호는 행운, 홍길동은 침착·방어가 가장 높다.
  const best = (k) => ids.reduce((a, b) => (Yut.YUT_CHARACTER_STATS[b][k] > Yut.YUT_CHARACTER_STATS[a][k] ? b : a));
  assert.equal(best('power'), 'nolbu');
  assert.equal(best('luck'), 'miho');
  assert.equal(best('calm'), 'honggilldong');
  assert.equal(best('guard'), 'honggilldong');
  assert.deepEqual(Yut.yutCharacterStats('nobody'), { power: 3, calm: 3, guard: 3, luck: 3, momentum: 3 });
});

test('stat levels become effects: level 1 gives nothing, level 5 the maximum', () => {
  const none = Yut.characterEffects('nolbu'); // 침착 1
  assert.equal(none.calmPct, 0);
  const hong = Yut.characterEffects('honggilldong');
  assert.equal(hong.calmPct, 12);
  assert.equal(hong.defensePct, 4.5);
  const miho = Yut.characterEffects('miho'); // 행운 5
  assert.equal(miho.backdoBonusPct, 8);
  assert.equal(miho.winCoinPct, 4);
  const nolbu = Yut.characterEffects('nolbu'); // 힘 5
  assert.ok(nolbu.controlPct > hong.controlPct);
});

test('character stats and skin effects share the caps', () => {
  const nolbuWithBolt = Yut.yutItemEffects({ yut_control_pct: 15, yut_overturn_pct: 10 }, 'nolbu');
  assert.ok(nolbuWithBolt.controlPct + nolbuWithBolt.overturnPct + nolbuWithBolt.moRatePct <= Yut.THROW_ITEM_CAP_PCT + 1e-9);
  const honggil = Yut.yutItemEffects({ piece_catch_resist_pct: 15 }, 'honggilldong');
  assert.equal(honggil.defensePct, Yut.DEFENSE_CAP_PCT);
  assert.equal(Yut.yutItemEffects({ yut_backdo_shield_pct: 25 }, 'honggilldong').calmPct, Yut.CALM_CAP_PCT);
  // 판돈이 없으면 코인 효과는 그냥 쌓이지 않는다(상한 0).
  const g = game({ stake: 0, effects: { A: Yut.yutItemEffects({}, 'miho'), B: Yut.yutItemEffects({}, 'nolbu') } });
  Yut.applyThrow(g, 'A', { random: queue([0.1, 0.1, 0.1, 0.1, 0.99, 0.99]) });
  assert.equal(g.coinBonus.A ?? 0, 0);
});

test('침착: a backdo is thrown again with the character calm chance; sticks match the new result', () => {
  const calm = { ...Yut.yutItemEffects({}), calmPct: 15 };
  const g = game({ a: [3], effects: { A: calm, B: Yut.yutItemEffects({}) } });
  // 첫 던지기: 빽도(표시 막대만 납작) → 침착 굴림 통과(0.1<15%) → 다시 던져 개(막대 0·2번 납작은 아님: 2개 납작).
  const r = Yut.applyThrow(g, 'A', { random: queue([0.1, 0.9, 0.9, 0.9, /*calm*/ 0.001, 0.1, 0.1, 0.9, 0.9]) });
  assert.equal(r.ok, true);
  assert.equal(r.throwResult.resultName, '개');
  assert.equal(Yut.resultFromSticks(r.throwResult.sticks), r.throwResult.result);
  assert.deepEqual(r.itemEffects, [{ player: 'A', stat: 'yut_backdo_shield_pct', amount: 0 }]);
  // 침착 굴림에 실패하면 빽도 그대로.
  const h = game({ a: [3], effects: { A: calm, B: Yut.yutItemEffects({}) } });
  const r2 = Yut.applyThrow(h, 'A', { random: queue([0.1, 0.9, 0.9, 0.9, 0.9]) });
  assert.equal(r2.throwResult.resultName, '빽도');
  assert.deepEqual(r2.itemEffects, []);
  // 침착이 없으면 굴리지 않는다.
  const k = game({ a: [3] });
  assert.equal(Yut.applyThrow(k, 'A', { random: queue([0.1, 0.9, 0.9, 0.9]) }).throwResult.resultName, '빽도');
});

test('state payload carries both characters stat lines', () => {
  const g = game({});
  g.characters = { A: 'miho', B: 'nolbu' };
  const view = Yut.serializeYutState(g);
  assert.deepEqual(view.characterStats.A, Yut.YUT_CHARACTER_STATS.miho);
  assert.deepEqual(view.characterStats.B, Yut.YUT_CHARACTER_STATS.nolbu);
  assert.notDeepEqual(view.characterStats.A, view.characterStats.B);
});
