import assert from 'node:assert/strict';
import test from 'node:test';
import {
  ANSWER_MAX_LENGTH,
  CATEGORY_ORDER,
  RECENT_WINDOW_DAYS,
  TwoAnswersError,
  bankProblems,
  computeStreak,
  defaultBank,
  normalizeAnswerBody,
  questionStatus,
  selectQuestion,
} from '../src/modules/two-answers/domain.js';
import { featureForRestPath, isRestEnabled } from '../src/shared/feature-registry.js';

test('question bank has 5 categories with at least 40 questions each and unique ids', () => {
  assert.deepEqual(bankProblems(defaultBank), []);
  assert.deepEqual(Object.keys(defaultBank.categories), CATEGORY_ORDER);
});

test('bank has place and anniversary reference templates that never mention coordinates', () => {
  const pin = defaultBank.questions.filter((q) => q.needs === 'pin');
  const ann = defaultBank.questions.filter((q) => q.needs === 'anniversary');
  assert.ok(pin.length >= 5);
  assert.ok(ann.length >= 3);
  for (const q of [...pin, ...ann]) assert.doesNotMatch(q.text, /좌표|위도|경도|주소/);
});

test('selection is deterministic per couple and date', () => {
  const a = selectQuestion({ coupleId: 7, date: '2026-11-23' });
  const b = selectQuestion({ coupleId: 7, date: '2026-11-23' });
  assert.deepEqual(a, b);
});

test('categories rotate across consecutive days', () => {
  const categories = Array.from({ length: 5 }, (_, i) => selectQuestion({
    coupleId: 3,
    date: `2026-11-${String(10 + i).padStart(2, '0')}`,
  }).category);
  assert.deepEqual([...categories].sort(), [...CATEGORY_ORDER].sort());
});

test('no repeats within the recent window across 180 days', () => {
  const used = [];
  for (let i = 0; i < 180; i += 1) {
    const date = new Date(Date.UTC(2026, 0, 1 + i)).toISOString().slice(0, 10);
    const recent = used.slice(-RECENT_WINDOW_DAYS);
    const picked = selectQuestion({ coupleId: 1, date, recentQuestionIds: recent });
    assert.ok(!recent.includes(picked.questionId), `${date} repeated ${picked.questionId}`);
    used.push(picked.questionId);
  }
});

test('reference templates require a pin or anniversary and use only the title', () => {
  const noRefs = new Set();
  for (let i = 0; i < 100; i += 1) {
    const date = new Date(Date.UTC(2026, 0, 1 + i)).toISOString().slice(0, 10);
    const q = selectQuestion({ coupleId: 2, date });
    noRefs.add(q.questionId);
    assert.doesNotMatch(q.text, /\{pin\}|\{anniversary\}/);
  }
  assert.ok(![...noRefs].some((id) => defaultBank.questions.find((q) => q.id === id).needs));

  let sawPin = false;
  let sawAnniversary = false;
  for (let i = 0; i < 200; i += 1) {
    const date = new Date(Date.UTC(2026, 0, 1 + i)).toISOString().slice(0, 10);
    const q = selectQuestion({
      coupleId: 2,
      date,
      pinTitles: ['한강 벤치'],
      anniversaryLabels: ['백일'],
    });
    assert.doesNotMatch(q.text, /\{pin\}|\{anniversary\}/);
    if (q.text.includes('한강 벤치')) sawPin = true;
    if (q.text.includes('백일')) sawAnniversary = true;
  }
  assert.ok(sawPin && sawAnniversary);
});

test('streak counts consecutive both-answered days and resets to 0 when broken', () => {
  assert.equal(computeStreak(['2026-11-21', '2026-11-22', '2026-11-23'], '2026-11-23'), 3);
  assert.equal(computeStreak(['2026-11-21', '2026-11-22'], '2026-11-23'), 2);
  assert.equal(computeStreak(['2026-11-20'], '2026-11-23'), 0);
  assert.equal(computeStreak([], '2026-11-23'), 0);
});

test('status reflects whose turn it is', () => {
  assert.equal(questionStatus({ mine: false, partner: true }), 'my_turn');
  assert.equal(questionStatus({ mine: true, partner: false }), 'waiting');
  assert.equal(questionStatus({ mine: true, partner: true }), 'open');
});

test('answers are trimmed and limited to 500 characters', () => {
  assert.equal(normalizeAnswerBody('  안녕  '), '안녕');
  assert.equal(normalizeAnswerBody('가'.repeat(ANSWER_MAX_LENGTH)).length, ANSWER_MAX_LENGTH);
  assert.throws(() => normalizeAnswerBody('가'.repeat(ANSWER_MAX_LENGTH + 1)), TwoAnswersError);
  assert.throws(() => normalizeAnswerBody('   '), TwoAnswersError);
  assert.throws(() => normalizeAnswerBody(12), TwoAnswersError);
});

test('mvp feature set does not block /api/two-answers', () => {
  for (const path of ['/two-answers/today', '/api/two-answers/today/answer', '/api/TWO-ANSWERS/history']) {
    assert.equal(featureForRestPath(path), null, path);
    assert.equal(isRestEnabled(path, 'mvp'), true, path);
  }
  assert.notEqual(featureForRestPath('/api/qa/today'), null);
});
