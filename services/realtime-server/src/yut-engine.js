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
 *
 * yutControlPct: bonus % from equipped yut skin (max 15). After a normal throw,
 * if the result is 3-flat (close to 윷) or 1-flat (close to 모), the pct is used
 * as a threshold to upgrade the result to 윷 or 모 respectively.
 */
export function throwYut({
  yutControlPct = 0,
  yutMoRatePct = 0,
  yutOverturnPct = 0,
  isLosing = false,
} = {}) {
  const sticks = Array.from({ length: 4 }, () => Math.random() < 0.5 ? 0 : 1);
  let flatCount = sticks.filter((s) => s === 0).length;

  // 1. yutControlPct: 걸→윷 or 도→모 upgrade
  const controlPct = yutControlPct + (isLosing ? Math.min(yutOverturnPct, 10) : 0);
  if (controlPct > 0) {
    const threshold = Math.min(controlPct, 20) / 100;
    if (flatCount === 3 && Math.random() < threshold) flatCount = 4; // 걸 → 윷
    else if (flatCount === 1 && Math.random() < threshold) flatCount = 0; // 도 → 모
  }

  // 2. yutMoRatePct: 윷→모 추가 업그레이드 (최대 8%)
  if (yutMoRatePct > 0 && flatCount === 4) {
    if (Math.random() < Math.min(yutMoRatePct, 8) / 100) flatCount = 0; // 윷 → 모
  }

  let result;
  if (flatCount === 0) result = YUT_RESULTS.MO;
  else if (flatCount === 1) result = sticks[0] === 0 ? YUT_RESULTS.BACKDO : YUT_RESULTS.DO;
  else if (flatCount === 2) result = YUT_RESULTS.GAE;
  else if (flatCount === 3) result = YUT_RESULTS.GEOL;
  else result = YUT_RESULTS.YUT;

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
 * opts.backdoDir: for pos 23 with 백도, explicitly choose 22 or 25.
 */
export function movePiece(piece, steps, { backdoDir } = {}) {
  if (piece.finished) {
    return null;
  }

  let position = piece.position;
  let lastPos = piece.lastPos ?? 0;

  if (steps === YUT_RESULTS.BACKDO) {
    if (position === 0) {
      return { position: 0, lastPos };
    }
    return { position: getPrevPosition(position, lastPos, backdoDir), lastPos: position };
  }

  for (let i = 0; i < steps; i += 1) {
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
 * Check if a piece catches opponent's piece
 */
export function checkCatch(position, opponentPieces) {
  if (position === 0) {
    return [];
  }
  return opponentPieces.filter((p) => p.position === position && !p.finished);
}

/**
 * Reset every opponent piece on the landing square. Keeping the mutation at
 * the engine seam makes the server's catch result and persisted board state
 * use the same rule for single pieces and stacked pieces.
 */
export function capturePieces(position, opponentPieces) {
  const capturedPieces = checkCatch(position, opponentPieces);
  for (const piece of capturedPieces) {
    piece.position = 0;
    piece.lastPos = 0;
    piece.finished = false;
  }
  return capturedPieces;
}

/**
 * Resolve a landing against the opponent's pieces.
 *
 * Protected pieces remain on the landing square, while every other eligible
 * piece is reset to start. Keeping both outcomes lets the socket layer persist
 * the authoritative state and explain an apparently missed capture to clients.
 */
export function resolveCapture(
  position,
  opponentPieces,
  { resistPct = 0, safePct = 0, random = Math.random } = {},
) {
  const candidates = checkCatch(position, opponentPieces);
  const blockedPieces = [];
  const capturablePieces = [];
  const resistChance = Math.max(0, Math.min(100, Number(resistPct) || 0));
  const safeChance = Math.max(0, Math.min(100, Number(safePct) || 0));

  for (const piece of candidates) {
    const resisted = resistChance > 0 && random() * 100 < resistChance;
    const safe = safeChance > 0 && random() * 100 < safeChance;
    if (resisted || safe) blockedPieces.push(piece);
    else capturablePieces.push(piece);
  }

  return {
    capturedPieces: capturePieces(position, capturablePieces),
    blockedPieces,
  };
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
 * Apply one resolved move to the selected piece and any pieces already on it.
 * Keeping this at the engine seam prevents callers from dropping `finished`.
 */
export function applyMoveToPieces(carriedPieces, moveResult) {
  for (const piece of carriedPieces) {
    piece.lastPos = moveResult.lastPos;
    piece.position = moveResult.position;
    piece.finished = moveResult.finished === true;
  }
  return carriedPieces;
}

export function hasBackdoMove(playerPieces) {
  return playerPieces.some(
    (piece) => !piece.finished && piece.position !== 0,
  );
}

/**
 * Initialize game state
 */
export function createYutGameState(player1, player2, options = {}) {
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
    characters: options.characters ?? {},
    bgm: options.bgm ?? null,
    startRolls: {},
    orderCountdownUntil: null,
    pendingMoves: [],
    hasBonusThrow: false,
    caughtOpponentThisTurn: false,
    winner: null,
    lastThrow: null,
    // Throws made by the current player before the turn settles. This is
    // intentionally kept separate from lastThrow so 윷/모 bonus throws are
    // visible as one accumulated turn history on both clients.
    turnThrows: [],
  };
}

/**
 * Record a throw without losing the earlier results from the same turn.
 * The socket layer calls this after adding the nak flag to the result.
 */
export function recordYutThrow(gameState, throwResult) {
  gameState.lastThrow = throwResult;
  gameState.turnThrows = [
    ...(Array.isArray(gameState.turnThrows) ? gameState.turnThrows : []),
    throwResult,
  ];
  return gameState.turnThrows;
}

/** Clear the accumulated results when control moves to the other player. */
export function resetYutTurnThrows(gameState) {
  gameState.turnThrows = [];
  return gameState.turnThrows;
}

/**
 * Remember that the mover captured at least one opponent piece this turn.
 * The extra turn is granted once per turn, after every pending move settles.
 */
export function recordCapture(gameState, capturedCount) {
  if (capturedCount > 0) {
    gameState.caughtOpponentThisTurn = true;
  }
}

/**
 * Decide the next turn after a move. Only settles when every pending move
 * has been played; a bonus throw or capture keeps the turn.
 */
export function settleTurnAfterMove(gameState, userId) {
  if (gameState.pendingMoves.length > 0) {
    gameState.phase = "moving";
    return;
  }
  if (gameState.hasBonusThrow) {
    // Consume one bonus throw; caughtOpponentThisTurn is left intact so it
    // grants another throw on the subsequent settleTurnAfterMove call.
    gameState.hasBonusThrow = false;
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

/**
 * Apply the authoritative move portion of a Yut turn.
 *
 * The socket layer is responsible for persistence, rewards, and bonus-item
 * side effects. This function owns the board mutation so carrying and capture
 * cannot diverge between callers or get accidentally omitted from an event.
 */
export function resolveYutMove(
  gameState,
  userId,
  {
    pieceId,
    moveIndex = 0,
    backdoDir,
    moverStats = gameState.playerStats?.[userId] ?? {},
    defenderStats,
    random = Math.random,
  } = {},
) {
  const playerState = gameState.players?.[userId];
  if (!playerState || !Array.isArray(playerState.pieces)) {
    return { ok: false, reason: "not_a_player" };
  }
  if (!Array.isArray(gameState.pendingMoves) || gameState.pendingMoves.length === 0) {
    return { ok: false, reason: "no_pending_moves" };
  }
  if (gameState.currentTurn !== userId) {
    return { ok: false, reason: "not_your_turn" };
  }
  if (!Number.isInteger(moveIndex) || moveIndex < 0 || moveIndex >= gameState.pendingMoves.length) {
    return { ok: false, reason: "invalid_move_index" };
  }

  const piece = playerState.pieces[pieceId];
  if (!piece || piece.finished) {
    return { ok: false, reason: "invalid_piece" };
  }

  const steps = gameState.pendingMoves[moveIndex];
  if (steps === YUT_RESULTS.BACKDO && piece.position === 0) {
    return { ok: false, reason: "invalid_piece_for_move" };
  }

  const preMovePos = piece.position;
  const moveResult = movePiece(piece, steps, { backdoDir });
  if (moveResult === null) {
    return { ok: false, reason: "invalid_move" };
  }

  const opponentId = getNextPlayer(gameState, userId);
  const opponentState = gameState.players?.[opponentId];
  if (!opponentState || !Array.isArray(opponentState.pieces)) {
    return { ok: false, reason: "invalid_game_state" };
  }

  gameState.pendingMoves.splice(moveIndex, 1);
  const carriedPieces = getCarriedPieces(piece, playerState.pieces);
  const stackedPieces = moveResult.position > 0
    ? playerState.pieces.filter(
        (candidate) =>
          candidate.id !== pieceId &&
          !candidate.finished &&
          candidate.position === moveResult.position,
      )
    : [];
  applyMoveToPieces(carriedPieces, moveResult);

  const resolvedDefenderStats = defenderStats ?? gameState.playerStats?.[opponentId] ?? {};
  const captureResult = resolveCapture(
    piece.position,
    opponentState.pieces,
    {
      resistPct: Math.min(resolvedDefenderStats.piece_catch_resist_pct ?? 0, 15),
      safePct: Math.min(resolvedDefenderStats.piece_safe_zone_pct ?? 0, 15),
      random,
    },
  );
  recordCapture(gameState, captureResult.capturedPieces.length);

  return {
    ok: true,
    piece,
    steps,
    preMovePos,
    moveResult,
    carriedPieces,
    stackedPieces,
    capturedPieces: captureResult.capturedPieces,
    captureBlockedPieces: captureResult.blockedPieces,
    opponentId,
    moverStats,
    defenderStats: resolvedDefenderStats,
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
    characters: gameState.characters ?? {},
    bgm: gameState.bgm ?? null,
    startRolls: gameState.startRolls ?? {},
    orderCountdownUntil: gameState.orderCountdownUntil ?? null,
    pendingMoves: gameState.pendingMoves,
    hasBonusThrow: gameState.hasBonusThrow ?? false,
    lastThrow: gameState.lastThrow,
    turnThrows: Array.isArray(gameState.turnThrows) ? gameState.turnThrows : [],
    winner: gameState.winner,
    pieces: Object.fromEntries(
      Object.entries(gameState.players).map(([player, state]) => [
        player,
        state.pieces,
      ]),
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
    23: lastPos === 22 ? 28 : 26,
    26: 27,
    27: GOAL_POSITION,
    28: 29,
    29: 15,
  };

  return nextMap[currentPosition] ?? GOAL_POSITION;
}

function getPrevPosition(currentPosition, lastPos, backdoDir = null) {
  if (currentPosition === GOAL_POSITION) {
    if (backdoDir === 19 || backdoDir === 27) return backdoDir;
    return lastPos === 27 ? 27 : 19;
  }
  if (currentPosition === 23) {
    if (backdoDir === 22 || backdoDir === 25) return backdoDir;
    return lastPos === 25 || lastPos === 24 || lastPos === 10 ? 25 : 22;
  }
  if (currentPosition === 15) {
    if (backdoDir === 14 || backdoDir === 29) return backdoDir;
    return lastPos === 29 ? 29 : 14;
  }

  const prevMap = {
    0: 0,
    // 날빽도: 1칸에서 빽도는 대기(0)가 아니라 도착 칸(20) 대기. 완주는 다음 이동에서.
    1: 20,
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
    28: 23,
    29: 28,
  };

  return prevMap[currentPosition] ?? 0;
}
