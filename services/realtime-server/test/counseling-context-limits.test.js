import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildPrivateCounselingContext,
  buildSharedCounselingContext,
} from '../src/relationship-context-builder.js';

const many = (count, make) => Array.from({ length: count }, (_, i) => make(i));

test('counseling LLM context keeps only the latest messages and insights', () => {
  const messages = many(100, (i) => ({ role: 'user', content: `m${i}` }));
  const shared = buildSharedCounselingContext({
    approvedInsights: many(50, (i) => ({ insightText: `i${i}` })),
    messages,
  });
  assert.equal(shared.messages.length, 40);
  assert.equal(shared.messages.at(-1).content, 'm99');
  assert.equal(shared.approvedInsights.length, 20);
  assert.equal(shared.approvedInsights.at(-1).text, 'i49');
  assert.match(shared.untrustedInputNotice, /지시/);

  const priv = buildPrivateCounselingContext({ messages });
  assert.equal(priv.messages.length, 40);
  assert.equal(priv.messages[0].content, 'm60');
});
