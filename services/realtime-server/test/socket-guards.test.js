import assert from 'node:assert/strict';
import test from 'node:test';
import { createSocketRateLimiter, profileEmojiSchema } from '../src/shared/socket-guards.js';

test('profileEmoji accepts emoji (incl. ZWJ sequences) and rejects control or blank values', () => {
  for (const ok of ['🙂', '👨‍👩‍👧', '❤️', '🇰🇷', 'A']) {
    assert.equal(profileEmojiSchema.safeParse(ok).success, true, ok);
  }
  for (const bad of ['', '   ', 'a\nb', '\u0000', 'x'.repeat(17), ' ', '']) {
    assert.equal(profileEmojiSchema.safeParse(bad).success, false, JSON.stringify(bad));
  }
});

test('socket rate limiter allows the limit per window and recovers after it', () => {
  let t = 0;
  const allow = createSocketRateLimiter({ limit: 3, windowMs: 1000, now: () => t });
  assert.deepEqual([allow(), allow(), allow(), allow()], [true, true, true, false]);
  t = 999;
  assert.equal(allow(), false);
  t = 1000;
  assert.equal(allow(), true);
});
