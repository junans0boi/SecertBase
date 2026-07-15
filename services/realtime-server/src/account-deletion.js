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
    Nickname: null,
    PasswordHash: null,
    GoogleId: null,
    IsDeleted: 1,
    DeletedAt: new Date().toISOString(),
  };
}

/**
 * map_pins 행 목록을 받아 삭제/익명화로 분류한다.
 *
 * 규칙:
 *   - map_pin_id 를 참조하는 setlog 행이 존재하면 → 익명화(archive) 대상
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
