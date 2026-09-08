const safeString = (value, max = 4000) => String(value ?? '').slice(0, max);

const safeDimension = (dimension) => ({
  key: safeString(dimension?.key, 80),
  title: safeString(dimension?.title, 160),
  score: dimension?.score == null ? undefined : Number(dimension.score),
  scoreDifference: dimension?.scoreDifference == null
    ? undefined
    : Number(dimension.scoreDifference),
});

export const buildFortuneContext = ({ date, profile, partnerProfile = null }) => ({
  contextVersion: 'fortune-v1',
  date: safeString(date, 10),
  birthProfile: {
    calendarType: safeString(profile?.calendarType, 16),
    birthDate: safeString(profile?.birthDate, 10),
    birthTime: profile?.birthTime ? safeString(profile.birthTime, 8) : null,
    timezone: safeString(profile?.timezone, 64),
    birthPlace: profile?.birthPlace ? safeString(profile.birthPlace, 255) : null,
  },
  partnerBirthProfile: partnerProfile
    ? {
      calendarType: safeString(partnerProfile.calendarType, 16),
      birthDate: safeString(partnerProfile.birthDate, 10),
      birthTime: partnerProfile.birthTime ? safeString(partnerProfile.birthTime, 8) : null,
      timezone: safeString(partnerProfile.timezone, 64),
      birthPlace: partnerProfile.birthPlace ? safeString(partnerProfile.birthPlace, 255) : null,
    }
    : null,
});

export const buildPrivateCounselingContext = ({
  profile,
  assessmentSummaries = [],
  messages = [],
}) => ({
  contextVersion: 'counseling-private-v1',
  scope: 'private',
  birthProfile: profile,
  assessmentSummaries: assessmentSummaries.map((summary) => ({
    code: safeString(summary.code, 80),
    version: safeString(summary.version, 32),
    tendency: safeString(summary.tendency, 240),
    dimensions: (summary.dimensions ?? []).map(safeDimension),
  })),
  messages: messages.map((message) => ({
    role: safeString(message.role, 16),
    content: safeString(message.content),
  })),
  safety: {
    nonClinical: true,
    crisisNotice: '위기나 자해 위험이 있으면 AI 대신 즉시 지역 응급·상담 자원을 이용하세요.',
  },
});

export const buildSharedCounselingContext = ({
  compatibilitySummaries = [],
  approvedInsights = [],
  messages = [],
}) => ({
  contextVersion: 'counseling-shared-v1',
  scope: 'shared',
  compatibilitySummaries: compatibilitySummaries.map((summary) => ({
    code: safeString(summary.code, 80),
    patternKey: safeString(summary.patternKey, 120),
    dimensions: (summary.dimensions ?? []).map(safeDimension),
  })),
  approvedInsights: approvedInsights.map((insight) => ({
    text: safeString(insight.insightText, 1200),
  })),
  messages: messages.map((message) => ({
    role: safeString(message.role, 16),
    content: safeString(message.content),
  })),
  privacy: {
    privateRawMessagesIncluded: false,
    onlyUserApprovedPrivateInsightsIncluded: true,
  },
  safety: {
    nonClinical: true,
    crisisNotice: '위기나 자해 위험이 있으면 AI 대신 즉시 지역 응급·상담 자원을 이용하세요.',
  },
});

export const buildRelationshipContentAttempt = async ({
  provider,
  input,
  fallbackText,
}) => {
  if (!provider) {
    return {
      status: 'fallback',
      provider: 'disabled',
      model: null,
      text: fallbackText,
      errorCode: 'provider_disabled',
    };
  }
  try {
    const response = await provider.explain(input);
    return {
      status: 'available',
      provider: provider.name,
      model: provider.model ?? null,
      text: String(response.text ?? ''),
      errorCode: null,
    };
  } catch (error) {
    return {
      status: 'fallback',
      provider: provider.name ?? 'unknown',
      model: provider.model ?? null,
      text: fallbackText,
      errorCode: error?.code ?? 'provider_failed',
    };
  }
};
