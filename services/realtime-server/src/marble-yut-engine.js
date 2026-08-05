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

export function getCarriedPieces(selectedPiece, playerPieces) {
  if (selectedPiece.position === 0 || selectedPiece.finished) {
    return [selectedPiece];
  }
  return playerPieces.filter(
    (piece) => !piece.finished && piece.position === selectedPiece.position,
  );
}

export function hasBackdoMove(playerPieces) {
  return playerPieces.some(
    (piece) => !piece.finished && piece.position !== 0,
  );
}

/**
 * Initialize game state
 */
// 마블윷: 말 2개, 완주 승리 없음, 영지 점령 게임
export function createMarbleYutGameState(player1, player2, options = {}) {
  const createPieces = () => [
    { id: 0, position: 0, lastPos: 0, finished: false },
    { id: 1, position: 0, lastPos: 0, finished: false },
  ];

  const initialCoins = 1500;

  return {
    id: `marble-yut-${Date.now()}`,
    playersOrder: [player1, player2],
    players: {
      [player1]: {
        pieces: createPieces(),
        coins: initialCoins,
      },
      [player2]: {
        pieces: createPieces(),
        coins: initialCoins,
      },
    },
    // 영지 상태: { [pos]: { owner: uid, level: 1~4 } }
    lands: {},
    round: 1,           // 현재 라운드 (1~20)
    roundTurns: 0,      // 이번 라운드에서 완료한 플레이어 수 (0 or 1)
    phase: "roll_order",
    currentTurn: null,
    characters: options.characters ?? {},
    bgm: options.bgm ?? null,
    startRolls: {},
    orderCountdownUntil: null,
    pendingMoves: [],
    hasBonusThrow: false,
    caughtOpponentThisTurn: false,
    catchBonusPending: false,   // 잡기 후 영지 인수 기회 대기 중
    catchBonusBy: null,         // H2: 잡기를 수행한 플레이어 uid
    catchBonusUntil: null,      // 보너스 만료 타임스킬프 (ms)
    winner: null,
    winReason: null,
    lastThrow: null,
  };
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
    // Consume the bonus: keep turn and go back to throwing
    gameState.hasBonusThrow = false;
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

// ─── 마블윷 영지 상수 ────────────────────────────────────────────────────────

export const MARBLE_SALARY = 200;
export const MARBLE_MAX_ROUNDS = 20;
export const MARBLE_START_POSITIONS = new Set([0, 20]);
export const SHRINE_POSITIONS = new Set([5, 10, 15]); // 백호, 청룡, 주작

/** 각 칸의 기본 점령비 */
export function getLandValue(pos) {
  if (MARBLE_START_POSITIONS.has(pos)) return 0;
  if (SHRINE_POSITIONS.has(pos)) return 300;
  if (pos === 23) return 200;
  if ([21, 22, 24, 25, 26, 27, 28, 29].includes(pos)) return 150;
  return 100;
}

/** 레벨별 통행료 배율 */
export const LEVEL_RATE = { 1: 1.0, 2: 1.5, 3: 2.5, 4: 3.5 };

/** 레벨별 강화비 (점령비 × 배수) */
export const UPGRADE_COST_MULT = { 2: 1, 3: 2, 4: 3 };

/** 통행료 계산 */
export function calcToll(pos, level) {
  const base = getLandValue(pos);
  return Math.floor(base * (LEVEL_RATE[level] ?? 1.0));
}

/** 인수비 계산 (stacked 시 50% 할인) */
export function calcAcquireCost(pos, stacked = false) {
  const base = getLandValue(pos);
  const cost = Math.floor(base * 1.3);
  return stacked ? Math.floor(cost * 0.5) : cost;
}

/** 서든데스 점수 계산 */
export function calcScore(gameState, uid) {
  const coins = gameState.players[uid]?.coins ?? 0;
  let landValue = 0;
  for (const [posStr, land] of Object.entries(gameState.lands)) {
    if (land.owner === uid) {
      const pos = Number(posStr);
      const toll = calcToll(pos, land.level);
      landValue += toll * 10;
    }
  }
  return coins + landValue;
}

/** 4개 변 (모서리 포함 6칸씩) */
export const LINE_SETS = [
  [5, 6, 7, 8, 9, 10],   // 우변: 백호↔청룡
  [10, 11, 12, 13, 14, 15], // 상변: 청룡↔주작
  [15, 16, 17, 18, 19, 0],  // 좌변: 주작↔현무 (pos 0 = 현무, 점령 불가이므로 5칸 실질)
  [0, 1, 2, 3, 4, 5],    // 하변: 현무↔백호 (pos 0 점령 불가이므로 5칸 실질)
];

// ─── 승리 조건 체크 ──────────────────────────────────────────────────────────

/**
 * 마블윷 승리 조건 체크.
 * 반환: { winner: uid, reason } or null
 */
export function checkMarbleWin(gameState) {
  const [p1, p2] = gameState.playersOrder;

  // 1. 파산
  if ((gameState.players[p1]?.coins ?? 0) <= 0) return { winner: p2, reason: 'bankrupt' };
  if ((gameState.players[p2]?.coins ?? 0) <= 0) return { winner: p1, reason: 'bankrupt' };

  // 2. 신수 독점 (pos 5, 10, 15 모두 동일 플레이어)
  for (const uid of [p1, p2]) {
    if ([...SHRINE_POSITIONS].every((pos) => gameState.lands[pos]?.owner === uid)) {
      return { winner: uid, reason: 'shrine' };
    }
  }

  // 3. 한 변 독점 (6칸 모두 동일 플레이어, pos 0 제외 처리)
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

// ─── 마블윷 완주는 승리 조건이 아님 ─ 기존 checkWin 대체 ─────────────────

/** 완주해도 게임이 끝나지 않음. 출발지 통과 시 월급만 지급. */
export function checkWin(_playerState) {
  return false;
}

export function getNextPlayer(gameState, player) {
  return gameState.playersOrder.find((candidate) => candidate !== player);
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
    hasBonusThrow: gameState.hasBonusThrow ?? false,
    catchBonusPending: gameState.catchBonusPending,
    // H2: 잡기 수행자 정보를 클라이언트에 전달 (turnChange와 독립적으로 파악 가능)
    catchBonusBy: gameState.catchBonusBy ?? null,
    catchBonusUntil: gameState.catchBonusUntil ?? null,
    catchBonusTarget: gameState.catchBonusTarget ?? null,
    lastThrow: gameState.lastThrow,
    winner: gameState.winner,
    winReason: gameState.winReason ?? null,
    round: gameState.round ?? 1,
    lands: gameState.lands ?? {},
    coins: Object.fromEntries(
      gameState.playersOrder.map((uid) => [uid, gameState.players[uid]?.coins ?? 0]),
    ),
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
