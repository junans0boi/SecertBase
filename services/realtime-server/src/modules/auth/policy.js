// 가입·비밀번호·동의 정책(2.0). 순수 함수만 둔다.

/** 비밀번호: 8자 이상, 영문과 숫자를 모두 포함. 공백 포함 여부는 막지 않는다(trim 하지 않음). */
export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 72; // bcrypt 입력 한도

export const isStrongPassword = (value) =>
  typeof value === 'string' &&
  value.length >= PASSWORD_MIN_LENGTH &&
  value.length <= PASSWORD_MAX_LENGTH &&
  /[A-Za-z]/.test(value) &&
  /\d/.test(value);

/** 만 14세 미만은 가입할 수 없다(서버에서도 생일로 검증). */
export const MIN_SIGNUP_AGE = 14;

const parseIsoDate = (value) => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }
  return { year, month, day };
};

export const isValidBirthDate = (value, today = new Date()) => {
  const parsed = parseIsoDate(value);
  if (!parsed || parsed.year < 1900) return false;
  return value <= today.toISOString().slice(0, 10);
};

/** 만 나이(한국 기준 "만"): 생일이 지나지 않았으면 1을 뺀다. */
export const ageOn = (birthDate, today = new Date()) => {
  const parsed = parseIsoDate(birthDate);
  if (!parsed) return null;
  const y = today.getUTCFullYear();
  const m = today.getUTCMonth() + 1;
  const d = today.getUTCDate();
  let age = y - parsed.year;
  if (m < parsed.month || (m === parsed.month && d < parsed.day)) age -= 1;
  return age;
};

/**
 * 현재 게시된 문서 버전. 약관·개인정보처리방침 페이지를 고치면 함께 올린다.
 * 서버가 기록 시점의 버전을 정한다(클라이언트가 보낸 버전은 믿지 않는다).
 */
export const CONSENT_VERSIONS = Object.freeze({
  terms: '2026-11-06',
  privacy: '2026-11-06',
  age14: '2026-11-06',
  marketing: '2026-11-06',
});

export const REQUIRED_CONSENTS = Object.freeze(['terms', 'privacy', 'age14']);
export const CONSENT_TYPES = Object.freeze(['terms', 'privacy', 'age14', 'marketing']);

/**
 * 요청 본문의 consents를 정규화한다.
 * - 객체가 없으면 legacy(1.x 앱: 약관·개인정보 단일 필수 체크) 로 보고 약관·개인정보만 기록한다.
 * - 객체가 있으면 필수 3개가 모두 true여야 한다.
 * @returns {{ ok: true, records: Array<{type,agreed,version}> } | { ok: false, reason: string }}
 */
export const normalizeConsents = (input, { allowLegacy = true } = {}) => {
  if (input == null) {
    if (!allowLegacy) return { ok: false, reason: 'consent_required' };
    return {
      ok: true,
      legacy: true,
      records: ['terms', 'privacy'].map((type) => ({
        type,
        agreed: true,
        version: CONSENT_VERSIONS[type],
      })),
    };
  }
  if (typeof input !== 'object' || Array.isArray(input)) {
    return { ok: false, reason: 'invalid_consents' };
  }
  for (const type of REQUIRED_CONSENTS) {
    if (input[type] !== true) return { ok: false, reason: 'consent_required' };
  }
  if (input.marketing != null && typeof input.marketing !== 'boolean') {
    return { ok: false, reason: 'invalid_consents' };
  }
  return {
    ok: true,
    legacy: false,
    records: CONSENT_TYPES.map((type) => ({
      type,
      agreed: type === 'marketing' ? input.marketing === true : true,
      version: CONSENT_VERSIONS[type],
    })),
  };
};

const IGNORABLE_SCHEMA_ERRORS = new Set(['ER_NO_SUCH_TABLE', 'ER_BAD_FIELD_ERROR']);
export const isMissingSchemaError = (error) => IGNORABLE_SCHEMA_ERRORS.has(error?.code);

/**
 * 동의 이력을 추가한다. execute는 (sql, params) => Promise. 트랜잭션 연결의 execute나 query 모두 된다.
 * 0050 마이그레이션 전 스키마에서는 가입을 막지 않고 onMissing으로 알린다.
 */
export const recordConsents = async (execute, userId, records, source, onMissing = () => {}) => {
  if (!records.length) return;
  const placeholders = records.map(() => '(?, ?, ?, ?, ?)').join(', ');
  const params = records.flatMap((r) => [userId, r.type, r.version, r.agreed ? 1 : 0, source]);
  try {
    await execute(
      `INSERT INTO user_consents (user_id, consent_type, version, agreed, source)
       VALUES ${placeholders}`,
      params,
    );
  } catch (error) {
    if (!isMissingSchemaError(error)) throw error;
    onMissing(error);
  }
};
