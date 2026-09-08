import assert from 'node:assert/strict';
import test from 'node:test';
import {
  ExplanationProviderError,
  createFixtureExplanationProvider,
  createFreeApiExplanationProvider,
  normalizeExplanationInput,
} from '../src/relationship-explanation-provider.js';
import { createExplanationAttempt } from '../src/relationship-explanation-service.js';

const input = {
  sourceType: 'assessment',
  assessmentCode: 'attachment',
  version: 'v1',
  dimensions: [{ key: 'reassurance', title: '확인과 안심', score: 70 }],
  patternKey: 'situational_balance',
  metadata: { locale: 'ko-KR' },
};

test('normalizes structured input and rejects raw or identity data', () => {
  const normalized = normalizeExplanationInput(input);
  assert.equal(normalized.dimensions[0].score, 70);
  assert.throws(
    () => normalizeExplanationInput({ ...input, answers: [{ value: 5 }] }),
    (error) => error instanceof ExplanationProviderError && error.code === 'raw_data_not_allowed',
  );
  assert.throws(
    () => normalizeExplanationInput({ ...input, coupleId: 7 }),
    (error) => error instanceof ExplanationProviderError && error.code === 'raw_data_not_allowed',
  );
});

test('fixture provider reproduces success, failure, and timeout', async () => {
  const normalized = normalizeExplanationInput(input);
  const success = await createFixtureExplanationProvider().explain(normalized);
  assert.match(success.text, /구조화된 검사 결과/);

  await assert.rejects(
    () => createFixtureExplanationProvider({ mode: 'failure' }).explain(normalized),
    (error) => error instanceof ExplanationProviderError && error.code === 'provider_failed',
  );
  await assert.rejects(
    () => createFixtureExplanationProvider({ mode: 'timeout' }).explain(normalized),
    (error) => error instanceof ExplanationProviderError && error.code === 'timeout',
  );
});

test('free provider adapter sends only the normalized contract', async () => {
  let request;
  const provider = createFreeApiExplanationProvider({
    baseUrl: 'https://llm.example.test/generate',
    apiKey: 'test-key',
    model: 'free-model',
    fetchImpl: async (_url, options) => {
      request = JSON.parse(options.body);
      return new Response(JSON.stringify({ text: '설명' }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    },
  });
  const result = await provider.explain(normalizeExplanationInput(input));
  assert.equal(result.text, '설명');
  assert.equal(request.model, 'free-model');
  assert.equal(request.input.answers, undefined);
  assert.equal(request.input.coupleId, undefined);
});

test('service preserves fallback and core input when provider is disabled or fails', async () => {
  const disabled = await createExplanationAttempt({ provider: null, input });
  assert.equal(disabled.status, 'fallback');
  assert.match(disabled.text, /점수와 경향은 그대로/);

  const failed = await createExplanationAttempt({
    provider: createFixtureExplanationProvider({ mode: 'failure' }),
    input,
  });
  assert.equal(failed.status, 'fallback');
  assert.equal(failed.errorCode, 'provider_failed');
  assert.deepEqual(failed.input.dimensions, disabled.input.dimensions);
});
