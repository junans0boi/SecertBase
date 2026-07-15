#!/usr/bin/env bash
# backup.sh - 데이터베이스 및 업로드 파일 암호화 일일 백업 스크립트
#
# 완료 조건:
#   - 데이터베이스와 업로드 파일을 함께 매일 암호화 백업한다.
#   - 일일 백업을 정확히 30세대 보관하고 더 오래된 백업은 제거한다.
#   - 백업 실패 시 명확한 에러 보고와 종료 코드 1 반환.

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

# 기본 백업 경로 설정 (프로젝트 루트 하위의 backups 디렉토리)
BACKUP_DIR="${BACKUP_DIR:-$REPO_DIR/backups}"
mkdir -p "$BACKUP_DIR"

# 업로드 루트 폴더 기본값 설정
UPLOADS_ROOT="${UPLOADS_ROOT:-$REPO_DIR/services/realtime-server/uploads}"

# 백업 암호화 키 검증
if [ -z "${BACKUP_ENCRYPTION_KEY:-}" ]; then
  echo "ERROR: BACKUP_ENCRYPTION_KEY 환경 변수가 설정되어 있지 않습니다." >&2
  exit 1
fi

# DATABASE_URL 검증 및 파싱
if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: DATABASE_URL 환경 변수가 설정되어 있지 않습니다." >&2
  exit 1
fi

# mysql://user:password@host/database 또는 mysql://user:password@host:port/database 파싱
DB_CONN_STR="${DATABASE_URL#mysql://}"
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

echo "==> 백업 시작"
echo "  대상 DB: $DB_NAME ($DB_HOST:$DB_PORT)"
echo "  대상 업로드 폴더: $UPLOADS_ROOT"
echo "  백업 저장소: $BACKUP_DIR"

# 임시 작업 디렉토리 생성
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

# 1. 데이터베이스 덤프 수행
echo "==> 데이터베이스 덤프 중..."
if ! mysqldump -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
    --single-transaction --quick --lock-tables=false "$DB_NAME" > "$TEMP_DIR/db.sql" 2>/dev/null; then
  echo "  (정보) TCP 접속을 통한 덤프 실패. Unix socket 접속으로 재시도합니다..."
  if ! mysqldump -u"$DB_USER" -p"$DB_PASS" \
      --single-transaction --quick --lock-tables=false "$DB_NAME" > "$TEMP_DIR/db.sql"; then
    echo "ERROR: 데이터베이스 덤프 실패" >&2
    exit 1
  fi
fi

# 2. 업로드 폴더 백업
echo "==> 업로드 폴더 복사 중..."
mkdir -p "$TEMP_DIR/uploads"
if [ -d "$UPLOADS_ROOT" ]; then
  cp -R "$UPLOADS_ROOT/." "$TEMP_DIR/uploads/"
fi

# 3. 암호화 아카이브 생성
# openssl enc -aes-256-cbc 사용 (pbkdf2, iter 100000 적용으로 보안 강화)
BACKUP_FILENAME="backup_$(date +%Y%m%d_%H%M%S).tar.enc"
BACKUP_FILE_PATH="$BACKUP_DIR/$BACKUP_FILENAME"

echo "==> 암호화 압축 백업 파일 생성 중..."
if ! tar -C "$TEMP_DIR" -czf - db.sql uploads | \
     openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -out "$BACKUP_FILE_PATH" -pass pass:"$BACKUP_ENCRYPTION_KEY"; then
  echo "ERROR: 암호화 압축 백업 생성 실패" >&2
  # 실패 시 불완전한 백업 파일 제거
  rm -f "$BACKUP_FILE_PATH"
  exit 1
fi

echo "==> 백업 파일 생성 성공: $BACKUP_FILE_PATH"

# 4. 30세대 보관 정책 적용 (가장 최근 30개 파일만 유지하고 오래된 것은 삭제)
echo "==> 30세대 백업 관리 적용..."
# 파일명 정렬을 위해 생성 시간 기준 내림차순(가장 최근 파일이 먼저 오도록) 정렬하여 31번째 줄부터 삭제 대상 지정
BACKUP_FILES=($(ls -t "$BACKUP_DIR"/backup_*.tar.enc 2>/dev/null || true))

if [ ${#BACKUP_FILES[@]} -gt 30 ]; then
  EXCESS_COUNT=$((${#BACKUP_FILES[@]} - 30))
  echo "  보관 개수 초과 (${#BACKUP_FILES[@]}/30). 오래된 백업 ${EXCESS_COUNT}개를 삭제합니다."
  for ((i=30; i<${#BACKUP_FILES[@]}; i++)); do
    echo "  삭제 대상 백업: ${BACKUP_FILES[$i]}"
    rm -f "${BACKUP_FILES[$i]}"
  done
else
  echo "  현재 보관 중인 백업 개수: ${#BACKUP_FILES[@]} (최대 30개 보관 가능)"
fi

echo "==> 백업 완료!"
exit 0
