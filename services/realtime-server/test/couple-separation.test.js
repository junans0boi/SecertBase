import test from 'node:test';
import assert from 'node:assert/strict';

import {
  isCoupleMember,
  normalizeCoupleUserId,
  partnerIdForCouple,
} from '../src/couple-separation.js';

test('normalizeCoupleUserId accepts only positive integer ids', () => {
  assert.equal(normalizeCoupleUserId('12'), 12);
  assert.equal(normalizeCoupleUserId(12), 12);
  assert.equal(normalizeCoupleUserId('0'), null);
  assert.equal(normalizeCoupleUserId('abc'), null);
});

test('isCoupleMember verifies either side of a couple row', () => {
  const couple = { User1Id: 3, User2Id: 9 };
  assert.equal(isCoupleMember(couple, 3), true);
  assert.equal(isCoupleMember(couple, 9), true);
  assert.equal(isCoupleMember(couple, 4), false);
});

test('partnerIdForCouple returns the other member only for members', () => {
  const couple = { User1Id: 3, User2Id: 9 };
  assert.equal(partnerIdForCouple(couple, 3), 9);
  assert.equal(partnerIdForCouple(couple, 9), 3);
  assert.equal(partnerIdForCouple(couple, 4), null);
});
