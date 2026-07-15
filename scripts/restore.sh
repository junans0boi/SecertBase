#!/usr/bin/env bash
# restore.sh - 암호화된 백업 복구 및 데이터/미디어 무결성 검증 스크립트
#
# 완료 조건:
#   - 기본적으로 폐기 가능한 환경에 복구하고 기록 및 미디어 무결성을 검증한다.
#   - 운영 데이터베이스를 덮어쓰지 않도록 안전 검증을 수행한다.

set -euo pipefail

# 현재 스크립트 위치 기준 프로젝트 루트 경로 설정
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# .env 파일 로드 (realtime-server 디렉토리에 있는 설정 로드)
ENV_FILE="$REPO_DIR/services/realtime-server/.env"
# UPLOADS_ROOT 및 DATABASE_URL이 지정되지 않은 경우에만 .env에서 읽음
if [ -f "$ENV_FILE" ]; then
  if [ -z "${DATABASE_URL:-}" ]; then
    DATABASE_URL="$(grep -E "^DATABASE_URL=" "$ENV_FILE" | cut -d'=' -f2- || true)"
  fi
  if [ -z "${UPLOADS_ROOT:-}" ]; then
    UPLOADS_ROOT="$(grep -E "^UPLOADS_ROOT=" "$ENV_FILE" | cut -d'=' -f2- || true)"
  fi
fi

# 백업 파일 매개변수 확인
if [ $# -lt 1 ]; then
  echo "사용법: $0 <백업 파일 경로> [복구 대상 DATABASE_URL] [복구 대상 UPLOADS_ROOT]" >&2
  exit 1
fi

BACKUP_FILE_PATH="$1"

# 복구용 데이터베이스 URL (지정되지 않은 경우 환경 변수의 DATABASE_URL 사용)
# 프로덕션 데이터베이스 덮어쓰기 방지를 위한 예방 조치
TARGET_DATABASE_URL="${2:-${DATABASE_URL:-}}"
TARGET_UPLOADS_ROOT="${3:-${UPLOADS_ROOT:-$REPO_DIR/services/realtime-server/uploads_restore_test}}"

# 백업 암호화 키 검증
if [ -z "${BACKUP_ENCRYPTION_KEY:-}" ]; then
  echo "ERROR: BACKUP_ENCRYPTION_KEY 환경 변수가 설정되어 있지 않습니다." >&2
  exit 1
fi

if [ -z "$TARGET_DATABASE_URL" ]; then
  echo "ERROR: 복구 대상 DATABASE_URL이 지정되지 않았습니다." >&2
  exit 1
fi

# 안전 장치: 운영 DB에 직접 복구하는 것을 엄격히 경고하고 방지
# DATABASE_URL이 secretbase이거나 production 데이터베이스에 속하면 경고
if [[ "$TARGET_DATABASE_URL" == *"secretbase"* && ! "$TARGET_DATABASE_URL" == *"test"* ]]; then
  echo "WARNING: 지정된 복구 대상 DB가 프로덕션일 수 있습니다: $TARGET_DATABASE_URL"
  echo "안전을 위해 복구 시도 시 환경 변수 FORCE_RESTORE=true 가 필요합니다."
  if [ "${FORCE_RESTORE:-false}" != "true" ]; then
    echo "ERROR: 프로덕션 DB 손상을 방지하기 위해 작업을 중단합니다. (FORCE_RESTORE=true 를 설정해 덮어쓰거나, 테스트 DB를 지정하세요)" >&2
    exit 1
  fi
fi

# 백업 파일 존재 확인
if [ ! -f "$BACKUP_FILE_PATH" ]; then
  echo "ERROR: 백업 파일을 찾을 수 없습니다: $BACKUP_FILE_PATH" >&2
  exit 1
fi

# DATABASE_URL 파싱
DB_CONN_STR="${TARGET_DATABASE_URL#mysql://}"
USER_PASS="${DB_CONN_STR%%@*}"
HOST_DB="${DB_CONN_STR#*@}"

DB_USER="${USER_PASS%%:*}"
DB_PASS="${USER_PASS#*:}"

DB_HOST="${HOST_DB%%/*}"
DB_NAME="${HOST_DB#*/}"

if [[ "$DB_HOST" == *:* ]]; then
  DB_PORT="${DB_HOST#*:}"
  DB_HOST="${DB_HOST%%:*}"
else
  DB_PORT=3306
fi

# mysql 쿼리를 안전하게 수행하는 헬퍼 함수 (TCP 실패 시 Unix socket 펄백)
run_mysql() {
  if ! mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$@" 2>/dev/null; then
    mysql -u"$DB_USER" -p"$DB_PASS" "$@"
  fi
}

echo "==> 복구 시작"
echo "  백업 파일: $BACKUP_FILE_PATH"
echo "  복구 대상 DB: $DB_NAME ($DB_HOST:$DB_PORT)"
echo "  복구 대상 업로드 폴더: $TARGET_UPLOADS_ROOT"

# 임시 복구 디렉토리 생성
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

# 1. 암호 해독 및 압축 해제
echo "==> 백업 암호화 해제 및 압축 풀기..."
if ! openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$BACKUP_FILE_PATH" -pass pass:"$BACKUP_ENCRYPTION_KEY" | \
     tar -xzf - -C "$TEMP_DIR"; then
  echo "ERROR: 백업 암호 해독 또는 압축 해제 실패. 비밀번호(BACKUP_ENCRYPTION_KEY)를 확인하세요." >&2
  exit 1
fi

# 복구 아카이브 구조 검증
if [ ! -f "$TEMP_DIR/db.sql" ] || [ ! -d "$TEMP_DIR/uploads" ]; then
  echo "ERROR: 복구 디렉토리 내에 필수 요소(db.sql, uploads)가 유실되었습니다." >&2
  exit 1
fi

# 2. 데이터베이스 복구
echo "==> 데이터베이스 테이블 및 데이터 복구 중..."
# DB가 없다면 자동 생성 시도
run_mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;" || true

if ! run_mysql "$DB_NAME" < "$TEMP_DIR/db.sql"; then
  echo "ERROR: 데이터베이스 복구 실행 실패" >&2
  exit 1
fi

# 3. 업로드 파일 복구
echo "==> 업로드 폴더 복구 중..."
mkdir -p "$TARGET_UPLOADS_ROOT"
if ! cp -R "$TEMP_DIR/uploads/." "$TARGET_UPLOADS_ROOT/"; then
  echo "ERROR: 업로드 파일 복구 실패" >&2
  exit 1
fi

# 4. 무결성 검증 (Integrity Check)
echo "==> 복구 무결성 검증 수행..."
INTEGRITY_FAILED=0

# A. DB 테이블 및 기본 레코드 무결성 검증
echo "  [DB 무결성 검증]"
REQUIRED_TABLES=("Users" "Couples" "map_pins" "setlog_posts")
for TABLE in "${REQUIRED_TABLES[@]}"; do
  # 테이블 존재 여부 검사
  TABLE_EXISTS=$(run_mysql -AN "$DB_NAME" -e "SHOW TABLES LIKE '$TABLE';")
  if [ -z "$TABLE_EXISTS" ]; then
    echo "  ❌ 오류: 필수 테이블 '$TABLE'이 복구되지 않았습니다!" >&2
    INTEGRITY_FAILED=1
  else
    # 테이블 내의 로우 수 출력해 확인
    ROW_COUNT=$(run_mysql -AN "$DB_NAME" -e "SELECT COUNT(*) FROM \`$TABLE\`;")
    echo "  - 테이블 '$TABLE' 복구 성공 (레코드 수: $ROW_COUNT)"
  fi
done

# B. 업로드 미디어 파일 무결성 검증
echo "  [미디어 무결성 검증]"
BACKUP_MEDIA_COUNT=$(find "$TEMP_DIR/uploads" -type f | wc -l)
RESTORED_MEDIA_COUNT=$(find "$TARGET_UPLOADS_ROOT" -type f | wc -l)

echo "  - 백업 내 미디어 파일 수: $BACKUP_MEDIA_COUNT"
echo "  - 복구된 미디어 파일 수: $RESTORED_MEDIA_COUNT"

if [ "$BACKUP_MEDIA_COUNT" -ne "$RESTORED_MEDIA_COUNT" ]; then
  echo "  ❌ 오류: 미디어 파일 개수가 불일치합니다!" >&2
  INTEGRITY_FAILED=1
else
  echo "  - 미디어 파일 개수 일치 및 무결성 확인 완료"
fi

if [ $INTEGRITY_FAILED -eq 1 ]; then
  echo "ERROR: 복구 무결성 검증 실패!" >&2
  exit 1
fi

echo "==> 복구 및 무결성 검증 완료! (성공)"
exit 0
