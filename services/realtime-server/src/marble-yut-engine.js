/**
 * Marble Board Game Engine
 *
 * Rules:
 * - 2 players take turns rolling 2 dice
 * - Roll doubles → extra roll this turn (max 3 consecutive doubles)
 * - Board: 20 outer positions + diagonal shortcuts
 * - Win via: bankrupt / shrine monopoly / line monopoly / timeout (20 rounds)
 */

// Board positions used by the mobile board UI:
// 0=start, 1-19=outer route, 20=goal, 21-29=diagonal shortcuts.
export const GOAL_POSITION = 20;

/**
 * Roll 2 dice (each 1-6).
 * Returns { dice1, dice2, total, isDouble }
 */
export function rollDice() {
  const dice1 = Math.floor(Math.random() * 6) + 1;
  const dice2 = Math.floor(Math.random() * 6) + 1;
  return { dice1, dice2, total: dice1 + dice2, isDouble: dice1 === dice2 };
}

/**
 * Move a piece on the visual board.
 * Returns { position, lastPos, finished } or null if move cannot be made.
 */
export function movePiece(piece, steps) {
  if (piece.finished || steps <= 0) return null;

  let position = piece.position;
  let lastPos = piece.lastPos ?? 0;

  for (let i = 0; i < steps; i++) {
    if (position === GOAL_POSITION) {
      return { position: GOAL_POSITION, lastPos: GOAL_POSITION, finished: true };
    }
    const nextPosition = getNextPosition(position, i === 0, lastPos);
    lastPos = position;
    position = nextPosition;
  }

  return { position, lastPos, finished: false };
}

/**
 * Check if a piece catches opponent's pieces at the same position.
 */
export function checkCatch(position, opponentPieces) {
  if (position === 0) return [];
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

export function recordCapture(gameState, capturedCount) {
  if (capturedCount > 0) {
    gameState.caughtOpponentThisTurn = true;
  }
}

/**
 * Decide the next turn after a piece move.
 * Stays on mover when pendingMoves remain, doubles granted, or caught opponent.
 */
export function settleTurnAfterMove(gameState, userId) {
  if (gameState.pendingMoves.length > 0) {
    gameState.phase = "moving";
    return;
  }
  if (gameState.hasDoubleRoll) {
    gameState.hasDoubleRoll = false;
    gameState.caughtOpponentThisTurn = false;
    gameState.currentTurn = userId;
    gameState.phase = "throwing";
    return;
  }
  if (gameState.caughtOpponentThisTurn) {
    gameState.caughtOpponentThisTurn = false;
    gameState.currentTurn = userId;
  } else {
    gameState.currentTurn = getNextPlayer(gameState, userId);
  }
  gameState.phase = "throwing";
}

// ─── 마블 영지 상수 ─────────────────────────────────────────────────────────

export const MARBLE_SALARY = 200;
export const MARBLE_MAX_ROUNDS = 20;
export const MARBLE_START_POSITIONS = new Set([0, 20]);
export const SHRINE_POSITIONS = new Set([5, 10, 15]);

export function getLandValue(pos) {
  if (MARBLE_START_POSITIONS.has(pos)) return 0;
  if (SHRINE_POSITIONS.has(pos)) return 300;
  if (pos === 23) return 200;
  if ([21, 22, 24, 25, 26, 27, 28, 29].includes(pos)) return 150;
  return 100;
}

export const LEVEL_RATE = { 1: 1.0, 2: 1.5, 3: 2.5, 4: 3.5 };
export const UPGRADE_COST_MULT = { 2: 1, 3: 2, 4: 3 };

export function calcToll(pos, level) {
  const base = getLandValue(pos);
  return Math.floor(base * (LEVEL_RATE[level] ?? 1.0));
}

export function calcAcquireCost(pos, stacked = false) {
  const base = getLandValue(pos);
  const cost = Math.floor(base * 1.3);
  return stacked ? Math.floor(cost * 0.5) : cost;
}

export function calcScore(gameState, uid) {
  const coins = gameState.players[uid]?.coins ?? 0;
  let landValue = 0;
  for (const [posStr, land] of Object.entries(gameState.lands)) {
    if (land.owner === uid) {
      const pos = Number(posStr);
      landValue += calcToll(pos, land.level) * 10;
    }
  }
  return coins + landValue;
}

export const LINE_SETS = [
  [5, 6, 7, 8, 9, 10],
  [10, 11, 12, 13, 14, 15],
  [15, 16, 17, 18, 19, 0],
  [0, 1, 2, 3, 4, 5],
];

// ─── 승리 조건 ───────────────────────────────────────────────────────────────

export function checkMarbleWin(gameState) {
  const [p1, p2] = gameState.playersOrder;

  if ((gameState.players[p1]?.coins ?? 0) <= 0) return { winner: p2, reason: 'bankrupt' };
  if ((gameState.players[p2]?.coins ?? 0) <= 0) return { winner: p1, reason: 'bankrupt' };

  for (const uid of [p1, p2]) {
    if ([...SHRINE_POSITIONS].every((pos) => gameState.lands[pos]?.owner === uid)) {
      return { winner: uid, reason: 'shrine' };
    }
  }

  for (const uid of [p1, p2]) {
    for (const line of LINE_SETS) {
      const claimable = line.filter((pos) => !MARBLE_START_POSITIONS.has(pos));
      if (claimable.every((pos) => gameState.lands[pos]?.owner === uid)) {
        return { winner: uid, reason: 'line' };
      }
    }
  }

  return null;
}

export function checkWin(_playerState) {
  return false;
}

export function getNextPlayer(gameState, player) {
  return gameState.playersOrder.find((candidate) => candidate !== player);
}

/**
 * Initialize game state
 */
export function createMarbleYutGameState(player1, player2, options = {}) {
  const createPieces = () => [
    { id: 0, position: 0, lastPos: 0, finished: false },
    { id: 1, position: 0, lastPos: 0, finished: false },
  ];

  return {
    id: `marble-${Date.now()}`,
    playersOrder: [player1, player2],
    players: {
      [player1]: { pieces: createPieces(), coins: 1500 },
      [player2]: { pieces: createPieces(), coins: 1500 },
    },
    lands: {},
    round: 1,
    roundTurns: 0,
    phase: "roll_order",
    currentTurn: null,
    characters: options.characters ?? {},
    bgm: options.bgm ?? null,
    startRolls: {},
    orderCountdownUntil: null,
    pendingMoves: [],
    hasDoubleRoll: false,
    consecutiveDoubles: 0,
    caughtOpponentThisTurn: false,
    catchBonusPending: false,
    catchBonusBy: null,
    catchBonusUntil: null,
    winner: null,
    winReason: null,
    lastRoll: null,
  };
}

export function serializeMarbleYutGame(gameState) {
  return {
    id: gameState.id,
    players: gameState.playersOrder,
    phase: gameState.phase,
    currentTurn: gameState.currentTurn,
    characters: gameState.characters ?? {},
    bgm: gameState.bgm ?? null,
    startRolls: gameState.startRolls ?? {},
    orderCountdownUntil: gameState.orderCountdownUntil ?? null,
    pendingMoves: gameState.pendingMoves,
    hasDoubleRoll: gameState.hasDoubleRoll ?? false,
    consecutiveDoubles: gameState.consecutiveDoubles ?? 0,
    catchBonusPending: gameState.catchBonusPending,
    catchBonusBy: gameState.catchBonusBy ?? null,
    catchBonusUntil: gameState.catchBonusUntil ?? null,
    catchBonusTarget: gameState.catchBonusTarget ?? null,
    lastRoll: gameState.lastRoll ?? null,
    winner: gameState.winner,
    winReason: gameState.winReason ?? null,
    round: gameState.round ?? 1,
    lands: gameState.lands ?? {},
    coins: Object.fromEntries(
      gameState.playersOrder.map((uid) => [uid, gameState.players[uid]?.coins ?? 0]),
    ),
    pieces: Object.fromEntries(
      Object.entries(gameState.players).map(([player, state]) => [player, state.pieces]),
    ),
    equippedItems: gameState.equippedItems ?? {},
  };
}

function getNextPosition(currentPosition, isFirstStep, lastPos = 0) {
  if (currentPosition === GOAL_POSITION) return GOAL_POSITION;

  if (isFirstStep) {
    if (currentPosition === 5) return 21;
    if (currentPosition === 10) return 24;
    if (currentPosition === 23) return 26;
  }

  const nextMap = {
    0: 1, 1: 2, 2: 3, 3: 4, 4: 5,
    5: 6, 6: 7, 7: 8, 8: 9, 9: 10,
    10: 11, 11: 12, 12: 13, 13: 14, 14: 15,
    15: 16, 16: 17, 17: 18, 18: 19, 19: GOAL_POSITION,
    21: 22, 22: 23,
    24: 25, 25: 23,
    23: lastPos === 22 ? 28 : 26,
    26: 27, 27: GOAL_POSITION,
    28: 29, 29: 15,
  };

  return nextMap[currentPosition] ?? GOAL_POSITION;
}
