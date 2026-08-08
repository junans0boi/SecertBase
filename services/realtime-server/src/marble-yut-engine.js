/**
 * Marble Board Game Engine
 *
 * Rules:
 * - 2 players take turns rolling 2 dice
 * - Roll doubles → extra roll this turn (max 3 consecutive doubles)
 * - Board: 32 perimeter positions (0 = START, clockwise loop)
 * - Passing pos 0 → collect MARBLE_SALARY
 * - Win via: bankrupt / color monopoly / round limit
 */

export const BOARD_SIZE = 32;

// pos 0 = 출발 — 착지해도 점령 프롬프트 없음
export const MARBLE_START_POSITIONS = new Set([0]);

export function rollDice() {
  const dice1 = Math.floor(Math.random() * 6) + 1;
  const dice2 = Math.floor(Math.random() * 6) + 1;
  return { dice1, dice2, total: dice1 + dice2, isDouble: dice1 === dice2 };
}

/**
 * Move a piece around the 32-tile loop.
 * Returns { position, passedStart } — pieces never "finish."
 */
export function movePiece(piece, steps) {
  if (steps <= 0) return null;

  let position = piece.position;
  let passedStart = false;

  for (let i = 0; i < steps; i++) {
    const next = (position + 1) % BOARD_SIZE;
    if (next === 0 && position !== 0) passedStart = true;
    position = next;
  }

  return { position, lastPos: piece.position, passedStart, finished: false };
}

export function checkCatch(position, opponentPieces) {
  if (position === 0) return [];
  return opponentPieces.filter((p) => p.position === position && !p.finished);
}

export function getCarriedPieces(selectedPiece, playerPieces) {
  if (selectedPiece.position === 0) return [selectedPiece];
  return playerPieces.filter(
    (piece) => !piece.finished && piece.position === selectedPiece.position,
  );
}

export function recordCapture(gameState, capturedCount) {
  if (capturedCount > 0) gameState.caughtOpponentThisTurn = true;
}

export function settleTurnAfterMove(gameState, userId) {
  if (gameState.pendingMoves.length > 0) {
    gameState.phase = 'moving';
    return;
  }
  if (gameState.hasDoubleRoll) {
    gameState.hasDoubleRoll = false;
    gameState.caughtOpponentThisTurn = false;
    gameState.currentTurn = userId;
    gameState.phase = 'throwing';
    return;
  }
  if (gameState.caughtOpponentThisTurn) {
    gameState.caughtOpponentThisTurn = false;
    gameState.currentTurn = userId;
  } else {
    gameState.currentTurn = getNextPlayer(gameState, userId);
  }
  gameState.phase = 'throwing';
}

// ─── 보드 상수 ──────────────────────────────────────────────────────────────

export const MARBLE_SALARY       = 200;    // 출발 통과 시 급여
export const MARBLE_MAX_ROUNDS   = 30;
export const MARBLE_START_COINS  = 2000;

// 색상 그룹별 부동산 위치
export const COLOR_GROUPS = {
  pink:   [1,  2,  4,  6,  7],   // bottom side
  orange: [9,  10, 12, 14, 15],  // right side
  purple: [17, 18, 20, 22, 23],  // top side
  green:  [25, 26, 28, 30, 31],  // left side
};

// 부동산 기본값 (land value) — price 데이터와 일치
const LAND_VALUES = {
  1: 100, 2: 120, 4: 160, 6: 200, 7: 240,
  9: 300, 10: 350, 12: 400, 14: 450, 15: 500,
  17: 600, 18: 650, 20: 700, 22: 800, 23: 900,
  25: 600, 26: 650, 28: 700, 30: 800, 31: 900,
};

export function getLandValue(pos) {
  return LAND_VALUES[pos] ?? 0;
}

// 통행료: base × level multiplier
export const LEVEL_RATE = { 1: 0.5, 2: 1.0, 3: 1.7, 4: 2.5 };

// 업그레이드 비용: base × multiplier
export const UPGRADE_COST_MULT = { 2: 1.0, 3: 1.8, 4: 2.8 };

export function calcToll(pos, level) {
  const base = getLandValue(pos);
  return Math.round(base * (LEVEL_RATE[level] ?? 0.5));
}

export function calcAcquireCost(pos, stacked = false) {
  const base = getLandValue(pos);
  const cost = Math.round(base * 1.3);
  return stacked ? Math.round(cost * 0.5) : cost;
}

export function calcUpgradeCost(pos, targetLevel) {
  const base = getLandValue(pos);
  return Math.round(base * (UPGRADE_COST_MULT[targetLevel] ?? 1.0));
}

export function calcScore(gameState, uid) {
  const coins = gameState.players[uid]?.coins ?? 0;
  let landValue = 0;
  for (const [posStr, land] of Object.entries(gameState.lands)) {
    if (land.owner === uid) {
      const pos = Number(posStr);
      landValue += getLandValue(pos) * (land.level ?? 1) * 8;
    }
  }
  return coins + landValue;
}

// ─── 승리 조건 ───────────────────────────────────────────────────────────────

export function checkMarbleWin(gameState) {
  const [p1, p2] = gameState.playersOrder;

  // 파산
  if ((gameState.players[p1]?.coins ?? 0) <= 0) return { winner: p2, reason: 'bankrupt' };
  if ((gameState.players[p2]?.coins ?? 0) <= 0) return { winner: p1, reason: 'bankrupt' };

  // 색상 독점 (한 색 5개 모두 소유)
  for (const uid of [p1, p2]) {
    for (const [, group] of Object.entries(COLOR_GROUPS)) {
      if (group.every((pos) => gameState.lands[pos]?.owner === uid)) {
        return { winner: uid, reason: 'monopoly' };
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

// ─── 게임 상태 초기화 ────────────────────────────────────────────────────────

export function createMarbleYutGameState(player1, player2, options = {}) {
  const createPieces = () => [
    { id: 0, position: 0, lastPos: 0, finished: false },
  ];

  return {
    id: `marble-${Date.now()}`,
    playersOrder: [player1, player2],
    players: {
      [player1]: { pieces: createPieces(), coins: MARBLE_START_COINS },
      [player2]: { pieces: createPieces(), coins: MARBLE_START_COINS },
    },
    lands: {},
    round: 1,
    roundTurns: 0,
    phase: 'roll_order',
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
