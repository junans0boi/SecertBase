export const MINDCARE_CONTENT_VERSION = 'mindcare-v1';

const choice = (key, label) => ({ key, label });

export const MINDCARE_TAXONOMY = Object.freeze({
  emotions: Object.freeze([
    choice('anxious', '불안해요'),
    choice('sad', '슬퍼요'),
    choice('angry', '화가 나요'),
    choice('lonely', '외로워요'),
    choice('overwhelmed', '벅차요'),
    choice('numb', '아무 느낌이 없어요'),
    choice('guilty', '미안하고 죄책감이 들어요'),
    choice('relieved', '조금 안도돼요'),
  ]),
  situations: Object.freeze([
    choice('work', '일이나 공부에서'),
    choice('family', '가족과 집에서'),
    choice('relationship', '연인이나 가까운 관계에서'),
    choice('health', '몸과 건강 때문에'),
    choice('change', '변화나 선택 앞에서'),
    choice('alone', '혼자 있는 시간에'),
  ]),
  needs: Object.freeze([
    choice('reassurance', '안심하고 싶어요'),
    choice('rest', '잠깐 쉬고 싶어요'),
    choice('being_heard', '판단 없이 들어주면 좋겠어요'),
    choice('boundary', '내 경계를 지키고 싶어요'),
    choice('connection', '누군가와 연결되고 싶어요'),
    choice('clarity', '무엇부터 할지 정리하고 싶어요'),
  ]),
  actions: Object.freeze([
    choice('breathing', '숨을 천천히 세 번 쉬기'),
    choice('water', '물 한 잔 마시기'),
    choice('stretch', '어깨와 목 가볍게 풀기'),
    choice('window', '창문을 열고 바깥 공기 느끼기'),
    choice('walk', '5분만 걷기'),
    choice('shower', '따뜻한 샤워하기'),
    choice('meal', '간단한 것을 먹기'),
    choice('sleep', '잠자리를 준비하기'),
    choice('phone_down', '휴대전화를 잠깐 내려놓기'),
    choice('mute', '알림을 잠시 끄기'),
    choice('write', '마음을 한 문장으로 적기'),
    choice('name_feeling', '감정에 이름 붙이기'),
    choice('three_things', '고마운 것 세 가지 적기'),
    choice('schedule', '오늘 할 일을 하나만 고르기'),
    choice('ask_time', '믿을 사람에게 잠깐 통화 가능한지 묻기'),
    choice('send_message', '안부 메시지 보내기'),
    choice('say_no', '오늘 하지 않을 일을 정하기'),
    choice('small_boundary', '작은 경계 한 가지 말하기'),
    choice('professional_help', '상담이나 진료를 알아보기'),
    choice('safe_place', '조금 더 안전한 장소로 이동하기'),
    choice('grounding', '눈에 보이는 것 다섯 가지 찾기'),
    choice('music', '편안한 음악 한 곡 듣기'),
    choice('pet', '반려동물과 잠깐 머물기'),
    choice('custom', '내가 할 수 있는 작은 행동 적기'),
  ]),
});

const steps = Object.freeze([
  {
    key: 'emotion',
    text: '지금 어떤 감정이 가장 가까우세요?',
    allowFreeText: false,
    choices: MINDCARE_TAXONOMY.emotions,
  },
  {
    key: 'emotion_detail',
    text: '그 감정이 몸이나 생각에 어떻게 느껴지는지 적어주실래요?',
    allowFreeText: true,
    choices: [],
  },
  {
    key: 'situation',
    text: '이 마음은 어떤 상황에서 가장 커졌나요?',
    allowFreeText: false,
    choices: MINDCARE_TAXONOMY.situations,
  },
  {
    key: 'situation_detail',
    text: '그 상황에서 특히 마음에 남은 장면을 한 가지 적어주세요.',
    allowFreeText: true,
    choices: [],
  },
  {
    key: 'need',
    text: '지금 내 마음에 가장 필요한 것은 무엇일까요?',
    allowFreeText: false,
    choices: MINDCARE_TAXONOMY.needs,
  },
  {
    key: 'need_priority',
    text: '그 필요를 오늘 조금 채운다면 어떤 모습일까요?',
    allowFreeText: false,
    choices: MINDCARE_TAXONOMY.needs,
  },
  {
    key: 'action',
    text: '지금 해볼 수 있는 작은 행동을 하나 골라볼까요?',
    allowFreeText: false,
    choices: MINDCARE_TAXONOMY.actions,
  },
  {
    key: 'action_detail',
    text: '그 행동을 언제, 어디에서 해볼지 정해보실래요?',
    allowFreeText: true,
    choices: [],
  },
  {
    key: 'action_check',
    text: '이 작은 행동을 오늘 시도해볼 수 있을까요?',
    allowFreeText: false,
    choices: [choice('today', '오늘 해볼게요'), choice('later', '조금 뒤에 해볼게요')],
  },
  {
    key: 'closure',
    text: '오늘은 여기까지 정리해도 괜찮을까요?',
    allowFreeText: false,
    choices: [choice('finish', '여기까지 마칠게요'), choice('save', '이 마음을 기억해둘게요')],
  },
]);

const stepView = (step) => step && ({
  key: step.key,
  text: step.text,
  allowFreeText: step.allowFreeText,
});

const choicesFor = (step) => step?.choices?.map((item) => ({ ...item })) ?? [];

const copySelections = (selections) => ({ ...(selections ?? {}) });

const makeSafety = (status = 'not_needed', reason = null) => ({
  required: status !== 'not_needed',
  status,
  ...(reason ? { reason } : {}),
});

export const createMindcareState = () => {
  const first = steps[0];
  return {
    contentVersion: MINDCARE_CONTENT_VERSION,
    status: 'active',
    currentState: first.key,
    stepIndex: 0,
    userResponseCount: 0,
    selections: {},
    safety: makeSafety(),
    nextQuestion: stepView(first),
    choices: choicesFor(first),
    lastAssistantText: '지금 마음을 안전한 속도로 살펴볼게요. 서두르지 않아도 괜찮아요.',
  };
};

const riskRules = Object.freeze([
  {
    key: 'self_harm',
    words: ['죽고 싶', '죽어버리', '자해', '내 몸을 해치', '살고 싶지 않'],
  },
  {
    key: 'harm_to_others',
    words: ['죽이고 싶', '해치고 싶', '누군가를 해칠', '해칠까', '때리고 싶', '폭력을 쓰'],
  },
  {
    key: 'immediate_danger',
    words: ['지금 위험', '도망칠 수 없', '당장 다칠', '위협받고'],
  },
]);

export const detectRiskCandidate = (value) => {
  const normalized = String(value ?? '').normalize('NFKC').toLowerCase();
  if (!normalized) return null;
  return riskRules.find((rule) => rule.words.some((word) => normalized.includes(word)))?.key ?? null;
};

const selectedLabel = (step, input) => {
  if (input.choiceKey) {
    const selected = step.choices.find((item) => item.key === input.choiceKey);
    if (!selected) throw new Error('invalid_mindcare_choice');
    return selected.label;
  }
  const text = String(input.text ?? '').trim();
  if (!step.allowFreeText || !text || text.length > 1000) {
    throw new Error('invalid_mindcare_input');
  }
  return text;
};

const nextStateFor = ({ state, stepIndex, selections, status, safety, lastAssistantText }) => {
  const next = steps[stepIndex];
  if (!next) {
    return {
      ...state,
      status: 'completed',
      currentState: 'complete',
      stepIndex,
      selections,
      safety,
      nextQuestion: null,
      choices: [],
      lastAssistantText: lastAssistantText ?? '오늘의 마음관리를 여기까지 잘 마쳤어요. 작은 행동 하나를 기억해두세요.',
    };
  }
  return {
    ...state,
    status,
    currentState: next.key,
    stepIndex,
    selections,
    safety,
    nextQuestion: stepView(next),
    choices: choicesFor(next),
    lastAssistantText: lastAssistantText ?? '천천히 잘 따라오고 계세요. 다음 마음을 살펴볼게요.',
  };
};

export const advanceMindcareState = (state, input) => {
  if (state.status !== 'active') throw new Error('mindcare_not_active');
  const step = steps[state.stepIndex];
  if (!step) throw new Error('mindcare_completed');
  const text = String(input?.text ?? '').trim();
  const risk = text ? detectRiskCandidate(text) : null;
  if (risk) {
    return {
      ...state,
      status: 'safety_pending',
      currentState: 'safety',
      safety: makeSafety('pending', risk),
      nextQuestion: {
        key: 'safety',
        text: '지금 안전한 곳에 있고, 당장 자신이나 다른 사람을 해칠 위험은 없나요?',
        allowFreeText: false,
      },
      choices: [choice('safe_now', '지금은 안전해요'), choice('need_help', '지금 도움이 필요해요')],
      lastAssistantText: '그 말을 혼자 감당하지 않도록 함께 확인할게요. 지금 안전한 곳에 있나요?',
    };
  }
  const label = selectedLabel(step, input);
  const selections = copySelections(state.selections);
  selections[step.key] = input.choiceKey ?? label;
  return nextStateFor({
    state: {
      ...state,
      userResponseCount: Number(state.userResponseCount ?? 0) + 1,
    },
    stepIndex: state.stepIndex + 1,
    selections,
    status: 'active',
    safety: makeSafety(),
  });
};

export const resolveMindcareSafety = (state, { safeNow }) => {
  if (!['safety_pending', 'safety_support'].includes(state.status)) {
    throw new Error('mindcare_safety_not_required');
  }
  if (typeof safeNow !== 'boolean') throw new Error('invalid_mindcare_safety');
  if (safeNow) {
    const step = steps[state.stepIndex];
    return {
      ...state,
      status: 'active',
      currentState: step.key,
      safety: { ...makeSafety('confirmed_safe'), previousReason: state.safety?.reason ?? null },
      nextQuestion: stepView(step),
      choices: choicesFor(step),
      lastAssistantText: '확인해주셔서 고마워요. 지금은 안전을 확인했으니, 아까의 마음을 천천히 이어서 살펴볼게요.',
    };
  }
  return {
    ...state,
    status: 'safety_support',
    currentState: 'safety',
    safety: { ...state.safety, required: true, status: 'needs_immediate_help' },
    nextQuestion: null,
    choices: [],
    lastAssistantText: '지금은 혼자 버티지 말고 즉시 도움을 받아주세요. 가까운 사람에게 함께 있어 달라고 말하고, 급하면 112 또는 119에 연락하세요.',
  };
};

export const mindcareStateView = (state) => ({
  contentVersion: state.contentVersion ?? MINDCARE_CONTENT_VERSION,
  currentState: state.currentState,
  userResponseCount: Number(state.userResponseCount ?? 0),
  selections: copySelections(state.selections),
  safety: state.safety ?? makeSafety(),
  nextQuestion: state.nextQuestion ?? null,
  choices: state.choices ?? [],
});
