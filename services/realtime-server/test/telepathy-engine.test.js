// 텔레파시 2.0 엔진: 문제 은행 검증, 셔플 가방(분야 상한·매운맛 끄기·재셔플·최근 50개 뒤로),
// 연속 32판 무반복, 판정·요약·등급·시리즈.
import assert from 'node:assert/strict';
import test from 'node:test';
import {
  TELEPATHY_BANK,
  TELEPATHY_CATEGORIES,
  TELEPATHY_OPTION_MAX,
  TELEPATHY_RECENT_LIMIT,
  applyTelepathySeries,
  drawQuestions,
  emptyBag,
  judge,
  refillOrder,
  summary,
  tierFor,
  validateTelepathyBank,
} from '../src/telepathy-engine.js';

/** 재현 가능한 무작위(LCG). */
function seeded(seed) {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

/** 순한 분야 + 살짝 매운맛 = 옛 320문제(19+ 제외). */
const BANK320 = TELEPATHY_BANK.filter((q) => q.heat !== 'nuclear');

const sample = (over = {}) => ({ id: 'food-001', cat: 'food', a: '짜장면', b: '짬뽕', emojiA: '🥢', emojiB: '🌶️', heat: 'mild', spicy: false, ...over });

test('the bank has 320 regular questions (8 categories x 40) plus 100+ nuclear ones, with stable ids', () => {
  assert.equal(BANK320.length, 320);
  assert.equal(TELEPATHY_CATEGORIES.length, 9);
  for (const { id } of TELEPATHY_CATEGORIES.filter((c) => c.id !== 'nuclear')) {
    const list = TELEPATHY_BANK.filter((q) => q.cat === id);
    assert.equal(list.length, 40, id);
    assert.deepEqual(list.map((q) => q.id), list.map((_, i) => `${id}-${String(i + 1).padStart(3, '0')}`));
  }
  const nuclear = TELEPATHY_BANK.filter((q) => q.cat === 'nuclear');
  assert.ok(nuclear.length >= 100, `nuclear count ${nuclear.length}`);
  assert.deepEqual(nuclear.map((q) => q.id), nuclear.map((_, i) => `nuc-${String(i + 1).padStart(3, '0')}`));
  assert.ok(nuclear.every((q) => q.heat === 'nuclear' && q.spicy === true));
  assert.equal(TELEPATHY_BANK.filter((q) => q.heat === 'spicy').length, 40);
  assert.ok(TELEPATHY_BANK.filter((q) => q.heat === 'mild').every((q) => q.spicy === false));
  assert.equal(new Set(TELEPATHY_BANK.map((q) => q.id)).size, TELEPATHY_BANK.length);
});

test('the question bank never names the 19+ level or uses off-limits subjects', () => {
  // 가이드라인: 성인 커플 사이의 장난만. 미성년·가족·동의 없음·폭력·동물·비하 표현은 은행에 없다.
  const banned = /교복|학생|미성년|아기|엄마|아빠|부모|가족|형제|동생|누나|언니|오빠|강제|억지|때리|폭력|묶|짐승|걸레|변태|바보|멍청/;
  for (const q of TELEPATHY_BANK.filter((x) => x.heat === 'nuclear')) {
    for (const text of [q.a, q.b]) {
      assert.doesNotMatch(text, banned, `${q.id}: ${text}`);
      assert.doesNotMatch(text, /핵|nuclear/i, `${q.id}: the level name stays out of questions`);
    }
  }
});

test('every option is Korean only, at most 14 characters and never repeated anywhere in the bank', () => {
  const seen = new Map();
  for (const q of TELEPATHY_BANK) {
    for (const text of [q.a, q.b]) {
      assert.ok([...text].length <= TELEPATHY_OPTION_MAX, `${q.id}: ${text}`);
      assert.match(text, /^[가-힣0-9 ·,.?!~%()-]+$/, `${q.id}: ${text}`);
      assert.doesNotMatch(text, /[A-Za-z]/, `${q.id}: no English`);
      assert.ok(!seen.has(text), `${q.id} repeats "${text}" from ${seen.get(text)}`);
      seen.set(text, q.id);
    }
    assert.ok(q.emojiA && q.emojiB, `${q.id}: emoji`);
  }
});

test('validation rejects duplicates, long or non-Korean options and mislabelled spicy questions', () => {
  assert.doesNotThrow(() => validateTelepathyBank([sample()]));
  const bad = (list, pattern) => assert.throws(() => validateTelepathyBank(list), pattern);
  bad([], /non-empty/);
  bad([sample(), sample({ a: '피자', b: '치킨' })], /duplicate id/);
  bad([sample(), sample({ id: 'food-002', a: '짬뽕', b: '짜장면' })], /duplicate question/);
  bad([sample({ a: '가나다라마바사아자차카타파하거' })], /longer than 14/);
  bad([sample({ a: '피자 pizza' })], /Korean only/);
  bad([sample({ b: '😀' })], /Korean only/);
  bad([sample({ a: '짬뽕' })], /same/);
  bad([sample({ cat: 'snack', id: 'snack-001' })], /unknown cat/);
  bad([sample({ id: 'date-001' })], /prefix/);
  bad([sample({ heat: 'spicy' })], /spicy/);
  bad([sample({ id: 'spicy-001', cat: 'spicy', spicy: false })], /spicy/);
  bad([sample({ emojiA: '' })], /emojiA/);
  bad([sample({ emojiB: 'B' })], /emojiB/);
});

test('a draw takes at most two per category, never repeats inside a game and skips spicy when off', () => {
  for (let seed = 1; seed <= 50; seed++) {
    const { questions, bag } = drawQuestions(emptyBag(), BANK320, 10, { heat: 'mild', random: seeded(seed) });
    assert.equal(questions.length, 10);
    assert.equal(new Set(questions.map((q) => q.id)).size, 10);
    assert.ok(questions.every((q) => !q.spicy));
    const perCat = Object.groupBy(questions, (q) => q.cat);
    assert.ok(Object.values(perCat).every((list) => list.length <= 2), `seed ${seed}`);
    assert.equal(bag.order.length, 310, 'drawn ids leave the bag');
    assert.deepEqual(bag.recent, bag.recent.filter((id) => questions.some((q) => q.id === id)));
  }
});

test('the draw does not mutate the stored bag', () => {
  const bag = { order: TELEPATHY_BANK.map((q) => q.id), recent: [], refills: 0 };
  const copy = structuredClone(bag);
  drawQuestions(bag, BANK320, 10, { heat: 'spicy', random: seeded(3) });
  assert.deepEqual(bag, copy);
});

test('32 games of 10 in a row never repeat a question (spicy on uses the whole bank)', () => {
  for (const seed of [1, 7, 42, 2026, 99_991]) {
    let bag = emptyBag();
    const seen = new Set();
    for (let game = 0; game < 32; game++) {
      const drawn = drawQuestions(bag, BANK320, 10, { heat: 'spicy', random: seeded(seed) });
      bag = drawn.bag;
      assert.equal(drawn.questions.length, 10);
      for (const q of drawn.questions) {
        assert.ok(!seen.has(q.id), `seed ${seed}: ${q.id} repeated in game ${game + 1}`);
        seen.add(q.id);
      }
    }
    assert.equal(seen.size, 320);
    assert.equal(bag.refills, 1, 'only the very first fill so far');
  }
});

test('with spicy off the 280 regular questions last 28 games without a repeat', () => {
  let bag = emptyBag();
  const seen = new Set();
  const random = seeded(5);
  for (let game = 0; game < 28; game++) {
    const drawn = drawQuestions(bag, BANK320, 10, { heat: 'mild', random });
    bag = drawn.bag;
    for (const q of drawn.questions) {
      assert.ok(!q.spicy);
      assert.ok(!seen.has(q.id), `${q.id} repeated in game ${game + 1}`);
      seen.add(q.id);
    }
  }
  assert.equal(seen.size, 280);
});

test('15 questions with spicy off still fill the game by allowing a third per category', () => {
  const { questions } = drawQuestions(emptyBag(), BANK320, 15, { heat: 'mild', random: seeded(8) });
  assert.equal(questions.length, 15);
  const counts = Object.values(Object.groupBy(questions, (q) => q.cat)).map((l) => l.length);
  assert.ok(Math.max(...counts) <= 3);
  const on = drawQuestions(emptyBag(), BANK320, 15, { heat: 'spicy', random: seeded(8) }).questions;
  assert.ok(Object.values(Object.groupBy(on, (q) => q.cat)).every((l) => l.length <= 2));
});

test('an exhausted bag is reshuffled with the latest 50 questions pushed to the back', () => {
  let bag = emptyBag();
  const random = seeded(11);
  const history = [];
  for (let game = 0; game < 32; game++) {
    const drawn = drawQuestions(bag, BANK320, 10, { heat: 'spicy', random });
    bag = drawn.bag;
    history.push(...drawn.questions.map((q) => q.id));
  }
  assert.equal(bag.order.length, 0);
  const recent50 = history.slice(-TELEPATHY_RECENT_LIMIT);
  assert.deepEqual(bag.recent, recent50);
  const next = drawQuestions(bag, BANK320, 10, { heat: 'spicy', random });
  assert.equal(next.bag.refills, 2);
  assert.ok(next.questions.every((q) => !recent50.includes(q.id)), 'recent questions do not come straight back');
  // 새 가방: 앞 270개에는 최근 50개가 없고, 맨 뒤 50개가 최근 문제(오래된 순)다.
  const order = refillOrder(BANK320, recent50, seeded(4));
  assert.equal(order.length, 320);
  assert.equal(new Set(order).size, 320);
  assert.deepEqual(order.slice(-50), recent50);
  assert.ok(order.slice(0, 270).every((id) => !recent50.includes(id)));
});

test('a partly used bag tops up from a fresh shuffle without repeating inside the game', () => {
  const keep = TELEPATHY_BANK.filter((q) => q.cat === 'food').slice(0, 3).map((q) => q.id);
  const bag = { order: keep, recent: [], refills: 4 };
  const { questions, bag: next } = drawQuestions(bag, BANK320, 10, { heat: 'spicy', random: seeded(2) });
  assert.equal(questions.length, 10);
  assert.equal(new Set(questions.map((q) => q.id)).size, 10);
  assert.equal(next.refills, 5);
  const food = questions.filter((q) => q.cat === 'food');
  assert.equal(food.length, 2, 'the category cap holds across the refill');
  assert.ok(food.every((q) => keep.includes(q.id)), 'old bag questions are used before the refill');
});

test('unknown or duplicated ids in a stored bag are ignored', () => {
  const bag = { order: ['nope-001', 'food-001', 'food-001', 'light-001'], recent: ['ghost'], refills: 'x' };
  const { questions } = drawQuestions(bag, BANK320, 2, { heat: 'spicy', random: seeded(1) });
  assert.deepEqual(questions.map((q) => q.id).sort(), ['food-001', 'light-001']);
});

test('judge: same side matches, different sides miss and a timeout never matches', () => {
  assert.deepEqual(judge('A', 'A'), { matched: true, outcome: 'match' });
  assert.deepEqual(judge('B', 'B'), { matched: true, outcome: 'match' });
  assert.deepEqual(judge('A', 'B'), { matched: false, outcome: 'miss' });
  assert.deepEqual(judge(null, 'A'), { matched: false, outcome: 'timeout' });
  assert.deepEqual(judge(null, null), { matched: false, outcome: 'timeout' });
  assert.deepEqual(judge('C', 'C'), { matched: false, outcome: 'timeout' });
});

test('summary counts matches, the current and the best streak and picks the tier', () => {
  const h = [true, true, false, true, true, true, false, true, true, true].map((matched) => ({ matched }));
  assert.deepEqual(summary(h, 10), {
    matches: 8, total: 10, played: 10, streak: 3, bestStreak: 3, tier: { id: 'eyes', label: '눈빛만 봐도' },
  });
  assert.equal(summary([], 10).tier.id, 'opposites');
  assert.equal(summary([{ matched: true }], 10).streak, 1);
});

test('tiers follow 9–10 / 7–8 / 4–6 / 0–3 out of 10 and scale for 5 or 15', () => {
  const ids = Array.from({ length: 11 }, (_, n) => tierFor(n, 10).id);
  assert.deepEqual(ids, ['opposites', 'opposites', 'opposites', 'opposites', 'learning', 'learning', 'learning', 'eyes', 'eyes', 'soulmate', 'soulmate']);
  assert.equal(tierFor(9, 10).label, '텔레파시 커플');
  assert.equal(tierFor(5, 10).label, '알아가는 중');
  assert.equal(tierFor(1, 10).label, '반대가 끌려요');
  assert.equal(tierFor(5, 5).id, 'soulmate');
  assert.equal(tierFor(4, 5).id, 'eyes');
  assert.equal(tierFor(14, 15).id, 'soulmate');
  assert.equal(tierFor(0, 0).id, 'opposites');
});

test('the room series adds games, the match ratio and the best streak without winners', () => {
  const one = applyTelepathySeries(null, { matches: 7, total: 10, bestStreak: 4 });
  assert.deepEqual(one, { games: 1, matches: 7, questions: 10, bestStreak: 4, bestMatches: 7, recent: [{ matches: 7, total: 10 }], ratio: 70 });
  const two = applyTelepathySeries(one, { matches: 4, total: 5, bestStreak: 2 });
  assert.equal(two.games, 2);
  assert.equal(two.ratio, 73);
  assert.equal(two.bestStreak, 4);
  assert.equal(two.wins, undefined);
});

test('heat decides which categories mix in: mild is regular only, spicy adds the spicy ones, nuclear skips mild', () => {
  const draw = (heat, seed = 5) => drawQuestions(emptyBag(), TELEPATHY_BANK, 10, { heat, random: seeded(seed) }).questions;
  for (let seed = 1; seed <= 40; seed++) {
    assert.ok(draw('mild', seed).every((q) => q.heat === 'mild'));
    assert.ok(draw('spicy', seed).every((q) => q.heat === 'mild' || q.heat === 'spicy'));
    const hot = draw('nuclear', seed);
    assert.equal(hot.length, 10);
    assert.ok(hot.every((q) => q.heat === 'nuclear' || q.heat === 'spicy'), 'no mild question in a 19+ game');
    assert.equal(hot.filter((q) => q.heat === 'nuclear').length, 7);
    assert.equal(hot.filter((q) => q.heat === 'spicy').length, 3);
  }
  const five = drawQuestions(emptyBag(), TELEPATHY_BANK, 5, { heat: 'nuclear', random: seeded(1) }).questions;
  assert.equal(five.filter((q) => q.heat === 'spicy').length, 1);
  const fifteen = drawQuestions(emptyBag(), TELEPATHY_BANK, 15, { heat: 'nuclear', random: seeded(1) }).questions;
  assert.equal(fifteen.filter((q) => q.heat === 'spicy').length, 4);
});

test('nuclear games do not repeat a question for as many games as the pool allows', () => {
  const nuclearCount = TELEPATHY_BANK.filter((q) => q.heat === 'nuclear').length;
  const spicyCount = TELEPATHY_BANK.filter((q) => q.heat === 'spicy').length;
  // 한 판 7 + 3: 어느 쪽 풀이 먼저 바닥나는지가 반복 없이 할 수 있는 판 수.
  const games = Math.min(Math.floor(nuclearCount / 7), Math.floor(spicyCount / 3));
  assert.ok(games >= 13, `games without repeat ${games}`);
  for (const seed of [1, 9, 77, 4242]) {
    let bag = emptyBag();
    const seen = new Set();
    const random = seeded(seed);
    for (let game = 0; game < games; game++) {
      const drawn = drawQuestions(bag, TELEPATHY_BANK, 10, { heat: 'nuclear', random });
      bag = drawn.bag;
      for (const q of drawn.questions) {
        assert.ok(!seen.has(q.id), `seed ${seed}: ${q.id} repeated in game ${game + 1}`);
        seen.add(q.id);
      }
    }
    assert.equal(seen.size, games * 10);
  }
});

test('after the nuclear pool runs dry the bag reshuffles and keeps filling games', () => {
  let bag = emptyBag();
  const random = seeded(3);
  for (let game = 0; game < 40; game++) {
    const drawn = drawQuestions(bag, TELEPATHY_BANK, 10, { heat: 'nuclear', random });
    bag = drawn.bag;
    assert.equal(drawn.questions.length, 10);
    assert.equal(new Set(drawn.questions.map((q) => q.id)).size, 10);
    assert.ok(drawn.questions.every((q) => q.heat !== 'mild'));
  }
  assert.ok(bag.refills >= 2);
});

test('the legacy spicy flag still means the spicy level', () => {
  const on = drawQuestions(emptyBag(), TELEPATHY_BANK, 10, { spicy: true, random: seeded(2) }).questions;
  assert.ok(on.every((q) => q.heat !== 'nuclear'));
  const off = drawQuestions(emptyBag(), TELEPATHY_BANK, 10, { random: seeded(2) }).questions;
  assert.ok(off.every((q) => q.heat === 'mild'));
});
