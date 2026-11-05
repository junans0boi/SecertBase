import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildFortuneContext,
  buildPrivateCounselingContext,
} from '../src/relationship-context-builder.js';

const profile = {
  calendarType: 'solar',
  birthDate: '1995-03-02',
  birthTime: '09:30',
  timezone: 'Asia/Seoul',
  birthPlace: '서울 마포구 어딘가 123',
};

test('fortune context never carries the free-text birth place', () => {
  const context = buildFortuneContext({
    date: '2026-11-05',
    profile,
    partnerProfile: { ...profile, birthPlace: '부산 어딘가' },
  });
  const serialized = JSON.stringify(context);
  assert.equal(serialized.includes('birthPlace'), false);
  assert.equal(serialized.includes('마포'), false);
  assert.equal(serialized.includes('부산'), false);
  assert.equal(context.birthProfile.birthDate, '1995-03-02');
});

test('private counseling context drops the birth place but keeps other profile fields', () => {
  const context = buildPrivateCounselingContext({ profile, messages: [] });
  const serialized = JSON.stringify(context);
  assert.equal(serialized.includes('마포'), false);
  assert.equal(context.birthProfile.birthDate, '1995-03-02');
});
