export const CHANGE_COMPARISON_MESSAGE = '이 검사를 한 번 더 완료하면 최근 변화를 볼 수 있어요.';

const numeric = (value) => Number.isFinite(Number(value)) ? Number(value) : 0;

const delta = (current, previous) => numeric(current) - numeric(previous);

const valueFor = (dimension, scope) => scope === 'couple'
  ? numeric(dimension.pairScore)
  : numeric(dimension.score);

const overallFor = (result, scope) => scope === 'couple'
  ? numeric(result.overallScore)
  : numeric(result.overallScore);

const alignmentFor = (dimension, scope) => scope === 'couple'
  ? numeric(dimension.alignmentScore)
  : null;

export const buildAssessmentComparison = ({
  scope,
  assessmentCode,
  version,
  records,
}) => {
  const ordered = Array.isArray(records) ? records.slice(0, 2) : [];
  if (ordered.length < 2) {
    return {
      status: 'insufficient_data',
      available: false,
      scope,
      assessmentCode,
      version,
      message: CHANGE_COMPARISON_MESSAGE,
      visualization: 'bar_or_line',
      dimensions: [],
      overall: null,
    };
  }
  const current = ordered[0];
  const previous = ordered[1];
  const previousByKey = new Map(
    (previous.result?.dimensions ?? []).map((dimension) => [dimension.key, dimension]),
  );
  const dimensions = (current.result?.dimensions ?? []).flatMap((dimension) => {
    const before = previousByKey.get(dimension.key);
    if (!before) return [];
    const previousValue = valueFor(before, scope);
    const currentValue = valueFor(dimension, scope);
    const previousAlignment = alignmentFor(before, scope);
    const currentAlignment = alignmentFor(dimension, scope);
    return [{
      key: dimension.key,
      title: dimension.title,
      previous: previousValue,
      current: currentValue,
      delta: delta(currentValue, previousValue),
      ...(scope === 'couple'
        ? {
            alignment: {
              previous: previousAlignment,
              current: currentAlignment,
              delta: delta(currentAlignment, previousAlignment),
            },
          }
        : {}),
    }];
  });
  const previousOverall = overallFor(previous.result ?? {}, scope);
  const currentOverall = overallFor(current.result ?? {}, scope);
  const response = {
    status: 'ready',
    available: true,
    scope,
    assessmentCode,
    version,
    metric: scope === 'couple' ? 'pairScore' : 'dimensionScore',
    visualization: 'bar_or_line',
    message: '최근 두 기록의 변화를 가볍게 비교해봐요.',
    previous: {
      id: previous.id == null ? null : Number(previous.id),
      createdAt: previous.createdAt ?? null,
    },
    current: {
      id: current.id == null ? null : Number(current.id),
      createdAt: current.createdAt ?? null,
    },
    overall: {
      previous: previousOverall,
      current: currentOverall,
      delta: delta(currentOverall, previousOverall),
    },
    dimensions,
    disclaimer: '변화량은 자기성찰을 위한 참고 정보이며 개선·악화나 관계의 우열을 의미하지 않아요.',
  };
  if (scope === 'couple') {
    const previousAlignment = numeric(previous.result?.overallAlignmentScore);
    const currentAlignment = numeric(current.result?.overallAlignmentScore);
    response.overall.alignment = {
      previous: previousAlignment,
      current: currentAlignment,
      delta: delta(currentAlignment, previousAlignment),
    };
  }
  return response;
};
