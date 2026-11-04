// bowling-sim.js — 클라이언트 bowling_screen.dart의 결정론적 투구 시뮬레이션 이식본.
// 서버가 같은 (서 있는 핀, aim, curve)로 같은 결과를 계산하므로, 서버 점수와
// 클라이언트 연출이 정확히 일치한다. 상수·연산 순서를 Dart 쪽과 동일하게 유지할 것.

const PIN_X = [0.0, -0.15, 0.15, -0.30, 0.0, 0.30, -0.45, -0.15, 0.15, 0.45];
const PIN_T = [0.86, 0.90, 0.90, 0.94, 0.94, 0.94, 0.98, 0.98, 0.98, 0.98];
const PIN_BEHIND = { 0: [1, 2], 1: [3, 4], 2: [4, 5], 3: [6, 7], 4: [7, 8], 5: [8, 9] };

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

export function trajX(aim, curve, t) {
  const endX = clamp(aim * 0.8 + curve * 0.5, -1.15, 1.15);
  const ctrlX = aim * 0.8 - curve * 0.55;
  const u = 1 - t;
  return 2 * u * t * ctrlX + t * t * endX;
}

const sign = (v) => (v > 0 ? 1 : v < 0 ? -1 : 0);

/** standing: 10개 boolean. 반환: { knocked: number[], pinsDown, gutter } */
export function simulateRoll(standing, aim, curve) {
  for (let t = 0.05; t < 0.85; t += 0.01) {
    if (Math.abs(trajX(aim, curve, t)) > 0.97) return { knocked: [], pinsDown: 0, gutter: true };
  }
  const knocked = [];
  const down = new Array(10).fill(false);

  const fall = (pin, dir, strength) => {
    if (down[pin]) return;
    down[pin] = true;
    if (standing[pin]) knocked.push(pin);
    const children = PIN_BEHIND[pin];
    if (!children || strength < 0.45) return;
    const next = strength * 0.8;
    if (dir === 0) {
      fall(children[0], -1, 0.35);
      fall(children[1], 1, 0.35);
    } else {
      fall(dir < 0 ? children[0] : children[1], dir, next);
    }
  };

  for (let i = 0; i < 10; i++) {
    if (down[i]) continue;
    const bx = trajX(aim, curve, PIN_T[i]);
    const dx = PIN_X[i] - bx;
    if (Math.abs(dx) >= 0.10) continue;
    if (i === 0 && Math.abs(dx) >= 0.045) {
      down[0] = true;
      if (standing[0]) knocked.push(0);
      fall(1, -1, 0.62);
      fall(2, 1, 0.62);
    } else if (Math.abs(dx) < 0.05) {
      fall(i, 0, 1.0);
    } else {
      fall(i, sign(dx), 1.0);
    }
  }
  return { knocked, pinsDown: knocked.length, gutter: false };
}

/**
 * 현재 프레임의 서 있는 핀을 서버 history(aim/curve)로 재구성한다.
 * ctx: nextRollContext 결과. history 항목: { playerId, rollIndex, aim, curve }.
 * 재구성이 불가능하면(과거 데이터) 개수만 맞춘 표준 배치로 대체한다.
 */
const CANONICAL_KNOCK_ORDER = [0, 1, 2, 4, 3, 5, 7, 8, 6, 9];
export function standingDeck(rolls, ctx, history, playerId) {
  if (!ctx || ctx.rollInFrame === 0) return new Array(10).fill(true);
  const frameStart = rolls.length - ctx.rollInFrame;
  let deck = new Array(10).fill(true);
  let replayOk = true;
  for (let k = frameStart; k < rolls.length; k++) {
    const meta = (history ?? []).find((h) => String(h.playerId) === String(playerId) && h.rollIndex === k);
    if (!meta) { replayOk = false; break; }
    const sim = simulateRoll(deck, Number(meta.aim) || 0, Number(meta.curve) || 0);
    for (const pin of sim.knocked) deck[pin] = false;
    if (!deck.includes(true)) deck = new Array(10).fill(true);
  }
  if (replayOk && deck.filter(Boolean).length === ctx.standing) return deck;
  deck = new Array(10).fill(true);
  let toKnock = 10 - ctx.standing;
  for (const p of CANONICAL_KNOCK_ORDER) {
    if (toKnock === 0) break;
    deck[p] = false;
    toKnock--;
  }
  return deck;
}

/** 손 떨림: 조준이 완벽해도 결과가 매번 같지 않도록 작은 흔들림을 더한다. */
export const BOWLING_JITTER = 0.035;
export function jitterThrow(aim, curve, random = Math.random) {
  const j = () => (random() * 2 - 1) * BOWLING_JITTER;
  const round3 = (v) => Math.round(v * 1000) / 1000;
  return {
    aim: round3(clamp(aim + j(), -1, 1)),
    curve: round3(clamp(curve + j(), -1, 1)),
  };
}
