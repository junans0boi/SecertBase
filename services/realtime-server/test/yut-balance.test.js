// 윷놀이 균형(티켓 21·27): 캐릭터 능력치 + 윷 스킨 효과를 합쳐도 승률이 기울지 않는다.
//  - 캐릭터끼리(기본 윷): 모든 조합 45~55%
//  - 가장 강한 구성(캐릭터 + 스킨 아무거나) vs 맨 구성: ≤ 55%
//  - 이론상 상한(모든 효과를 상한까지) vs 맨 구성: ≤ 55%
// 두 사람 모두 서버 자동 이동(autoMove)과 같은 전략. 시드를 고정해 언제나 같은 판들을 돌린다.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import * as Yut from '../src/yut-engine.js';

const CHARACTERS = Object.keys(Yut.YUT_CHARACTER_STATS);
const GAMES = 6000;
const SKIN_GAMES = 2500;

// 새 윷 스킨의 효과는 마이그레이션 SQL에서 그대로 읽는다(카탈로그와 균형 테스트가 어긋날 수 없게).
function readSkinCatalog() {
  const sql = readFileSync(new URL('../migrations/0049_yut_system.sql', import.meta.url), 'utf8');
  const skins = new Map();
  for (const m of sql.matchAll(/\((11\d), 'skin', 'yut', 'yut_yut', '(\w+)',\s+'([^']+)'/g)) {
    skins.set(Number(m[1]), { id: Number(m[1]), grade: m[2], name: m[3], stats: {} });
  }
  const statBlock = sql.slice(sql.indexOf('INSERT INTO item_stats'));
  for (const m of statBlock.matchAll(/\((11\d), '(\w+)',\s+([\d.]+)\)/g)) {
    skins.get(Number(m[1])).stats[m[2]] = Number(m[3]);
  }
  return [...skins.values()];
}

const seeded = (seed) => () => {
  seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

function play(effectsA, effectsB, starter, random, pieces = 4, stake = 1000) {
  const g = Yut.createYutGameState('A', 'B', { pieces, starter });
  g.effects = { A: effectsA, B: effectsB };
  g.stake = stake;
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

function winRate(effectsA, effectsB, { seed = 2026, pieces = 4, games = GAMES } = {}) {
  const random = seeded(seed);
  let wins = 0;
  let throws = 0;
  for (let i = 0; i < games; i++) {
    const r = play(effectsA, effectsB, i % 2 ? 'A' : 'B', random, pieces); // 선공을 번갈아
    if (r.winner === 'A') wins += 1;
    throws += r.throws;
  }
  return { rate: wins / games, throws: throws / games };
}

const fx = (stats, character) => Yut.yutItemEffects(stats, character);

test('balance: equal loadouts are a coin flip and a game takes about as long as ever', () => {
  const { rate, throws } = winRate(fx({}), fx({}));
  assert.ok(Math.abs(rate - 0.5) < 0.025, `even win rate ${(rate * 100).toFixed(2)}%`);
  assert.ok(throws > 50 && throws < 90, `about ${throws.toFixed(1)} throws per game`);
});

test('balance: every character matchup with plain sticks stays within 45–55%', () => {
  for (const a of CHARACTERS) {
    for (const b of CHARACTERS) {
      if (a === b) continue; // 한 판에서 같은 캐릭터는 없다
      const { rate } = winRate(fx({}, a), fx({}, b), { seed: 11 });
      assert.ok(rate >= 0.45 && rate <= 0.55, `${a} vs ${b}: ${(rate * 100).toFixed(1)}%`);
    }
  }
});

test('balance: the strongest real loadout (any character + any yut skin) wins at most 55%', () => {
  const skins = readSkinCatalog();
  assert.equal(skins.length, 9, 'the catalog has nine purchasable skins');
  let worst = { rate: 0, label: '' };
  for (const skin of skins) {
    for (const mine of CHARACTERS) {
      for (const theirs of CHARACTERS) {
        if (mine === theirs) continue;
        const { rate } = winRate(fx(skin.stats, mine), fx({}, theirs), { games: SKIN_GAMES, seed: 5 + skin.id });
        if (rate > worst.rate) worst = { rate, label: `${mine}+${skin.name} vs ${theirs}` };
      }
    }
  }
  assert.ok(worst.rate <= 0.55, `${worst.label}: ${(worst.rate * 100).toFixed(1)}% must be ≤ 55%`);
  assert.ok(worst.rate > 0.5, 'a skin still helps a little');
});

test('balance: even with every effect at its hard cap the edge stays within 55%', () => {
  const CAPPED = {
    yut_control_pct: 15, yut_mo_rate_pct: 8, yut_overturn_pct: 10, yut_backdo_bonus_pct: 25, yut_backdo_shield_pct: 25,
    piece_catch_resist_pct: 15, piece_safe_zone_pct: 15, yut_win_coin_pct: 15, piece_catch_coin_bonus: 25, yut_catch_bonus: 300,
  };
  for (const mine of CHARACTERS) {
    for (const theirs of CHARACTERS) {
      if (mine === theirs) continue;
      const { rate } = winRate(fx(CAPPED, mine), fx({}, theirs), { seed: 31 });
      assert.ok(rate <= 0.55, `${mine} capped vs plain ${theirs}: ${(rate * 100).toFixed(1)}%`);
    }
  }
});

test('balance: a two-piece game is a short, fair game', () => {
  const { rate, throws } = winRate(fx({}), fx({}), { pieces: 2, seed: 7 });
  assert.ok(Math.abs(rate - 0.5) < 0.03, `2-piece win rate ${(rate * 100).toFixed(2)}%`);
  assert.ok(throws < 40, `2-piece games are about half as long (${throws.toFixed(1)} throws)`);
});
