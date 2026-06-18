/**
 * Yut (윷놀이) Game State Machine
 * 
 * Rules:
 * - 2 players take turns throwing 4 yut sticks
 * - Results: 도(1), 개(2), 걸(3), 윷(4), 모(5), 백도(-1)
 * - Each player has 4 pieces to move from start to goal
 * - Special squares: catch opponent, shortcut paths
 * - Win: Get all 4 pieces to goal first
 */

export const YUT_RESULTS = {
  DO: 1,
  GAE: 2,
  GEOL: 3,
  YUT: 4,
  MO: 5,
  BACKDO: -1,
};

export const YUT_RESULT_NAMES = {
  1: '도',
  2: '개',
  3: '걸',
  4: '윷',
  5: '모',
  '-1': '백도',
};

// Board positions used by the mobile board UI:
// 0=start, 1-19=outer route, 20=goal, 21-27=diagonal shortcuts.
export const GOAL_POSITION = 20;

/**
 * Throw 4 yut sticks
 * Each stick has 2 sides: flat(0) or round(1)
 * Result mapping:
 * - 0 flat (4 round) -> 모 (5)
 * - 1 marked flat (3 round) -> 백도 (-1)
 * - 1 flat (3 round) -> 도 (1)
 * - 2 flat (2 round) -> 개 (2)
 * - 3 flat (1 round) -> 걸 (3)
 * - 4 flat (0 round) -> 윷 (4)
 */
export function throwYut() {
  const sticks = Array.from({ length: 4 }, () => Math.random() < 0.5 ? 0 : 1);
  const flatCount = sticks.filter((s) => s === 0).length;

  let result;
  if (flatCount === 0) result = YUT_RESULTS.MO;
  else if (flatCount === 1) result = sticks[0] === 0 ? YUT_RESULTS.BACKDO : YUT_RESULTS.DO;
  else if (flatCount === 2) result = YUT_RESULTS.GAE;
  else if (flatCount === 3) result = YUT_RESULTS.GEOL;
  else result = YUT_RESULTS.YUT;

  // 윷 or 모 gets bonus throw
  const bonusThrow = result === YUT_RESULTS.YUT || result === YUT_RESULTS.MO;

  return {
    sticks,
    result,
    resultName: YUT_RESULT_NAMES[result],
    bonusThrow,
  };
}

/**
 * Move a piece on the visual board.
 * Returns `{ position, lastPos }` or null if the move cannot be made.
 */
export function movePiece(piece, steps) {
  if (piece.finished || piece.position === GOAL_POSITION) {
    return null;
  }

  let position = piece.position;
  let lastPos = piece.lastPos ?? 0;

  if (steps === YUT_RESULTS.BACKDO) {
    if (position === 0) {
      return { position: 0, lastPos };
    }
    return { position: getPrevPosition(position, lastPos), lastPos: position };
  }

  for (let i = 0; i < steps; i += 1) {
    if (position === GOAL_POSITION) {
      break;
    }
    const nextPosition = getNextPosition(position, i === 0);
    lastPos = position;
    position = nextPosition;
  }

  return { position, lastPos };
}

/**
 * Check if a piece catches opponent's piece
 */
export function checkCatch(position, opponentPieces) {
  if (position === 0 || position === GOAL_POSITION) {
    return [];
  }
  return opponentPieces.filter((p) => p.position === position && !p.finished);
}

export function getCarriedPieces(selectedPiece, playerPieces) {
  if (selectedPiece.position === 0 || selectedPiece.finished) {
    return [selectedPiece];
  }
  return playerPieces.filter(
    (piece) => !piece.finished && piece.position === selectedPiece.position,
  );
}

/**
 * Initialize game state
 */
export function createYutGameState(player1, player2) {
  const createPieces = () => [
    { id: 0, position: 0, lastPos: 0, finished: false },
    { id: 1, position: 0, lastPos: 0, finished: false },
    { id: 2, position: 0, lastPos: 0, finished: false },
    { id: 3, position: 0, lastPos: 0, finished: false },
  ];

  return {
    id: `yut-${Date.now()}`,
    playersOrder: [player1, player2],
    players: {
      [player1]: {
        pieces: createPieces(),
      },
      [player2]: {
        pieces: createPieces(),
      },
    },
    phase: "roll_order",
    currentTurn: null,
    startRolls: {},
    orderCountdownUntil: null,
    pendingMoves: [],
    winner: null,
    lastThrow: null,
  };
}

/**
 * Check win condition
 */
export function checkWin(playerState) {
  return playerState.pieces.every((p) => p.finished);
}

export function getNextPlayer(gameState, player) {
  return gameState.playersOrder.find((candidate) => candidate !== player);
}

export function serializeYutGame(gameState) {
  return {
    id: gameState.id,
    players: gameState.playersOrder,
    phase: gameState.phase,
    currentTurn: gameState.currentTurn,
    startRolls: gameState.startRolls ?? {},
    orderCountdownUntil: gameState.orderCountdownUntil ?? null,
    pendingMoves: gameState.pendingMoves,
    lastThrow: gameState.lastThrow,
    winner: gameState.winner,
    pieces: Object.fromEntries(
      Object.entries(gameState.players).map(([player, state]) => [
        player,
        state.pieces,
      ]),
    ),
  };
}

function getNextPosition(currentPosition, isFirstStep) {
  if (currentPosition === GOAL_POSITION) return GOAL_POSITION;

  if (isFirstStep) {
    if (currentPosition === 5) return 21;
    if (currentPosition === 10) return 24;
    if (currentPosition === 23) return 26;
  }

  const nextMap = {
    0: 1,
    1: 2,
    2: 3,
    3: 4,
    4: 5,
    5: 6,
    6: 7,
    7: 8,
    8: 9,
    9: 10,
    10: 11,
    11: 12,
    12: 13,
    13: 14,
    14: 15,
    15: 16,
    16: 17,
    17: 18,
    18: 19,
    19: GOAL_POSITION,
    21: 22,
    22: 23,
    24: 25,
    25: 23,
    23: 26,
    26: 27,
    27: GOAL_POSITION,
  };

  return nextMap[currentPosition] ?? GOAL_POSITION;
}

function getPrevPosition(currentPosition, lastPos) {
  if (currentPosition === 23) {
    return lastPos === 25 || lastPos === 24 || lastPos === 10 ? 25 : 22;
  }

  const prevMap = {
    0: 0,
    1: 0,
    2: 1,
    3: 2,
    4: 3,
    5: 4,
    6: 5,
    7: 6,
    8: 7,
    9: 8,
    10: 9,
    11: 10,
    12: 11,
    13: 12,
    14: 13,
    15: 14,
    16: 15,
    17: 16,
    18: 17,
    19: 18,
    20: 20,
    21: 5,
    22: 21,
    24: 10,
    25: 24,
    26: 23,
    27: 26,
  };

  return prevMap[currentPosition] ?? 0;
}
