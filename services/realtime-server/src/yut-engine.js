/**
 * 윷놀이 규칙 엔진(게임 2.0). 순수 함수 + random 주입. 소켓 흐름은 src/games/yut.js.
 *
 * 판: 0=대기(판 밖), 1–19 바깥길, 20=참먹이(도착 칸, 여기서 한 칸 더 가야 완주),
 * 21–22(모→방), 23=방(가운데), 24–25(뒷모→방), 26–27(방→참먹이), 28–29(방→찌모).
 * 모서리: 5=모, 10=뒷모, 15=찌모, 20=참먹이.
 *
 * 막대: 0=납작한 면(배), 1=둥근 면(등). 0번 막대는 표시 막대(뒷도 표시).
 *   납작 0개 → 모(5), 납작 1개 → 도(1) / 표시 막대만 납작 → 빽도(-1),
 *   납작 2개 → 개(2), 3개 → 걸(3), 4개 → 윷(4).
 *
 * 아이템(01-grilling Q6–Q8): 던지기 계열 효과는 합산 상한(THROW_ITEM_CAP_PCT) 안에서 비례 축소,
 * 방어는 한 번만 굴리고 상한 10%, 막히면 움직이던 말이 바로 앞 칸에 멈춘다.
 * 코인 보너스는 판당 판돈의 30%까지만 쌓이고 정산 때만 지급된다.
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
  '-1': '빽도',
};

export const GOAL_POSITION = 20;
export const PIECE_COUNTS = [4, 3, 2];
export const DEFAULT_PIECE_COUNT = 4;

/** 던지기 결과를 올리는 효과(윷·모 확률, 모 확률, 역전)의 합계 상한(%). 균형 테스트로 고정. */
export const THROW_ITEM_CAP_PCT = 2.5;
/** 방어 계열(잡힘 방어·안전 착지) 합계 상한(%). 한 번만 굴린다(10% 이하). */
export const DEFENSE_CAP_PCT = 9;
/** 빽도 뒤 추가 던지기 확률 상한(%). */
export const BACKDO_BONUS_CAP_PCT = 8;
/** 침착(빽도가 나오면 다시 던지기) 확률 상한(%). */
export const CALM_CAP_PCT = 12;
/** 판당 코인 보너스 상한: 판돈 × 30%. */
export const COIN_BONUS_CAP_RATIO = 0.3;

// ── 캐릭터 능력치(1~5): 화면에 그대로 보여 주고 서버가 같은 값으로 효과를 낸다 ──────────
// 합계는 모두 15(트레이드오프). 클라이언트 로비 표(yut_models.dart)와 같아야 한다(테스트가 확인).
export const YUT_STAT_KEYS = ['power', 'calm', 'guard', 'luck', 'momentum'];
export const YUT_CHARACTER_STATS = Object.freeze({
  // 홍길동: 균형·수비 — 침착하고 단단하다.
  honggilldong: Object.freeze({ power: 3, calm: 4, guard: 4, luck: 2, momentum: 2 }),
  // 미호: 기술·행운 — 운이 좋고 뒤따라잡기에 강하다.
  miho: Object.freeze({ power: 3, calm: 2, guard: 2, luck: 5, momentum: 3 }),
  // 놀부: 힘·욕심 — 던지기가 세지만 빽도에 약하다.
  nolbu: Object.freeze({ power: 5, calm: 1, guard: 3, luck: 3, momentum: 3 }),
});
const NEUTRAL_STATS = Object.freeze({ power: 3, calm: 3, guard: 3, luck: 3, momentum: 3 });

export const yutCharacterStats = (character) => YUT_CHARACTER_STATS[character] ?? NEUTRAL_STATS;

// 레벨 1은 0, 레벨 5가 최대. (레벨-1) × 단계 값.
const STAT_STEP = {
  power: 0.3, // 윷·모 확률(걸→윷, 도→모) +0.3%p / 레벨
  calm: 4, // 빽도가 나오면 다시 던질 확률 +4%p / 레벨
  guard: 1.5, // 잡힘 방어 +1.5%p / 레벨
  luckBackdo: 2, // 빽도 뒤 추가 던지기 +2%p / 레벨(무료 판에서도 의미 있음)
  luckCoin: 1, // 윷·모 코인 보너스 +1% / 레벨(판돈 판)
  momentum: 0.4, // 지고 있을 때 윷·모 확률 +0.4%p / 레벨
};

/** 캐릭터 능력치가 만드는 효과(합산 상한을 적용하기 전 값). */
export function characterEffects(character) {
  const s = yutCharacterStats(character);
  return {
    controlPct: (s.power - 1) * STAT_STEP.power,
    calmPct: (s.calm - 1) * STAT_STEP.calm,
    defensePct: (s.guard - 1) * STAT_STEP.guard,
    backdoBonusPct: (s.luck - 1) * STAT_STEP.luckBackdo,
    winCoinPct: (s.luck - 1) * STAT_STEP.luckCoin,
    overturnPct: (s.momentum - 1) * STAT_STEP.momentum,
  };
}

// 아이템 한 개 효과의 옛 상한(아이템 카탈로그 기준). 합산 상한 전에 먼저 자른다.
const RAW_CAPS = {
  yut_control_pct: 15,
  yut_mo_rate_pct: 8,
  yut_overturn_pct: 10,
  yut_backdo_bonus_pct: 25,
  yut_backdo_shield_pct: 25,
  piece_catch_resist_pct: 15,
  piece_safe_zone_pct: 15,
  yut_win_coin_pct: 15,
  piece_catch_coin_bonus: 25,
  yut_catch_bonus: 300,
};

const num = (value) => {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : 0;
};
const rawStat = (stats, key) => Math.min(num(stats?.[key]), RAW_CAPS[key]);
const round3 = (v) => Math.round(v * 1000) / 1000;

/**
 * 장착 윷 스킨 합계(getEquippedStats) + 캐릭터 능력치 → 이 판에 실제로 적용할 효과.
 * 던지기 계열(윷·모 확률·모 확률·역전)은 합이 THROW_ITEM_CAP_PCT를 넘으면 같은 비율로 줄이고,
 * 방어·빽도 보너스·침착·코인은 각자 상한을 따로 둔다.
 */
export function yutItemEffects(stats = {}, character = null) {
  const ch = character ? characterEffects(character) : {};
  const control = rawStat(stats, 'yut_control_pct') + (ch.controlPct ?? 0);
  const moRate = rawStat(stats, 'yut_mo_rate_pct');
  const overturn = rawStat(stats, 'yut_overturn_pct') + (ch.overturnPct ?? 0);
  const sum = control + moRate + overturn;
  const scale = sum > THROW_ITEM_CAP_PCT ? THROW_ITEM_CAP_PCT / sum : 1;
  return {
    controlPct: round3(control * scale),
    moRatePct: round3(moRate * scale),
    overturnPct: round3(overturn * scale),
    backdoBonusPct: round3(Math.min(BACKDO_BONUS_CAP_PCT, rawStat(stats, 'yut_backdo_bonus_pct') + (ch.backdoBonusPct ?? 0))),
    calmPct: round3(Math.min(CALM_CAP_PCT, rawStat(stats, 'yut_backdo_shield_pct') + (ch.calmPct ?? 0))),
    defensePct: round3(Math.min(DEFENSE_CAP_PCT, rawStat(stats, 'piece_catch_resist_pct') + rawStat(stats, 'piece_safe_zone_pct') + (ch.defensePct ?? 0))),
    winCoinPct: round3(Math.min(15, rawStat(stats, 'yut_win_coin_pct') + (ch.winCoinPct ?? 0))),
    catchCoinPer: Math.floor(rawStat(stats, 'piece_catch_coin_bonus')),
    catchFlat: Math.floor(rawStat(stats, 'yut_catch_bonus')),
  };
}

/** 막대 모양 → 결과. 화면은 이 규칙대로 막대를 그리므로 서버 결과와 항상 같아야 한다. */
export function resultFromSticks(sticks) {
  const flat = sticks.filter((s) => s === 0).length;
  if (flat === 0) return YUT_RESULTS.MO;
  if (flat === 1) return sticks[0] === 0 ? YUT_RESULTS.BACKDO : YUT_RESULTS.DO;
  if (flat === 2) return YUT_RESULTS.GAE;
  if (flat === 3) return YUT_RESULTS.GEOL;
  return YUT_RESULTS.YUT;
}

const STICKS_FOR = {
  [YUT_RESULTS.YUT]: [0, 0, 0, 0],
  [YUT_RESULTS.MO]: [1, 1, 1, 1],
};

/**
 * 윷 4개를 던진다. 아이템 효과는 yutItemEffects로 이미 줄인 값을 넘긴다
 * (원시 값이 와도 같은 합산 상한을 다시 적용한다).
 * - 컨트롤: 걸→윷, 도→모(빽도에는 발동하지 않음)
 * - 모 확률: 윷→모
 * - 역전: 골인한 말이 상대보다 적을 때 컨트롤에 더함
 * 결과가 바뀌면 sticks도 결과 모양으로 다시 만든다.
 */
export function throwYut({
  yutControlPct = 0,
  yutMoRatePct = 0,
  yutOverturnPct = 0,
  isLosing = false,
  random = Math.random,
} = {}) {
  const capped = yutItemEffects({
    yut_control_pct: yutControlPct,
    yut_mo_rate_pct: yutMoRatePct,
    yut_overturn_pct: yutOverturnPct,
  });
  let sticks = Array.from({ length: 4 }, () => (random() < 0.5 ? 0 : 1));
  const natural = resultFromSticks(sticks);
  let result = natural;

  const controlPct = capped.controlPct + (isLosing ? capped.overturnPct : 0);
  if (controlPct > 0) {
    if (natural === YUT_RESULTS.GEOL && random() * 100 < controlPct) result = YUT_RESULTS.YUT;
    else if (natural === YUT_RESULTS.DO && random() * 100 < controlPct) result = YUT_RESULTS.MO;
  }
  if (capped.moRatePct > 0 && result === YUT_RESULTS.YUT && random() * 100 < capped.moRatePct) {
    result = YUT_RESULTS.MO;
  }
  if (result !== natural) sticks = [...STICKS_FOR[result]];

  return {
    sticks,
    result,
    resultName: YUT_RESULT_NAMES[result],
    bonusThrow: result === YUT_RESULTS.YUT || result === YUT_RESULTS.MO,
    boosted: result !== natural,
  };
}

// ── 판 위 이동 ────────────────────────────────────────────────────────────

const NEXT = {
  0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 9, 9: 10,
  10: 11, 11: 12, 12: 13, 13: 14, 14: 15, 15: 16, 16: 17, 17: 18, 18: 19, 19: GOAL_POSITION,
  21: 22, 22: 23, 24: 25, 25: 23, 26: 27, 27: GOAL_POSITION, 28: 29, 29: 15,
};

function getNextPosition(currentPosition, isFirstStep, lastPos = 0) {
  if (currentPosition === GOAL_POSITION) return GOAL_POSITION;
  if (isFirstStep) {
    if (currentPosition === 5) return 21;
    if (currentPosition === 10) return 24;
    if (currentPosition === 23) return 26;
  }
  // 방(23)을 지나갈 때: 모(5)에서 온 말은 찌모(15) 쪽으로, 뒷모(10)에서 온 말은 참먹이 쪽으로.
  if (currentPosition === 23) return lastPos === 22 ? 28 : 26;
  return NEXT[currentPosition] ?? GOAL_POSITION;
}

/** 빽도 갈림길: 두 방향 중 고를 수 있는 칸 → 고를 수 있는 앞 칸. */
export const BACKDO_FORKS = Object.freeze({
  23: Object.freeze([22, 25]),
  15: Object.freeze([14, 29]),
  20: Object.freeze([19, 27]),
});

const PREV = {
  0: 0,
  // 날빽도: 1칸에서 빽도는 대기(0)가 아니라 참먹이(20)에서 대기. 완주는 다음 이동에서.
  1: 20,
  2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7, 9: 8, 10: 9,
  11: 10, 12: 11, 13: 12, 14: 13, 16: 15, 17: 16, 18: 17, 19: 18,
  21: 5, 22: 21, 24: 10, 25: 24, 26: 23, 27: 26, 28: 23, 29: 28,
};

function getPrevPosition(currentPosition, lastPos, backdoDir = null) {
  const fork = BACKDO_FORKS[currentPosition];
  if (fork) {
    if (fork.includes(backdoDir)) return backdoDir;
    if (currentPosition === GOAL_POSITION) return lastPos === 27 ? 27 : 19;
    if (currentPosition === 23) return lastPos === 25 || lastPos === 24 || lastPos === 10 ? 25 : 22;
    return lastPos === 29 ? 29 : 14;
  }
  return PREV[currentPosition] ?? 0;
}

/**
 * 한 번의 이동을 칸 단위로 따라간다.
 * → { path: [출발, …,도착], position, lastPos, finished, prev }
 *   prev: 도착 바로 앞 칸의 { position, lastPos } (방어로 막혔을 때 멈출 자리)
 */
export function tracePath(piece, steps, { backdoDir } = {}) {
  if (!piece || piece.finished) return null;
  const origin = { position: piece.position, lastPos: piece.lastPos ?? 0 };
  if (steps === YUT_RESULTS.BACKDO) {
    if (origin.position === 0) return { path: [0], position: 0, lastPos: origin.lastPos, finished: false, prev: null };
    const position = getPrevPosition(origin.position, origin.lastPos, backdoDir);
    return { path: [origin.position, position], position, lastPos: origin.position, finished: false, prev: origin };
  }
  const path = [origin.position];
  let position = origin.position;
  let lastPos = origin.lastPos;
  let prev = origin;
  for (let i = 0; i < steps; i += 1) {
    if (position === GOAL_POSITION) {
      return { path, position: GOAL_POSITION, lastPos: GOAL_POSITION, finished: true, prev };
    }
    const next = getNextPosition(position, i === 0, lastPos);
    prev = { position, lastPos };
    lastPos = position;
    position = next;
    path.push(position);
  }
  return { path, position, lastPos, finished: false, prev };
}

/**
 * 말 하나를 움직인 결과(옛 API). `{ position, lastPos, finished }` 또는 완주한 말이면 null.
 * opts.backdoDir: 갈림길(23·15·20)에서 빽도 방향.
 */
export function movePiece(piece, steps, { backdoDir } = {}) {
  if (piece.finished) return null;
  if (steps === YUT_RESULTS.BACKDO) {
    if (piece.position === 0) return { position: 0, lastPos: piece.lastPos ?? 0 };
    return { position: getPrevPosition(piece.position, piece.lastPos ?? 0, backdoDir), lastPos: piece.position };
  }
  const trace = tracePath(piece, steps);
  return { position: trace.position, lastPos: trace.lastPos, finished: trace.finished };
}

/** 이 칸에 있는(완주하지 않은) 상대 말. 대기(0)는 언제나 안전하다. */
export function checkCatch(position, opponentPieces) {
  if (position === 0) return [];
  return opponentPieces.filter((p) => p.position === position && !p.finished);
}

/** 도착 칸의 상대 말을 모두 대기로 돌려보낸다(업힌 말 포함). */
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
 * 잡기 판정. 방어(잡힘 방어 + 안전 착지)는 합쳐서 한 번만 굴리고 상한은 10%.
 * 막히면 그 칸의 상대 말은 모두 무사하다(같은 칸의 말은 한 무더기로 본다).
 */
export function resolveCapture(position, opponentPieces, { resistPct = 0, safePct = 0, defensePct, random = Math.random } = {}) {
  const candidates = checkCatch(position, opponentPieces);
  if (candidates.length === 0) return { capturedPieces: [], blockedPieces: [] };
  const chance = Math.min(DEFENSE_CAP_PCT, defensePct ?? (num(resistPct) + num(safePct)));
  if (chance > 0 && random() * 100 < chance) return { capturedPieces: [], blockedPieces: candidates };
  return { capturedPieces: capturePieces(position, candidates), blockedPieces: [] };
}

export function getCarriedPieces(selectedPiece, playerPieces) {
  if (selectedPiece.position === 0 || selectedPiece.finished) return [selectedPiece];
  return playerPieces.filter((piece) => !piece.finished && piece.position === selectedPiece.position);
}

/** 고른 말과 그 위에 업힌 말을 함께 옮긴다. */
export function applyMoveToPieces(carriedPieces, moveResult) {
  for (const piece of carriedPieces) {
    piece.lastPos = moveResult.lastPos;
    piece.position = moveResult.position;
    piece.finished = moveResult.finished === true;
  }
  return carriedPieces;
}

export function hasBackdoMove(playerPieces) {
  return playerPieces.some((piece) => !piece.finished && piece.position !== 0);
}

// ── 판 상태 ───────────────────────────────────────────────────────────────

/** 새 판. options: { pieces: 4|3|2, starter, characters, bgm } */
export function createYutGameState(player1, player2, options = {}) {
  const count = PIECE_COUNTS.includes(options.pieces) ? options.pieces : DEFAULT_PIECE_COUNT;
  const createPieces = () => Array.from({ length: count }, (_, id) => ({ id, position: 0, lastPos: 0, finished: false }));
  const starter = [player1, player2].includes(options.starter) ? options.starter : player1;
  return {
    id: `yut-${Date.now()}`,
    playersOrder: [player1, player2],
    players: {
      [player1]: { pieces: createPieces() },
      [player2]: { pieces: createPieces() },
    },
    pieceCount: count,
    phase: 'throwing',
    currentTurn: starter,
    starter,
    characters: options.characters ?? {},
    bgm: options.bgm ?? null,
    pendingMoves: [],
    hasBonusThrow: false,
    caughtOpponentThisTurn: false,
    captureBonusThrows: 0,
    winner: null,
    lastThrow: null,
    // 이번 차례에 던진 결과들(윷·모 보너스 포함). 차례가 넘어가면 비운다.
    turnThrows: [],
    coinBonus: {},
    seq: 0,
    lastAction: null,
  };
}

export function recordYutThrow(gameState, throwResult) {
  gameState.lastThrow = throwResult;
  gameState.turnThrows = [...(Array.isArray(gameState.turnThrows) ? gameState.turnThrows : []), throwResult];
  return gameState.turnThrows;
}

export function resetYutTurnThrows(gameState) {
  gameState.turnThrows = [];
  return gameState.turnThrows;
}

// 잡기로 얻은 추가 던지기 수. 구버전 상태(caughtOpponentThisTurn만 있음)는 1로 본다.
function captureBonus(gameState) {
  const count = Number(gameState.captureBonusThrows) || 0;
  return count > 0 ? count : (gameState.caughtOpponentThisTurn ? 1 : 0);
}
function setCaptureBonus(gameState, count) {
  gameState.captureBonusThrows = count;
  gameState.caughtOpponentThisTurn = count > 0;
}

/** 잡을 때마다 추가 던지기 1회(윷·모 보너스와 따로 센다). */
export function recordCapture(gameState, capturedCount) {
  if (capturedCount > 0) setCaptureBonus(gameState, captureBonus(gameState) + 1);
}

/** 남은 결과가 빽도뿐인데 판 위에 말이 없으면 쓸 수 없으니 버린다(낙). 버린 개수를 돌려준다. */
export function pruneUnusableBackdo(gameState, userId) {
  const pieces = gameState.players?.[userId]?.pieces ?? [];
  const pending = gameState.pendingMoves ?? [];
  if (pending.length === 0 || !pending.every((m) => m === YUT_RESULTS.BACKDO)) return 0;
  if (hasBackdoMove(pieces)) return 0;
  const removed = pending.length;
  gameState.pendingMoves = [];
  return removed;
}

/** 이동 뒤 다음 차례를 정한다. 남은 이동·보너스 던지기·잡기 보너스가 있으면 차례를 유지한다. */
export function settleTurnAfterMove(gameState, userId) {
  if (gameState.pendingMoves.length > 0) {
    gameState.phase = 'moving';
    return;
  }
  if (gameState.hasBonusThrow) {
    gameState.hasBonusThrow = false;
    gameState.currentTurn = userId;
    gameState.phase = 'throwing';
    return;
  }
  const bonus = captureBonus(gameState);
  if (bonus > 0) {
    setCaptureBonus(gameState, bonus - 1);
    gameState.currentTurn = userId;
  } else {
    gameState.currentTurn = getNextPlayer(gameState, userId);
  }
  gameState.phase = 'throwing';
}

export function checkWin(playerState) {
  return playerState.pieces.every((p) => p.finished);
}

export function getNextPlayer(gameState, player) {
  return gameState.playersOrder.find((candidate) => candidate !== player);
}

const effectsOf = (gameState, player) =>
  gameState.effects?.[player] ?? yutItemEffects(gameState.playerStats?.[player] ?? {}, gameState.characters?.[player] ?? null);
const finishedCount = (gameState, player) => (gameState.players?.[player]?.pieces ?? []).filter((p) => p.finished).length;

/** 판당 코인 보너스 상한(판돈의 30%). 무료 판은 0. */
export const coinBonusCap = (stake) => Math.floor(num(stake) * COIN_BONUS_CAP_RATIO);

/**
 * 코인 보너스를 상한 안에서 쌓는다. 실제로 더해진 양을 돌려준다(0이면 상한에 닿음).
 * 지급은 정산 때 승자에게만 한다.
 */
export function accrueCoinBonus(gameState, player, amount) {
  const cap = coinBonusCap(gameState.stake);
  const current = num(gameState.coinBonus?.[player]);
  const added = Math.max(0, Math.min(Math.floor(num(amount)), cap - current));
  if (added > 0) gameState.coinBonus = { ...(gameState.coinBonus ?? {}), [player]: current + added };
  return added;
}

const canThrowNow = (gameState) => gameState.phase === 'throwing' || (gameState.phase === 'moving' && gameState.hasBonusThrow);

/**
 * 던지기 한 번(손으로 또는 자동). 결과를 상태에 쌓고, 빽도를 쓸 수 없으면 낙 처리한다.
 * → { ok, throwResult, nak, itemEffects }
 */
export function applyThrow(gameState, userId, { random = Math.random, auto = false } = {}) {
  if (gameState.winner) return { ok: false, reason: 'game_over' };
  if (!gameState.players?.[userId]) return { ok: false, reason: 'not_in_game' };
  if (gameState.currentTurn !== userId) return { ok: false, reason: 'not_your_turn' };
  if (!canThrowNow(gameState)) return { ok: false, reason: 'must_move_first' };
  if (gameState.hasBonusThrow) gameState.hasBonusThrow = false;

  const effects = effectsOf(gameState, userId);
  const opponent = getNextPlayer(gameState, userId);
  const isLosing = finishedCount(gameState, userId) < finishedCount(gameState, opponent);
  const throwOnce = () => throwYut({
    yutControlPct: effects.controlPct,
    yutMoRatePct: effects.moRatePct,
    yutOverturnPct: effects.overturnPct,
    isLosing,
    random,
  });
  let thrown = throwOnce();
  const itemEffects = [];
  // 침착: 빽도가 나오면 일정 확률로 다시 던진다(막대도 새로 던진 모양 그대로).
  if (thrown.result === YUT_RESULTS.BACKDO && effects.calmPct > 0 && random() * 100 < effects.calmPct) {
    thrown = throwOnce();
    itemEffects.push({ player: userId, stat: 'yut_backdo_shield_pct', amount: 0 });
  }
  if (thrown.bonusThrow && effects.winCoinPct > 0) {
    const added = accrueCoinBonus(gameState, userId, (num(gameState.stake) * effects.winCoinPct) / 100);
    if (added > 0) itemEffects.push({ player: userId, stat: 'yut_win_coin_pct', amount: added });
  }
  // 아직 둘 이동이 남아 있으면 그 이동으로 말이 판에 올라온 뒤 빽도를 쓸 수 있으니 낙이 아니다.
  const nak = thrown.result === YUT_RESULTS.BACKDO
    && gameState.pendingMoves.length === 0
    && !hasBackdoMove(gameState.players[userId].pieces);
  const throwResult = {
    result: thrown.result,
    resultName: thrown.resultName,
    sticks: thrown.sticks,
    nak,
    bonus: thrown.bonusThrow,
    auto,
  };
  recordYutThrow(gameState, throwResult);
  if (!nak) gameState.pendingMoves.push(thrown.result);
  if (thrown.bonusThrow) gameState.hasBonusThrow = true;

  if (nak && gameState.pendingMoves.length === 0) {
    gameState.hasBonusThrow = false;
    setCaptureBonus(gameState, 0);
    gameState.currentTurn = opponent;
    gameState.phase = 'throwing';
  } else {
    gameState.phase = 'moving';
  }
  gameState.seq = (gameState.seq ?? 0) + 1;
  gameState.lastAction = { type: 'throw', by: userId, auto, seq: gameState.seq, throw: throwResult, itemEffects };
  if (gameState.currentTurn !== userId) {
    gameState.lastAction.turnPassed = true;
    resetYutTurnThrows(gameState);
  }
  return { ok: true, throwResult, nak, itemEffects };
}

function representatives(pieces) {
  const reps = [];
  const seen = new Set();
  for (const piece of pieces) {
    if (piece.finished) continue;
    const key = piece.position === 0 ? 'start' : piece.position;
    if (seen.has(key)) continue;
    seen.add(key);
    const pieceIds = piece.position === 0
      ? [piece.id]
      : pieces.filter((p) => !p.finished && p.position === piece.position).map((p) => p.id);
    reps.push({ piece, pieceIds });
  }
  return reps;
}

/**
 * 지금 둘 수 있는 이동 전부(서버가 계산해 화면에 보낸다, 화면은 규칙을 다시 계산하지 않는다).
 * → [{ moveIndex, steps, pieceId, pieceIds, backdoDir, from, to, path, finish, captures, stacks }]
 * 대기 말은 하나만, 업힌 말은 한 무더기로 낸다(pieceIds에 모두 담김).
 */
export function legalMoves(gameState, player) {
  if (gameState.winner || gameState.currentTurn !== player) return [];
  const pending = gameState.pendingMoves ?? [];
  if (pending.length === 0) return [];
  const mine = gameState.players?.[player]?.pieces ?? [];
  const opponent = getNextPlayer(gameState, player);
  const theirs = gameState.players?.[opponent]?.pieces ?? [];
  const moves = [];
  pending.forEach((steps, moveIndex) => {
    for (const { piece, pieceIds } of representatives(mine)) {
      if (steps === YUT_RESULTS.BACKDO && piece.position === 0) continue;
      const dirs = steps === YUT_RESULTS.BACKDO && BACKDO_FORKS[piece.position] ? BACKDO_FORKS[piece.position] : [null];
      for (const dir of dirs) {
        const trace = tracePath(piece, steps, { backdoDir: dir });
        if (!trace) continue;
        const captures = trace.finished ? 0 : checkCatch(trace.position, theirs).length;
        const stacks = trace.finished || trace.position === 0
          ? 0
          : mine.filter((p) => !p.finished && p.position === trace.position && !pieceIds.includes(p.id)).length;
        moves.push({
          moveIndex,
          steps,
          pieceId: piece.id,
          pieceIds,
          backdoDir: dir,
          from: piece.position,
          to: trace.position,
          path: trace.path,
          finish: trace.finished,
          captures,
          stacks,
        });
      }
    }
  });
  return moves;
}

// 골인까지 남은 거리(지름길을 지나쳐 가는 기본 길 기준). 자동 이동의 "가장 앞선 말" 판단용.
const REMAINING = {
  0: 21, 1: 20, 2: 19, 3: 18, 4: 17, 5: 12, 6: 15, 7: 14, 8: 13, 9: 12, 10: 7,
  11: 10, 12: 9, 13: 8, 14: 7, 15: 6, 16: 5, 17: 4, 18: 3, 19: 2, 20: 1,
  21: 11, 22: 10, 23: 4, 24: 6, 25: 5, 26: 3, 27: 2, 28: 7, 29: 6,
};
export const remainingDistance = (position) => REMAINING[position] ?? 21;

/**
 * 시간이 지났을 때 서버가 고르는 "최선 이동": 잡기 > 골인 > 가장 앞선 말.
 * 빽도는 잡을 때가 아니면 앞으로 가는 이동이 없을 때만 쓴다.
 */
export function autoMove(gameState, player) {
  const moves = legalMoves(gameState, player);
  if (moves.length === 0) return null;
  const rank = (m) => {
    if (m.captures > 0) return 3;
    if (m.finish) return 2;
    return m.steps === YUT_RESULTS.BACKDO ? 0 : 1;
  };
  const sorted = [...moves].sort((a, b) =>
    rank(b) - rank(a)
    || b.captures - a.captures
    || remainingDistance(a.from) - remainingDistance(b.from)
    || b.steps - a.steps
    || a.moveIndex - b.moveIndex);
  return sorted[0];
}

/**
 * 이동 한 번의 판 변화(업기·잡기·방어). 상태 저장·보너스·차례는 applyMove가 맡는다.
 * 방어에 막히면 움직이던 말은 도착 바로 앞 칸에 멈춘다. 앞 칸이 대기(0)이거나
 * 앞 칸에도 상대 말이 있으면 방어는 실패로 보고 정상적으로 잡는다.
 */
export function resolveYutMove(
  gameState,
  userId,
  { pieceId, moveIndex = 0, backdoDir, defenderStats, defensePct, random = Math.random } = {},
) {
  const playerState = gameState.players?.[userId];
  if (!playerState || !Array.isArray(playerState.pieces)) return { ok: false, reason: 'not_a_player' };
  if (!Array.isArray(gameState.pendingMoves) || gameState.pendingMoves.length === 0) {
    return { ok: false, reason: 'no_pending_moves' };
  }
  if (gameState.currentTurn !== userId) return { ok: false, reason: 'not_your_turn' };
  if (!Number.isInteger(moveIndex) || moveIndex < 0 || moveIndex >= gameState.pendingMoves.length) {
    return { ok: false, reason: 'invalid_move_index' };
  }
  const piece = playerState.pieces[pieceId];
  if (!piece || piece.finished) return { ok: false, reason: 'invalid_piece' };
  const steps = gameState.pendingMoves[moveIndex];
  if (steps === YUT_RESULTS.BACKDO && piece.position === 0) return { ok: false, reason: 'invalid_piece_for_move' };
  const fork = BACKDO_FORKS[piece.position];
  const dir = steps === YUT_RESULTS.BACKDO && fork && fork.includes(backdoDir) ? backdoDir : null;

  const preMovePos = piece.position;
  const trace = tracePath(piece, steps, { backdoDir: dir });
  if (!trace) return { ok: false, reason: 'invalid_move' };
  const opponentId = getNextPlayer(gameState, userId);
  const opponentState = gameState.players?.[opponentId];
  if (!opponentState || !Array.isArray(opponentState.pieces)) return { ok: false, reason: 'invalid_game_state' };

  gameState.pendingMoves.splice(moveIndex, 1);
  const carriedPieces = getCarriedPieces(piece, playerState.pieces);
  let landing = { position: trace.position, lastPos: trace.lastPos, finished: trace.finished };
  let path = trace.path;
  let capturedPieces = [];
  let blockedPieces = [];
  let blockedAt = null;

  if (!trace.finished) {
    const resolvedDefense = defensePct ?? (defenderStats ? yutItemEffects(defenderStats).defensePct : effectsOf(gameState, opponentId).defensePct);
    const candidates = checkCatch(trace.position, opponentState.pieces);
    if (candidates.length > 0) {
      const chance = Math.min(DEFENSE_CAP_PCT, num(resolvedDefense));
      const rolledBlock = chance > 0 && random() * 100 < chance;
      const stop = trace.prev;
      const canStop = stop && stop.position > 0 && checkCatch(stop.position, opponentState.pieces).length === 0;
      if (rolledBlock && canStop) {
        blockedPieces = candidates;
        blockedAt = trace.position;
        landing = { position: stop.position, lastPos: stop.position === preMovePos ? (piece.lastPos ?? 0) : stop.lastPos, finished: false };
        path = trace.path.slice(0, -1);
      } else {
        capturedPieces = capturePieces(trace.position, candidates);
      }
    }
  }
  // 완주한 말은 판 위에 없다: 참먹이(20)에 있는 말을 업거나 잡지 않는다.
  const stackedPieces = landing.position > 0 && !landing.finished
    ? playerState.pieces.filter((c) => !carriedPieces.includes(c) && !c.finished && c.position === landing.position)
    : [];
  applyMoveToPieces(carriedPieces, landing);
  recordCapture(gameState, capturedPieces.length);

  return {
    ok: true,
    piece,
    steps,
    preMovePos,
    backdoDir: dir,
    moveResult: landing,
    path,
    carriedPieces,
    stackedPieces,
    capturedPieces,
    captureBlockedPieces: blockedPieces,
    blockedAt,
    opponentId,
  };
}

/**
 * 이동 한 번(손으로 또는 자동): 판 변화 + 코인 보너스 + 빽도 보너스 + 승리 판정 + 다음 차례.
 * → { ok, won, resolution, itemEffects, discardedBackdo }
 */
export function applyMove(gameState, userId, { pieceId, moveIndex = 0, backdoDir, random = Math.random, auto = false } = {}) {
  if (gameState.winner) return { ok: false, reason: 'game_over' };
  if (!gameState.players?.[userId]) return { ok: false, reason: 'not_in_game' };
  if (gameState.currentTurn !== userId) return { ok: false, reason: 'not_your_turn' };
  if (!Array.isArray(gameState.pendingMoves) || gameState.pendingMoves.length === 0) {
    return { ok: false, reason: 'must_throw_first' };
  }
  const resolution = resolveYutMove(gameState, userId, { pieceId, moveIndex, backdoDir, random });
  if (!resolution.ok) return resolution;
  const effects = effectsOf(gameState, userId);
  const itemEffects = [];
  const captured = resolution.capturedPieces.length;
  if (captured > 0 && effects.catchCoinPer > 0) {
    const added = accrueCoinBonus(gameState, userId, effects.catchCoinPer * captured);
    if (added > 0) itemEffects.push({ player: userId, stat: 'piece_catch_coin_bonus', amount: added });
  }
  if (captured > 0 && effects.catchFlat > 0) {
    const added = accrueCoinBonus(gameState, userId, effects.catchFlat);
    if (added > 0) itemEffects.push({ player: userId, stat: 'yut_catch_bonus', amount: added });
  }
  if (resolution.captureBlockedPieces.length > 0) {
    itemEffects.push({ player: resolution.opponentId, stat: 'yut_capture_protection', amount: resolution.captureBlockedPieces.length });
  }
  // 빽도 보너스: 날빽도(1→참먹이)는 2배, 방(23)에서의 빽도는 그대로의 확률로 한 번 더 던진다.
  if (resolution.steps === YUT_RESULTS.BACKDO && effects.backdoBonusPct > 0) {
    const trigger = resolution.preMovePos === 1 ? effects.backdoBonusPct * 2 : resolution.preMovePos === 23 ? effects.backdoBonusPct : 0;
    if (trigger > 0 && random() * 100 < trigger) {
      gameState.hasBonusThrow = true;
      itemEffects.push({ player: userId, stat: 'yut_backdo_bonus_pct', amount: 0 });
    }
  }

  const won = checkWin(gameState.players[userId]);
  const discardedBackdo = won ? 0 : pruneUnusableBackdo(gameState, userId);
  if (won) {
    gameState.winner = userId;
    gameState.phase = 'finished';
    gameState.pendingMoves = [];
  } else {
    settleTurnAfterMove(gameState, userId);
  }
  gameState.seq = (gameState.seq ?? 0) + 1;
  gameState.lastAction = {
    type: 'move',
    by: userId,
    auto,
    seq: gameState.seq,
    move: {
      moveIndex,
      steps: resolution.steps,
      pieceIds: resolution.carriedPieces.map((p) => p.id),
      from: resolution.preMovePos,
      to: resolution.moveResult.position,
      path: resolution.path,
      finish: resolution.moveResult.finished,
      backdoDir: resolution.backdoDir,
      captured: resolution.capturedPieces.map((p) => p.id),
      capturedPlayer: captured > 0 ? resolution.opponentId : null,
      blocked: resolution.captureBlockedPieces.map((p) => p.id),
      blockedAt: resolution.blockedAt,
      stacked: resolution.stackedPieces.length > 0,
    },
    discardedBackdo,
    itemEffects,
  };
  if (!won && gameState.currentTurn !== userId) {
    gameState.lastAction.turnPassed = true;
    resetYutTurnThrows(gameState);
  }
  return { ok: true, won, resolution, itemEffects, discardedBackdo };
}

/** 두 사람에게 같은 내용을 보낸다(윷놀이는 숨길 정보가 없다). */
export function serializeYutState(gameState, { now = Date.now() } = {}) {
  const players = gameState.playersOrder ?? [];
  const current = gameState.currentTurn ?? null;
  const winner = gameState.winner ?? null;
  return {
    gameId: gameState.gameId ?? gameState.id ?? null,
    seq: gameState.seq ?? 0,
    players,
    pieceCount: gameState.pieceCount ?? DEFAULT_PIECE_COUNT,
    phase: winner ? 'finished' : gameState.phase,
    currentTurn: current,
    starter: gameState.starter ?? null,
    pieces: Object.fromEntries(Object.entries(gameState.players ?? {}).map(([player, state]) => [player, state.pieces ?? []])),
    pendingMoves: gameState.pendingMoves ?? [],
    canThrow: !winner && canThrowNow(gameState),
    hasBonusThrow: gameState.hasBonusThrow ?? false,
    captureBonusThrows: captureBonus(gameState),
    lastThrow: gameState.lastThrow ?? null,
    turnThrows: Array.isArray(gameState.turnThrows) ? gameState.turnThrows : [],
    lastAction: gameState.lastAction ?? null,
    legalMoves: current && !winner && players.includes(current) ? legalMoves(gameState, current) : [],
    characters: gameState.characters ?? {},
    bgm: gameState.bgm ?? null,
    // 낮/밤 화면 테마(서버가 판마다 정한다). 옛 판은 낮.
    theme: gameState.theme === 'night' ? 'night' : 'day',
    stake: gameState.stake ?? 0,
    coinBonus: gameState.coinBonus ?? {},
    coinBonusCap: coinBonusCap(gameState.stake),
    series: gameState.series ?? null,
    equippedItems: gameState.equippedItems ?? {},
    // 이 판에서 실제로 적용되는 아이템 효과(상한을 적용한 값). 화면의 "효과" 칩이 그대로 보여 준다.
    effects: Object.fromEntries(players.map((p) => [p, effectsOf(gameState, p)])),
    // 캐릭터 능력치 1~5(두 사람 모두). 화면의 능력치 막대와 "효과"가 같은 값에서 나온다.
    characterStats: Object.fromEntries(players.map((p) => [p, { ...yutCharacterStats(gameState.characters?.[p]) }])),
    winner,
    turnDeadline: gameState.turnDeadline ?? null,
    turnMs: gameState.turnMs ?? null,
    serverNow: now,
  };
}

/** 옛 이름(game-session 등). */
export const serializeYutGame = (gameState) => serializeYutState(gameState);
