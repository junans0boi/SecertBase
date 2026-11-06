// 윷놀이 아이템 균형(티켓 21, 01-grilling Q6): 한쪽만 아이템을 최대로 껴도 승률 55% 이하.
// 두 사람 모두 서버 자동 이동(autoMove)과 같은 전략으로, 보너스 던지기는 먼저 다 던지고 움직인다.
// 시드를 고정해 언제나 같은 판들을 돌린다(약 6천 판 × 3구성, 수 초).
import assert from 'node:assert/strict';
import test from 'node:test';
import * as Yut from '../src/yut-engine.js';

const GAMES = 6000;
const MAX_ITEMS = {
  yut_control_pct: 15, yut_mo_rate_pct: 8, yut_overturn_pct: 10, yut_backdo_bonus_pct: 25,
  piece_catch_resist_pct: 15, piece_safe_zone_pct: 15,
  yut_win_coin_pct: 15, piece_catch_coin_bonus: 25, yut_catch_bonus: 300,
};

const seeded = (seed) => () => {
  seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

function play(statsA, statsB, starter, random, pieces = 4) {
  const g = Yut.createYutGameState('A', 'B', { pieces, starter });
  g.effects = { A: Yut.yutItemEffects(statsA), B: Yut.yutItemEffects(statsB) };
  g.stake = 1000;
  let throws = 0;
  for (let step = 0; step < 5000; step++) {
    const player = g.currentTurn;
    if (g.phase === 'throwing' || (g.phase === 'moving' && g.hasBonusThrow)) {
      assert.equal(Yut.applyThrow(g, player, { random }).ok, true);
      throws += 1;
      continue;
    }
    const move = Yut.autoMove(g, player);
    assert.ok(move, 'a legal move always exists while moves are pending');
    const r = Yut.applyMove(g, player, { pieceId: move.pieceId, moveIndex: move.moveIndex, backdoDir: move.backdoDir, random });
    assert.equal(r.ok, true, r.reason);
    for (const p of g.playersOrder) assert.ok((g.coinBonus[p] ?? 0) <= 300, 'coin bonus stays under 30% of the stake');
    if (r.won) return { winner: player, throws };
  }
  throw new Error('game did not end');
}

function winRate(statsA, statsB, { seed = 2026, pieces = 4 } = {}) {
  const random = seeded(seed);
  let wins = 0;
  let throws = 0;
  for (let i = 0; i < GAMES; i++) {
    // 선공은 번갈아(선공 이점이 섞이지 않게).
    const r = play(statsA, statsB, i % 2 ? 'A' : 'B', random, pieces);
    if (r.winner === 'A') wins += 1;
    throws += r.throws;
  }
  return { rate: wins / GAMES, throws: throws / GAMES };
}

test('balance: even loadouts are a coin flip', () => {
  const { rate, throws } = winRate({}, {});
  assert.ok(Math.abs(rate - 0.5) < 0.025, `even win rate ${(rate * 100).toFixed(2)}%`);
  assert.ok(throws > 50 && throws < 90, `about ${throws.toFixed(1)} throws per game`);
});

test('balance: one side with every yut item maxed wins at most 55%', () => {
  const { rate } = winRate(MAX_ITEMS, {});
  assert.ok(rate <= 0.55, `max-item win rate ${(rate * 100).toFixed(2)}% must be ≤ 55%`);
  assert.ok(rate > 0.5, 'items still help a little');
});

test('balance: the capped defense alone stays within the same band', () => {
  const { rate } = winRate({}, { piece_catch_resist_pct: 15, piece_safe_zone_pct: 15 });
  assert.ok(rate >= 0.45, `attacker vs max defense ${(rate * 100).toFixed(2)}%`);
});

test('balance: a two-piece game is a short, fair game', () => {
  const { rate, throws } = winRate({}, {}, { pieces: 2, seed: 7 });
  assert.ok(Math.abs(rate - 0.5) < 0.03, `2-piece win rate ${(rate * 100).toFixed(2)}%`);
  assert.ok(throws < 40, `2-piece games are about half as long (${throws.toFixed(1)} throws)`);
});
