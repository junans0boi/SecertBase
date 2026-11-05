/**
 * account-deletion.js
 *
 * 회원 탈퇴 관련 순수 헬퍼 함수 모음.
 * 실제 DB/파일 I/O를 수행하지 않으므로 단위 테스트 가능.
 */

/**
 * 이메일 인증 사용자인지 확인.
 * AuthProvider 가 null/'password' 인 경우만 비밀번호 확인을 요구한다.
 * @param {string|null} authProvider
 * @returns {boolean}
 */
export function isPasswordUser(authProvider) {
  return authProvider === null || authProvider === 'password';
}

/**
 * 탈퇴 후 Users row 를 tombstone 으로 만들기 위한 업데이트 값 반환.
 * 이메일, 이름, UserCode, PasswordHash, OAuth 식별자 등 개인 정보를 지우고
 * 로그인 불가 상태로 전환한다.
 * @param {number} userId
 * @returns {{ Email: string, UserName: string, FullName: string, Nickname: string|null, PasswordHash: string|null, GoogleId: string|null, IsDeleted: number, DeletedAt: string }}
 */
export function buildTombstoneFields(userId) {
  return {
    Email: `deleted_${userId}@__tombstone__`,
    UserName: `deleted_${userId}`,
    FullName: 'Deleted User',
    // Users.Nickname is NOT NULL, so a blank string is the erased value.
    Nickname: '',
    PasswordHash: null,
    GoogleId: null,
    // Birth profile is personal data too. BirthDate is NOT NULL, so use a fixed placeholder.
    BirthDate: '1900-01-01',
    BirthTime: null,
    BirthPlace: null,
    BirthCalendarType: 'solar',
    IsDeleted: 1,
    // DATETIME columns reject ISO strings with 'T'/'Z' in strict mode; use 'YYYY-MM-DD HH:MM:SS' (UTC).
    DeletedAt: new Date().toISOString().slice(0, 19).replace('T', ' '),
  };
}

/**
 * Rows owned by a single user that must disappear when the account is deleted.
 * The Users row is kept as a tombstone, so ON DELETE CASCADE never fires and every
 * table has to be listed here. Couple-scoped history (shared with the partner)
 * and payment records are intentionally not listed.
 * `where` may name several columns; the user id is bound to each of them.
 */
export const USER_DATA_PURGE = [
  // Relationship understanding. Child rows (messages, answers) cascade from these.
  { table: 'relationship_counseling_messages', where: ['author_user_id'] },
  { table: 'relationship_counseling_sessions', where: ['owner_user_id'] },
  { table: 'relationship_shareable_insights', where: ['creator_user_id'] },
  { table: 'relationship_mindcare_sessions', where: ['owner_user_id'] },
  { table: 'relationship_assessment_results', where: ['user_id'] },
  { table: 'relationship_assessment_attempts', where: ['user_id'] },
  { table: 'relationship_saju_results', where: ['user_id'] },
  { table: 'relationship_fortune_contents', where: ['user_id'] },
  { table: 'relationship_tarot_contents', where: ['user_id'] },
  { table: 'relationship_explanation_generations', where: ['requester_user_id'] },
  // Moments and map.
  { table: 'setlog_comments', where: ['user_id'] },
  { table: 'setlog_reactions', where: ['user_id'] },
  { table: 'today_moments', where: ['user_id'] },
  { table: 'today_loop_views', where: ['user_id'] },
  { table: 'map_pin_reviews', where: ['user_id'] },
  { table: 'afterglow_contributions', where: ['user_id'] },
  // Private writing and answers.
  { table: 'private_reflections', where: ['user_id'] },
  { table: 'question_answers', where: ['user_id'] },
  { table: 'couple_balance_answers', where: ['user_id'] },
  { table: 'album_photos', where: ['user_id'] },
  { table: 'daily_engagement_actions', where: ['user_id'] },
  // Devices and notifications.
  { table: 'device_tokens', where: ['user_id'] },
  { table: 'notification_prefs', where: ['user_id'] },
  { table: 'notification_tokens', where: ['user_id'] },
  { table: 'notification_events', where: ['user_id'] },
  // Wallet, items, progress.
  { table: 'wallet_transactions', where: ['user_id'] },
  { table: 'wallets', where: ['user_id'] },
  { table: 'owned_items', where: ['user_id'] },
  { table: 'equipped_items', where: ['user_id'] },
  { table: 'user_levels', where: ['user_id'] },
  { table: 'user_missions', where: ['user_id'] },
  // Pending pairing requests.
  { table: 'PairingRequests', where: ['SenderUserId', 'RecipientUserId'] },
];

/** Tables whose rows reference uploaded files that must be removed from disk. */
export const USER_MEDIA_COLUMNS = [
  { table: 'album_photos', column: 'photo_url', userColumn: 'user_id' },
  { table: 'map_pin_reviews', column: 'media_url', userColumn: 'user_id' },
];

const IGNORABLE_PURGE_ERRORS = new Set(['ER_NO_SUCH_TABLE', 'ER_BAD_FIELD_ERROR']);

/**
 * Deletes every row in USER_DATA_PURGE for the user, inside the caller's transaction.
 * A table or column missing from an older schema must not block an account deletion,
 * so those two errors are reported through `onSkip` and the purge continues.
 * @returns {Promise<string[]>} names of tables that were skipped
 */
export async function purgeUserData(conn, userId, onSkip = () => {}) {
  const skipped = [];
  for (const { table, where } of USER_DATA_PURGE) {
    const clause = where.map((column) => `${column} = ?`).join(' OR ');
    try {
      await conn.execute(
        `DELETE FROM ${table} WHERE ${clause}`,
        where.map(() => userId),
      );
    } catch (error) {
      if (!IGNORABLE_PURGE_ERRORS.has(error?.code)) throw error;
      skipped.push(table);
      onSkip(table, error);
    }
  }
  return skipped;
}

/**
 * map_pins 행 목록을 받아 삭제/익명화로 분류한다.
 *
 * 규칙:
 *   - 다른 사용자의 setlog 행이 map_pin_id 를 참조하면 → 익명화(archive) 대상
 *   - 그렇지 않으면 → 하드 삭제 대상
 *
 * @param {Array<{id: number, hasLinkedMoment: boolean}>} pins
 * @returns {{ toAnonymize: number[], toDelete: number[] }}
 */
export function classifyPinsForDeletion(pins) {
  const toAnonymize = [];
  const toDelete = [];
  for (const pin of pins) {
    if (pin.hasLinkedMoment) {
      toAnonymize.push(pin.id);
    } else {
      toDelete.push(pin.id);
    }
  }
  return { toAnonymize, toDelete };
}

/**
 * setlog_posts 행 목록에서 media_url 이 있는 것만 골라
 * 파일 경로 배열을 반환한다.
 * @param {Array<{media_url: string|null}>} posts
 * @param {(url: string) => string|null} mediaFilePath  경로 변환 함수
 * @returns {string[]}
 */
export function collectMediaPaths(posts, mediaFilePath) {
  return posts
    .map((p) => mediaFilePath(p.media_url))
    .filter(Boolean);
}
