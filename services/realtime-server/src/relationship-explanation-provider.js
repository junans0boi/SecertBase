const forbiddenKeys = new Set([
  'answers',
  'rawAnswers',
  'answerValue',
  'userId',
  'coupleId',
  'partnerId',
  'resultText',
]);

export const explanationStatuses = Object.freeze({
  pending: 'pending',
  available: 'available',
  fallback: 'fallback',
  failed: 'failed',
});

export class ExplanationProviderError extends Error {
  constructor(code, message = code) {
    super(message);
    this.name = 'ExplanationProviderError';
    this.code = code;
  }
}

const hasForbiddenKey = (value) => {
  if (!value || typeof value !== 'object') return false;
  if (Array.isArray(value)) return value.some(hasForbiddenKey);
  return Object.entries(value).some(([key, child]) =>
    forbiddenKeys.has(key) || hasForbiddenKey(child));
};

export const normalizeExplanationInput = (input) => {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new ExplanationProviderError('invalid_input');
  }
  if (hasForbiddenKey(input)) {
    throw new ExplanationProviderError('raw_data_not_allowed');
  }
  const normalized = {
    sourceType: String(input.sourceType ?? ''),
    assessmentCode: input.assessmentCode == null ? null : String(input.assessmentCode),
    analysisCode: input.analysisCode == null ? null : String(input.analysisCode),
    version: String(input.version ?? ''),
    dimensions: Array.isArray(input.dimensions) ? input.dimensions.map((dimension) => ({
      key: String(dimension.key ?? ''),
      title: String(dimension.title ?? ''),
      score: dimension.score == null ? undefined : Number(dimension.score),
      scoreDifference: dimension.scoreDifference == null
        ? undefined
        : Number(dimension.scoreDifference),
      pairScore: dimension.pairScore == null ? undefined : Number(dimension.pairScore),
      alignmentScore: dimension.alignmentScore == null
        ? undefined
        : Number(dimension.alignmentScore),
    })) : [],
    patternKey: input.patternKey == null ? null : String(input.patternKey),
    metadata: input.metadata && typeof input.metadata === 'object'
      ? { locale: String(input.metadata.locale ?? 'ko-KR') }
      : { locale: 'ko-KR' },
  };
  if (!normalized.sourceType || !normalized.version) {
    throw new ExplanationProviderError('invalid_input');
  }
  return normalized;
};

const fixtureText = (input) => input.sourceType === 'compatibility'
  ? '두 사람의 구조화된 관계 패턴을 바탕으로 대화를 시작할 수 있는 지점을 정리했어요.'
  : '구조화된 검사 결과를 바탕으로 현재의 경향을 천천히 살펴볼 수 있어요.';

export const createFixtureExplanationProvider = ({
  mode = 'success',
  delayMs = 0,
  text = null,
} = {}) => ({
  name: 'fixture',
  model: 'fixture-v1',
  async explain(input, { signal } = {}) {
    if (mode === 'failure') throw new ExplanationProviderError('provider_failed');
    if (mode === 'timeout') {
      await new Promise((resolve, reject) => {
        const timer = setTimeout(resolve, delayMs || 1000);
        signal?.addEventListener('abort', () => {
          clearTimeout(timer);
          reject(new ExplanationProviderError('timeout'));
        }, { once: true });
      });
      throw new ExplanationProviderError('timeout');
    }
    if (delayMs > 0) await new Promise((resolve) => setTimeout(resolve, delayMs));
    return { text: text ?? fixtureText(input) };
  },
});

export const createFreeApiExplanationProvider = ({
  baseUrl,
  apiKey,
  model,
  fetchImpl = fetch,
  timeoutMs = 10000,
}) => ({
  name: 'free_api',
  model,
  async explain(input) {
    if (!baseUrl || !apiKey || !model) {
      throw new ExplanationProviderError('provider_not_configured');
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchImpl(baseUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          input,
        }),
        signal: controller.signal,
      });
      if (!response.ok) throw new ExplanationProviderError('provider_failed');
      const body = await response.json();
      const text = body?.text ?? body?.output_text ?? body?.choices?.[0]?.message?.content;
      if (!text) throw new ExplanationProviderError('invalid_provider_response');
      return { text: String(text) };
    } catch (error) {
      if (error?.name === 'AbortError') throw new ExplanationProviderError('timeout');
      if (error instanceof ExplanationProviderError) throw error;
      throw new ExplanationProviderError('provider_failed');
    } finally {
      clearTimeout(timer);
    }
  },
});

export const createExplanationProvider = (config, overrides = {}) => {
  if (!config.LLM_ENABLED || config.LLM_PROVIDER === 'disabled') return null;
  if (config.LLM_PROVIDER === 'fixture') {
    return createFixtureExplanationProvider(overrides.fixture);
  }
  return createFreeApiExplanationProvider({
    baseUrl: config.LLM_BASE_URL,
    apiKey: config.LLM_API_KEY,
    model: config.LLM_MODEL,
    timeoutMs: config.LLM_TIMEOUT_MS,
    ...overrides.freeApi,
  });
};
