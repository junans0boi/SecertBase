/**
 * JSON 컬럼/JSON 함수(JSON_OBJECTAGG 등) 결과를 객체로 맞춘다.
 * mysql2는 서버가 JSON 타입으로 알려 주면 이미 파싱된 객체를, 아니면 문자열(또는 Buffer)을 준다.
 * 이미 객체인 값을 JSON.parse하면 SyntaxError가 나서 윷·원카드·마블 생성이 internal_error로 실패했었다.
 * @param {unknown} value
 * @param {object|null} fallback - null/빈 값/파싱 실패 시 반환값
 */
export function parseJsonObject(value, fallback = {}) {
  if (value == null) return fallback;
  if (Buffer.isBuffer(value)) value = value.toString('utf8');
  if (typeof value === 'string') {
    if (value.trim() === '') return fallback;
    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === 'object' ? parsed : fallback;
    } catch {
      return fallback;
    }
  }
  return typeof value === 'object' ? value : fallback;
}
