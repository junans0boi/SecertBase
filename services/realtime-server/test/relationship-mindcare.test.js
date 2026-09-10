import assert from 'node:assert/strict';
import test from 'node:test';
import {
  MINDCARE_CONTENT_VERSION,
  MINDCARE_TAXONOMY,
  createMindcareState,
  advanceMindcareState,
  detectRiskCandidate,
  resolveMindcareSafety,
} from '../src/relationship-mindcare.js';

test('mindcare keeps the fixed taxonomy and starts with warm choices', () => {
  assert.equal(MINDCARE_CONTENT_VERSION, 'mindcare-v1');
  assert.equal(MINDCARE_TAXONOMY.emotions.length, 8);
  assert.equal(MINDCARE_TAXONOMY.situations.length, 6);
  assert.equal(MINDCARE_TAXONOMY.needs.length, 6);
  assert.equal(MINDCARE_TAXONOMY.actions.length, 24);

  const state = createMindcareState();
  assert.equal(state.status, 'active');
  assert.equal(state.currentState, 'emotion');
  assert.equal(state.userResponseCount, 0);
  assert.equal(state.nextQuestion.allowFreeText, false);
  assert.match(state.nextQuestion.text, /어떤 감정/);
  assert.equal(state.choices.length, 8);
});

test('mindcare advances through emotion, situation, need, action, and completion', () => {
  let state = createMindcareState();
  const inputs = [
    { choiceKey: 'anxious' },
    { text: '가슴이 답답하고 생각이 많아졌어요.' },
    { choiceKey: 'work' },
    { text: '오늘 회의에서 말하지 못한 일이 있었어요.' },
    { choiceKey: 'reassurance' },
    { choiceKey: 'clarity' },
    { choiceKey: 'breathing' },
    { text: '잠들기 전에 해볼게요.' },
    { choiceKey: 'today' },
    { choiceKey: 'finish' },
  ];
  for (const input of inputs) {
    state = advanceMindcareState(state, input);
  }
  assert.equal(state.status, 'completed');
  assert.equal(state.userResponseCount, 10);
  assert.equal(state.currentState, 'complete');
  assert.equal(state.nextQuestion, null);
  assert.match(state.lastAssistantText, /오늘의 마음관리/);
});

test('risk wording pauses the flow and asks explicit safety confirmation', () => {
  const initial = createMindcareState();
  const result = advanceMindcareState(initial, { text: '죽고 싶다는 생각이 들어요.' });
  assert.equal(result.status, 'safety_pending');
  assert.equal(result.currentState, 'safety');
  assert.equal(result.safety?.required, true);
  assert.equal(result.userResponseCount, 0);
  assert.match(result.lastAssistantText, /지금 안전한 곳에/);
  assert.equal(detectRiskCandidate('오늘 점심은 뭐 먹지?'), null);
  assert.ok(detectRiskCandidate('누군가를 해칠까 봐 무서워요.'));
});

test('explicit safety response either resumes or gives fixed immediate guidance', () => {
  const pending = advanceMindcareState(createMindcareState(), {
    text: '자해하고 싶은 충동이 있어요.',
  });
  const safe = resolveMindcareSafety(pending, { safeNow: true });
  assert.equal(safe.status, 'active');
  assert.equal(safe.currentState, 'emotion');
  assert.equal(safe.safety.status, 'confirmed_safe');
  assert.match(safe.lastAssistantText, /확인해주셔서 고마워요/);

  const unsafe = resolveMindcareSafety(pending, { safeNow: false });
  assert.equal(unsafe.status, 'safety_support');
  assert.equal(unsafe.currentState, 'safety');
  assert.equal(unsafe.safety.status, 'needs_immediate_help');
  assert.match(unsafe.lastAssistantText, /즉시 도움/);
});
