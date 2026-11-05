// 패널티킥 2.0 엔진(순수 함수). 시간·무작위는 주입받는다.
//
// 칸: 방장이 로비에서 3칸 또는 6칸을 고른다(01-grilling Q37 v2).
//   3칸: 0 왼쪽 · 1 가운데 · 2 오른쪽
//   6칸: 3열 × 2행 — 0~2 위(왼·가운데·오른), 3~5 아래
// 키커와 키퍼가 동시에 고르고 같은 칸이면 선방. 5킥씩 찬 뒤 동점이면 서든데스
// (3칸 최대 5쌍, 6칸 최대 10쌍), 그래도 같으면 무승부.

export const MAX_KICKS_PER_PLAYER = 5;
export const PENALTY_CELLS = Object.freeze([3, 6]);
export const DEFAULT_CELLS = 3;
/** 칸 수별 서든데스 최대 쌍 수. 6칸을 5쌍으로 두면 최종 무승부가 6.9%라서 10쌍. */
export const SUDDEN_DEATH_PAIRS_BY_CELLS = Object.freeze({ 3: 5, 6: 10 });
/** 한 번 고르는 시간. */
export const PENALTY_TURN_MS = 20_000;
/** 판정 뒤 연출(공 비행·반응)을 보는 동안은 시계가 돌지 않게 주는 여유. */
export const PENALTY_REVEAL_MS = 2_500;
/** 같은 사람이 연속으로 이만큼 자동 선택되면 기권. */
export const AUTO_PICK_FORFEIT = 3;

export const isValidCells = (cells) => PENALTY_CELLS.includes(cells);
export const normalizeCells = (cells) => (isValidCells(cells) ? cells : DEFAULT_CELLS);
export const suddenDeathPairs = (cells) => SUDDEN_DEATH_PAIRS_BY_CELLS[normalizeCells(cells)];

/** 0 ≤ choice < cells 인 정수만. */
export function isValidChoice(cells, choice) {
  return Number.isInteger(choice) && choice >= 0 && choice < normalizeCells(cells);
}

const pickCell = (cells, random) => Math.min(cells - 1, Math.floor(random() * cells));

/**
 * 새 판. 첫 킥커는 무작위(firstKicker를 주면 그 사람). 첫 마감은 startsAt + 20초.
 * options: { cells, random, gameId, firstKicker, startsAt, now, series }
 */
export function initPenaltyGame(player1Id, player2Id, options = {}) {
  const {
    cells = DEFAULT_CELLS,
    random = Math.random,
    gameId = null,
    firstKicker = null,
    now = Date.now(),
    startsAt = now,
    series = null,
  } = options;
  const p1 = String(player1Id);
  const p2 = String(player2Id);
  const first = firstKicker === p1 || firstKicker === p2 ? firstKicker : random() < 0.5 ? p1 : p2;
  return {
    gameId,
    status: "playing",
    cells: normalizeCells(cells),
    players: [p1, p2],
    firstKicker: first,
    round: 1,
    kicker: first,
    keeper: first === p1 ? p2 : p1,
    submissions: {},
    scores: { [p1]: 0, [p2]: 0 },
    rounds: [],
    suddenDeath: false,
    autoPicks: { [p1]: 0, [p2]: 0 },
    turnDeadline: startsAt + PENALTY_TURN_MS,
    series,
    result: null,
  };
}

function countKicks(rounds, playerId) {
  return rounds.reduce((count, round) => count + (String(round.kicker) === String(playerId) ? 1 : 0), 0);
}

function findWinner(game, scores, rounds) {
  const [player1, player2] = game.players ?? Object.keys(scores);
  const score1 = scores[player1] || 0;
  const score2 = scores[player2] || 0;
  const regulation = MAX_KICKS_PER_PLAYER * 2;

  if (rounds.length >= regulation) {
    // 서든데스: 두 사람이 한 번씩 찬 뒤(짝수 킥)에만 판정한다.
    if (rounds.length % 2 !== 0) return null;
    if (score1 > score2) return player1;
    if (score2 > score1) return player2;
    return rounds.length >= regulation + suddenDeathPairs(game.cells) * 2 ? "draw" : null;
  }

  const remaining1 = MAX_KICKS_PER_PLAYER - countKicks(rounds, player1);
  const remaining2 = MAX_KICKS_PER_PLAYER - countKicks(rounds, player2);
  // 뒤진 사람이 남은 킥을 다 넣어도 따라잡지 못하면 바로 끝난다.
  if (score1 > score2 && score2 + remaining2 < score1) return player1;
  if (score2 > score1 && score1 + remaining1 < score2) return player2;
  return null;
}

/** 한 킥 판정. auto = { kicker, keeper } 자동 선택 여부(기록용). */
export function resolvePenaltyRound(game, kickerDir, keeperDir, { now = Date.now(), auto = {} } = {}) {
  if (!game || game.status !== "playing") return game;

  const kickerId = String(game.kicker);
  const keeperId = String(game.keeper);
  const isGoal = kickerDir !== keeperDir;
  const scores = { ...game.scores };
  if (isGoal) scores[kickerId] = (scores[kickerId] || 0) + 1;

  const rounds = [
    ...(game.rounds || []),
    {
      round: game.round,
      kicker: kickerId,
      keeper: keeperId,
      kickerDir,
      keeperDir,
      isGoal,
      autoKicker: Boolean(auto.kicker),
      autoKeeper: Boolean(auto.keeper),
    },
  ];
  const winner = findWinner(game, scores, rounds);

  if (winner) {
    return {
      ...game,
      status: "finished",
      scores,
      rounds,
      submissions: {},
      turnDeadline: null,
      result: { winner, scores, reason: winner === "draw" ? "draw" : "score" },
    };
  }

  return {
    ...game,
    round: game.round + 1,
    suddenDeath: rounds.length >= MAX_KICKS_PER_PLAYER * 2,
    kicker: keeperId,
    keeper: kickerId,
    submissions: {},
    scores,
    rounds,
    turnDeadline: now + PENALTY_REVEAL_MS + PENALTY_TURN_MS,
  };
}

const bothSubmitted = (game) =>
  game.submissions[game.kicker] !== undefined && game.submissions[game.keeper] !== undefined;

function resolveIfReady(game, now) {
  if (!bothSubmitted(game)) return game;
  const auto = game.autoSubmitted ?? {};
  const { autoSubmitted: _ignored, ...rest } = game;
  return resolvePenaltyRound(rest, game.submissions[game.kicker], game.submissions[game.keeper], {
    now,
    auto: { kicker: Boolean(auto[game.kicker]), keeper: Boolean(auto[game.keeper]) },
  });
}

/**
 * 플레이어의 직접 선택. 둘 다 냈으면 바로 판정한다.
 * → { ok: true, game, resolved } | { ok: false, reason }
 */
export function submitPenaltyChoice(game, playerId, choice, { now = Date.now() } = {}) {
  if (!game) return { ok: false, reason: "no_game" };
  if (game.status !== "playing") return { ok: false, reason: "finished" };
  const uid = String(playerId);
  if (uid !== String(game.kicker) && uid !== String(game.keeper)) return { ok: false, reason: "not_a_player" };
  if (!isValidChoice(game.cells, choice)) return { ok: false, reason: "invalid_choice" };
  if (game.submissions?.[uid] !== undefined) return { ok: false, reason: "already_submitted" };

  const next = {
    ...game,
    submissions: { ...game.submissions, [uid]: choice },
    // 직접 고르면 연속 자동 선택 횟수가 0으로 돌아간다.
    autoPicks: { ...game.autoPicks, [uid]: 0 },
  };
  const resolved = resolveIfReady(next, now);
  return { ok: true, game: resolved, resolved: resolved.round !== game.round || resolved.status !== "playing" };
}

/**
 * 마감 시각이 지났을 때: 아직 안 낸 사람의 칸을 무작위로 채워 판정한다.
 * 연속 자동 선택이 AUTO_PICK_FORFEIT에 닿으면 판정 대신 기권으로 끝낸다
 * (둘 다 닿으면 기록 없이 무승부로 정리).
 * → { game, autoPicked: [ids], forfeitBy: id | null, abandoned: boolean }
 */
export function autoPickMissing(game, { random = Math.random, now = Date.now() } = {}) {
  if (!game || game.status !== "playing") return { game, autoPicked: [], forfeitBy: null, abandoned: false };
  const missing = [String(game.kicker), String(game.keeper)].filter((p) => game.submissions?.[p] === undefined);
  if (missing.length === 0) return { game: resolveIfReady(game, now), autoPicked: [], forfeitBy: null, abandoned: false };

  const autoPicks = { ...game.autoPicks };
  for (const p of missing) autoPicks[p] = (autoPicks[p] ?? 0) + 1;
  const idle = missing.filter((p) => autoPicks[p] >= AUTO_PICK_FORFEIT);
  if (idle.length === 2) {
    return {
      game: finishPenalty({ ...game, autoPicks }, { winner: "draw", reason: "abandoned" }),
      autoPicked: missing,
      forfeitBy: null,
      abandoned: true,
    };
  }
  if (idle.length === 1) {
    return { game: forfeitPenalty({ ...game, autoPicks }, idle[0]), autoPicked: missing, forfeitBy: idle[0], abandoned: false };
  }

  const submissions = { ...game.submissions };
  const autoSubmitted = {};
  for (const p of missing) {
    submissions[p] = pickCell(game.cells, random);
    autoSubmitted[p] = true;
  }
  return {
    game: resolveIfReady({ ...game, submissions, autoPicks, autoSubmitted }, now),
    autoPicked: missing,
    forfeitBy: null,
    abandoned: false,
  };
}

function finishPenalty(game, { winner, loser = null, reason }) {
  return {
    ...game,
    status: "finished",
    submissions: {},
    turnDeadline: null,
    result: { winner, ...(loser ? { loser } : {}), scores: game.scores, reason },
  };
}

/** loser의 기권으로 끝낸다(잠수·연속 자동 선택). */
export function forfeitPenalty(game, loser, reason = "forfeit") {
  const winner = (game.players ?? Object.keys(game.scores ?? {})).find((p) => p !== String(loser)) ?? null;
  return finishPenalty(game, { winner, loser: String(loser), reason });
}

/** 공개 상태: 판정 전 제출값은 "냈는지(true)"만. */
export function maskPenaltyState(game) {
  if (!game) return null;
  const { autoSubmitted: _hidden, ...rest } = game;
  return {
    ...rest,
    submissions: Object.fromEntries(Object.keys(game.submissions ?? {}).map((uid) => [uid, true])),
  };
}

/** 옛 형식(9칸 시절 `cells` 없음, 범위 밖 선택) 상태인지. 복원 때 정리한다. */
export function isLegacyPenaltyState(game) {
  if (!game || typeof game !== "object") return true;
  if (!isValidCells(game.cells)) return true;
  if (!Array.isArray(game.players) || game.players.length !== 2) return true;
  const inRange = (v) => v === undefined || isValidChoice(game.cells, v);
  if (Object.values(game.submissions ?? {}).some((v) => !inRange(v))) return true;
  return (game.rounds ?? []).some((r) => !inRange(r.kickerDir) || !inRange(r.keeperDir));
}
