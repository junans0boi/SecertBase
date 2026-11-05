// 제로 2.0 엔진(순수 함수). 두 사람이 동시에 손가락 0~5개와 합계 예측을 낸다.
// 예측은 (내 숫자) ~ (내 숫자 + 5)만 허용한다(그보다 작거나 큰 합계는 나올 수 없다).
// 정확히 맞히면 2점(둘 다 맞히면 각 2점), 둘 다 못 맞히면 합계에 더 가까운 쪽 1점,
// 같은 거리면 0점. 5라운드 합산, 동점이면 한 라운드씩 서든데스(최대 SUDDEN_DEATH_CAP).
// 근거: docs/plans/game-renewal-2026-11/01-grilling.md Q28~Q29.

export const ZERO_MAX_FINGERS = 5;
export const ZERO_REGULATION_ROUNDS = 5;
export const ZERO_SUDDEN_DEATH_CAP = 5;
export const ZERO_EXACT_POINTS = 2;
export const ZERO_CLOSER_POINTS = 1;

const isInt = (v) => Number.isInteger(v);

/** 이 사람이 고를 수 있는 예측 범위 [min, max]. */
export function guessRange(fingers) {
  return { min: fingers, max: fingers + ZERO_MAX_FINGERS };
}

/** 'ok' | 'invalid_fingers' | 'invalid_guess' */
export function validateZeroPick(pick) {
  const fingers = pick?.fingers;
  const guess = pick?.guess;
  if (!isInt(fingers) || fingers < 0 || fingers > ZERO_MAX_FINGERS) return "invalid_fingers";
  const { min, max } = guessRange(fingers);
  if (!isInt(guess) || guess < min || guess > max) return "invalid_guess";
  return "ok";
}

/**
 * 한 라운드 판정.
 * → { total, distance:[d1,d2], exact:[b1,b2], points:[p1,p2], roundWinner:'p1'|'p2'|'draw' }
 */
export function resolveZeroRound(pick1, pick2) {
  const total = pick1.fingers + pick2.fingers;
  const distance = [Math.abs(pick1.guess - total), Math.abs(pick2.guess - total)];
  const exact = [distance[0] === 0, distance[1] === 0];
  let points;
  if (exact[0] || exact[1]) {
    points = [exact[0] ? ZERO_EXACT_POINTS : 0, exact[1] ? ZERO_EXACT_POINTS : 0];
  } else if (distance[0] < distance[1]) {
    points = [ZERO_CLOSER_POINTS, 0];
  } else if (distance[1] < distance[0]) {
    points = [0, ZERO_CLOSER_POINTS];
  } else {
    points = [0, 0];
  }
  const roundWinner = points[0] > points[1] ? "p1" : points[1] > points[0] ? "p2" : "draw";
  return { total, distance, exact, points, roundWinner };
}

/** 새 판의 진행 상태(점수판). */
export function createZeroMatch() {
  return {
    round: 1,
    scores: [0, 0],
    suddenDeath: false,
    suddenDeathRounds: 0,
    finished: false,
    winner: null, // 'p1' | 'p2' | 'draw' | null
    reason: null, // 'score' | 'sudden_death' | 'draw_cap'
  };
}

/**
 * 판정된 라운드를 점수판에 더한다(새 객체를 돌려준다).
 * 5라운드가 끝나 점수가 다르면 종료, 같으면 서든데스. 서든데스는 그 라운드에서 점수가
 * 갈리면 종료, SUDDEN_DEATH_CAP 라운드 동안 안 갈리면 무승부.
 */
export function applyZeroRound(match, result) {
  const scores = [match.scores[0] + result.points[0], match.scores[1] + result.points[1]];
  const next = { ...match, scores, round: match.round + 1 };
  const leader = scores[0] > scores[1] ? "p1" : scores[1] > scores[0] ? "p2" : null;
  if (match.suddenDeath) {
    next.suddenDeathRounds = match.suddenDeathRounds + 1;
    if (leader) return { ...next, finished: true, winner: leader, reason: "sudden_death" };
    if (next.suddenDeathRounds >= ZERO_SUDDEN_DEATH_CAP) {
      return { ...next, finished: true, winner: "draw", reason: "draw_cap" };
    }
    return next;
  }
  if (match.round >= ZERO_REGULATION_ROUNDS) {
    if (leader) return { ...next, finished: true, winner: leader, reason: "score" };
    return { ...next, suddenDeath: true };
  }
  return next;
}

/** 무작위 손: 숫자 0~5, 예측은 허용 범위 안에서 무작위. 자동 선택에도 쓴다. */
export function randomZeroPick(random = Math.random) {
  const fingers = Math.floor(random() * (ZERO_MAX_FINGERS + 1));
  const guess = fingers + Math.floor(random() * (ZERO_MAX_FINGERS + 1));
  return { fingers, guess };
}

/** 합리적인 손: 숫자 0~5 무작위, 예측은 내 숫자 + 2 또는 3(상대 기대값 2.5). */
export function smartZeroPick(random = Math.random) {
  const fingers = Math.floor(random() * (ZERO_MAX_FINGERS + 1));
  return { fingers, guess: fingers + (random() < 0.5 ? 2 : 3) };
}
