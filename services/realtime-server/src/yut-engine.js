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

// Simplified board: 20 positions (0=start, 20=goal)
export const BOARD_SIZE = 20;

/**
 * Throw 4 yut sticks
 * Each stick has 2 sides: flat(0) or round(1)
 * Result mapping:
 * - 0 flat (4 round) -> 백도 (-1)
 * - 1 flat (3 round) -> 도 (1)
 * - 2 flat (2 round) -> 개 (2)
 * - 3 flat (1 round) -> 걸 (3)
 * - 4 flat (0 round) -> 윷 (4)
 */
export function throwYut() {
  const sticks = Array.from({ length: 4 }, () => Math.random() < 0.5 ? 0 : 1);
  const flatCount = sticks.filter((s) => s === 0).length;

  let result;
  if (flatCount === 0) result = YUT_RESULTS.BACKDO;
  else if (flatCount === 1) result = YUT_RESULTS.DO;
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
 * Move piece on board
 * Returns new position or null if out of bounds
 */
export function movePiece(currentPosition, steps) {
  const newPosition = currentPosition + steps;
  
  // Backward movement
  if (newPosition < 0) return null;
  
  // Goal reached
  if (newPosition >= BOARD_SIZE) return BOARD_SIZE;
  
  return newPosition;
}

/**
 * Check if a piece catches opponent's piece
 */
export function checkCatch(position, opponentPieces) {
  return opponentPieces.some((p) => p.position === position && !p.captured);
}

/**
 * Initialize game state
 */
export function createYutGameState(player1, player2) {
  return {
    players: {
      [player1]: {
        pieces: [
          { id: 0, position: 0, finished: false },
          { id: 1, position: 0, finished: false },
          { id: 2, position: 0, finished: false },
          { id: 3, position: 0, finished: false },
        ],
      },
      [player2]: {
        pieces: [
          { id: 0, position: 0, finished: false },
          { id: 1, position: 0, finished: false },
          { id: 2, position: 0, finished: false },
          { id: 3, position: 0, finished: false },
        ],
      },
    },
    currentTurn: player1,
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
