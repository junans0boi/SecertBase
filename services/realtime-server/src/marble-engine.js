/**
 * SecretBase Marble Game Engine
 *
 * 2-player, 24-tile clockwise board.
 * Win via: double monopoly / line monopoly / tourist monopoly / bankrupt / time limit.
 */

export const BOARD_SIZE = 24;
export const MARBLE_START_COINS = 5_000_000;  // 500만 MM
export const MARBLE_SALARY      = 1_000_000;  // 100만 MM (임무개시 경유 시)
export const MARBLE_MAX_ROUNDS  = 30;

export const MARBLE_START_POSITIONS = new Set([0]);

// Special tile positions
export const TILE_START = 0;
export const TILE_JAIL  = 6;
export const TILE_TAX   = 12;
export const TILE_GATE  = 18;

// Special cost (블랙사이트 탈출 / 운영본부 세금 / 비밀게이트 이동)
export const SPECIAL_FEE = 500_000; // 50만 MM

// Tile types for non-city tiles
export const TILE_TYPES = {
  0:  'start',
  3:  'card',
  6:  'jail',
  8:  'tourist',
  9:  'card',
  12: 'tax',
  15: 'card',
  17: 'tourist',
  18: 'gate',
  21: 'card',
};

// Color groups: which positions belong to each color
export const COLOR_GROUPS = {
  red:    [1, 2],       // 방콕, 카이로
  orange: [4, 5],       // 뭄바이, 자카르타
  green:  [7, 10, 11],  // 시드니, 베를린, 모스크바
  blue:   [13, 14],     // 도쿄, 상하이
  purple: [16, 19],     // 뉴욕, 파리
  gold:   [20, 22, 23], // 런던, 두바이, 서울
};

// Tourist spot positions
export const TOURIST_SPOTS = new Set([8, 17]);

// Per-city data: { color, price, buildCosts[house,building,landmark], tolls[land,house,building,landmark] }
const CITY_DATA = {
  //  pos   color     price        buildCosts                         tolls
  1:  { color: 'red',    price:  500_000, buildCosts: [ 200_000,   500_000, 1_000_000], tolls: [20_000,   80_000,  250_000,   700_000] },
  2:  { color: 'red',    price:  500_000, buildCosts: [ 200_000,   500_000, 1_000_000], tolls: [20_000,   80_000,  250_000,   700_000] },
  4:  { color: 'orange', price:  700_000, buildCosts: [ 300_000,   700_000, 1_400_000], tolls: [30_000,  120_000,  380_000, 1_000_000] },
  5:  { color: 'orange', price:  700_000, buildCosts: [ 300_000,   700_000, 1_400_000], tolls: [30_000,  120_000,  380_000, 1_000_000] },
  7:  { color: 'green',  price: 1_000_000, buildCosts: [ 400_000, 1_000_000, 2_000_000], tolls: [50_000,  180_000,  550_000, 1_500_000] },
  8:  { color: 'tourist', price: 1_000_000, buildCosts: [], tolls: [800_000, 800_000, 800_000, 800_000] },
  10: { color: 'green',  price: 1_000_000, buildCosts: [ 400_000, 1_000_000, 2_000_000], tolls: [50_000,  180_000,  550_000, 1_500_000] },
  11: { color: 'green',  price: 1_000_000, buildCosts: [ 400_000, 1_000_000, 2_000_000], tolls: [50_000,  180_000,  550_000, 1_500_000] },
  13: { color: 'blue',   price: 1_300_000, buildCosts: [ 600_000, 1_300_000, 2_600_000], tolls: [70_000,  250_000,  780_000, 2_100_000] },
  14: { color: 'blue',   price: 1_300_000, buildCosts: [ 600_000, 1_300_000, 2_600_000], tolls: [70_000,  250_000,  780_000, 2_100_000] },
  16: { color: 'purple', price: 1_600_000, buildCosts: [ 800_000, 1_600_000, 3_200_000], tolls: [90_000,  320_000, 1_000_000, 2_700_000] },
  17: { color: 'tourist', price: 1_000_000, buildCosts: [], tolls: [800_000, 800_000, 800_000, 800_000] },
  19: { color: 'purple', price: 1_600_000, buildCosts: [ 800_000, 1_600_000, 3_200_000], tolls: [90_000,  320_000, 1_000_000, 2_700_000] },
  20: { color: 'gold',   price: 2_000_000, buildCosts: [1_000_000, 2_000_000, 4_000_000], tolls: [120_000, 450_000, 1_400_000, 3_800_000] },
  22: { color: 'gold',   price: 2_000_000, buildCosts: [1_000_000, 2_000_000, 4_000_000], tolls: [120_000, 450_000, 1_400_000, 3_800_000] },
  23: { color: 'gold',   price: 2_000_000, buildCosts: [1_000_000, 2_000_000, 4_000_000], tolls: [120_000, 450_000, 1_400_000, 3_800_000] },
};

export function getCityData(pos) {
  return CITY_DATA[pos] ?? null;
}

export function getLandValue(pos) {
  return CITY_DATA[pos]?.price ?? 0;
}

export function getTileType(pos) {
  if (TILE_TYPES[pos]) return TILE_TYPES[pos];
  if (CITY_DATA[pos]) return CITY_DATA[pos].color === 'tourist' ? 'tourist' : 'property';
  return 'unknown';
}

// Keep server special-tile dispatch tied to the canonical 24-tile board.
export function getMarbleSpecialType(pos) {
  const type = TILE_TYPES[pos];
  return type === 'card' || type === 'tax' ? type : null;
}

export function rollDice() {
  const dice1 = Math.floor(Math.random() * 6) + 1;
  const dice2 = Math.floor(Math.random() * 6) + 1;
  return { dice1, dice2, total: dice1 + dice2, isDouble: dice1 === dice2 };
}

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

export function settleTurnAfterMove(gameState, userId) {
  if (gameState.pendingMoves.length > 0) {
    gameState.phase = 'moving';
    return;
  }
  if (gameState.hasDoubleRoll) {
    gameState.hasDoubleRoll = false;
    gameState.currentTurn = userId;
    gameState.phase = 'throwing';
    return;
  }
  gameState.currentTurn = getNextPlayer(gameState, userId);
  gameState.phase = 'throwing';
}

// Toll for landing on pos at level (0=land only, 1=house, 2=building, 3=landmark)
export function calcToll(pos, level) {
  const data = CITY_DATA[pos];
  if (!data) return 0;
  return data.tolls[Math.min(level, data.tolls.length - 1)] ?? 0;
}

export function calcPurchaseCost(pos) {
  return CITY_DATA[pos]?.price ?? 0;
}

// Acquisition cost = (price + sum of all buildCosts up to current level) × 2
export function calcAcquireCost(pos, currentLevel = 0) {
  const data = CITY_DATA[pos];
  if (!data || data.color === 'tourist') return 0;
  let invested = data.price;
  for (let i = 0; i < currentLevel && i < data.buildCosts.length; i++) {
    invested += data.buildCosts[i];
  }
  return invested * 2;
}

// Cost to build at targetLevel (1=house, 2=building, 3=landmark)
export function calcUpgradeCost(pos, targetLevel) {
  const data = CITY_DATA[pos];
  if (!data || targetLevel < 1 || targetLevel > 3) return 0;
  return data.buildCosts[targetLevel - 1] ?? 0;
}

export function hasColorMonopoly(gameState, uid, pos) {
  const data = CITY_DATA[pos];
  if (!data || data.color === 'tourist') return false;
  const group = COLOR_GROUPS[data.color];
  return Boolean(group?.every((groupPos) => gameState.lands[groupPos]?.owner === uid));
}

// Total asset score for a player (coins + all invested land value)
export function calcScore(gameState, uid) {
  const coins = gameState.players[uid]?.coins ?? 0;
  let landValue = 0;
  for (const [posStr, land] of Object.entries(gameState.lands)) {
    if (land.owner === uid) {
      const pos = Number(posStr);
      const data = CITY_DATA[pos];
      if (!data) continue;
      landValue += data.price;
      for (let i = 0; i < (land.level ?? 0) && i < data.buildCosts.length; i++) {
        landValue += data.buildCosts[i];
      }
    }
  }
  return coins + landValue;
}

// Check all win conditions after each move/event
export function checkMarbleWin(gameState) {
  const [p1, p2] = gameState.playersOrder;

  // 파산
  if ((gameState.players[p1]?.coins ?? 0) <= 0) return { winner: p2, reason: 'bankrupt' };
  if ((gameState.players[p2]?.coins ?? 0) <= 0) return { winner: p1, reason: 'bankrupt' };

  for (const uid of [p1, p2]) {
    // 관광지 독점 (비밀의섬 pos8 + 비밀의해변 pos17)
    if ([8, 17].every((pos) => gameState.lands[pos]?.owner === uid)) {
      return { winner: uid, reason: 'tourist_monopoly' };
    }

    // 더블 독점: 컬러 그룹 2개 이상 완전 소유
    let monopolyCount = 0;
    for (const group of Object.values(COLOR_GROUPS)) {
      if (group.every((pos) => gameState.lands[pos]?.owner === uid)) monopolyCount++;
    }
    if (monopolyCount >= 2) return { winner: uid, reason: 'double_monopoly' };

    // 라인 독점: 한 사이드 모든 구매 가능 칸 소유
    // bottom(1,2,4,5), right(7,8,10,11), top(13,14,16,17), left(19,20,22,23)
    const lineSides = [
      [1, 2, 4, 5],
      [7, 8, 10, 11],
      [13, 14, 16, 17],
      [19, 20, 22, 23],
    ];
    for (const side of lineSides) {
      if (side.every((pos) => gameState.lands[pos]?.owner === uid)) {
        return { winner: uid, reason: 'line_monopoly' };
      }
    }
  }

  return null;
}

export function getNextPlayer(gameState, player) {
  return gameState.playersOrder.find((candidate) => candidate !== player);
}

export function createMarbleGameState(player1, player2, options = {}) {
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
    visitCounts: { [player1]: {}, [player2]: {} }, // visit-based building system
    jailTurns:  { [player1]: 0, [player2]: 0 },    // 블랙사이트 감금 턴
    round: 1,
    roundTurns: 0,
    phase: 'roll_order',
    currentTurn: null,
    characters: options.characters ?? {},
    startRolls: {},
    orderCountdownUntil: null,
    pendingMoves: [],
    hasDoubleRoll: false,
    consecutiveDoubles: 0,
    pendingLandAction: null,
    gateActivated: null,  // uid with pending gate move
    oddEvenItems: { [player1]: 0, [player2]: 0 },
    winner: null,
    winReason: null,
    lastRoll: null,
  };
}

export function serializeMarbleGame(gameState) {
  return {
    id: gameState.id,
    players: gameState.playersOrder,
    phase: gameState.phase,
    currentTurn: gameState.currentTurn,
    characters: gameState.characters ?? {},
    startRolls: gameState.startRolls ?? {},
    orderCountdownUntil: gameState.orderCountdownUntil ?? null,
    pendingMoves: gameState.pendingMoves,
    hasDoubleRoll: gameState.hasDoubleRoll ?? false,
    consecutiveDoubles: gameState.consecutiveDoubles ?? 0,
    pendingLandAction: gameState.pendingLandAction ?? null,
    lastRoll: gameState.lastRoll ?? null,
    winner: gameState.winner,
    winReason: gameState.winReason ?? null,
    round: gameState.round ?? 1,
    lands: gameState.lands ?? {},
    visitCounts: gameState.visitCounts ?? {},
    jailTurns: gameState.jailTurns ?? {},
    gateActivated: gameState.gateActivated ?? null,
    oddEvenItems: gameState.oddEvenItems ?? {},
    coins: Object.fromEntries(
      gameState.playersOrder.map((uid) => [uid, gameState.players[uid]?.coins ?? 0]),
    ),
    pieces: Object.fromEntries(
      Object.entries(gameState.players).map(([player, state]) => [player, state.pieces]),
    ),
    equippedItems: gameState.equippedItems ?? {},
  };
}
