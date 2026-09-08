import {
  ExplanationProviderError,
  explanationStatuses,
  normalizeExplanationInput,
} from './relationship-explanation-provider.js';

const fallbackText = (input) => input.sourceType === 'compatibility'
  ? '두 사람의 핵심 관계 패턴은 유지되며, 아래의 고정 대화 질문부터 천천히 살펴볼 수 있어요.'
  : '현재 결과의 점수와 경향은 그대로 유지돼요. 각 차원이 일상에서 어떻게 나타나는지 천천히 살펴보세요.';

export const createExplanationAttempt = async ({
  provider,
  input,
  providerName = provider?.name ?? 'disabled',
  model = provider?.model ?? null,
}) => {
  const normalized = normalizeExplanationInput(input);
  if (!provider) {
    return {
      status: explanationStatuses.fallback,
      provider: providerName,
      model,
      text: fallbackText(normalized),
      errorCode: 'provider_disabled',
      input: normalized,
    };
  }
  try {
    const response = await provider.explain(normalized);
    return {
      status: explanationStatuses.available,
      provider: providerName,
      model,
      text: String(response.text ?? ''),
      errorCode: null,
      input: normalized,
    };
  } catch (error) {
    const errorCode = error instanceof ExplanationProviderError
      ? error.code
      : 'provider_failed';
    return {
      status: explanationStatuses.fallback,
      provider: providerName,
      model,
      text: fallbackText(normalized),
      errorCode,
      input: normalized,
    };
  }
};
