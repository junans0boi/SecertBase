#!/usr/bin/env bash
# dev.sh — 로컬 개발 환경 실행
# DB/Redis: SSH 터널 → 서버 실서버 사용 (포트 3307, 6380)
# Node 서버: 로컬 4100
# Flutter Web: localhost:7357 → SOCKET_URL=http://localhost:4100

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_HOST="ubuntu@secretbase.cloud"
SSH_KEY="/Users/junzzang/BACKUP/workspace/ssh-key-2026-07-06.key"
LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "localhost")"
TUNNEL_PID_FILE="/tmp/sb_ssh_tunnel.pid"
NODE_PID_FILE="/tmp/sb_node_server.pid"

# ── 색상 ────────────────────────────────────────────────────────────────────
C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[0;31m'; C_RESET='\033[0m'
ok()   { echo -e "${C_GREEN}✔  $*${C_RESET}"; }
info() { echo -e "${C_YELLOW}►  $*${C_RESET}"; }
err()  { echo -e "${C_RED}✘  $*${C_RESET}" >&2; }

# ── cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
  echo ""
  info "종료 중..."

  if [ -f "$NODE_PID_FILE" ]; then
    local pid; pid=$(cat "$NODE_PID_FILE")
    kill "$pid" 2>/dev/null && ok "Node 서버 종료 (PID $pid)" || true
    rm -f "$NODE_PID_FILE"
  fi

  if [ -f "$TUNNEL_PID_FILE" ]; then
    local pid; pid=$(cat "$TUNNEL_PID_FILE")
    kill "$pid" 2>/dev/null && ok "SSH 터널 종료 (PID $pid)" || true
    rm -f "$TUNNEL_PID_FILE"
  fi
}
trap cleanup EXIT INT TERM

# ── 기존 프로세스 정리 ───────────────────────────────────────────────────────
info "기존 프로세스 정리..."
# Node (4100), Flutter dev server (7357)
lsof -ti:4100 | xargs kill -9 2>/dev/null || true
lsof -ti:7357 | xargs kill -9 2>/dev/null || true
# Flutter tool 프로세스
pkill -f "dart.*flutter_tools" 2>/dev/null || true
pkill -f "flutter.*run" 2>/dev/null || true
# 기존 터널
if [ -f "$TUNNEL_PID_FILE" ]; then
  kill "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null || true
  rm -f "$TUNNEL_PID_FILE"
fi

# ── 1. SSH 터널 ──────────────────────────────────────────────────────────────
info "SSH 터널 연결 중: DB(3307) + Redis(6380) → $SERVER_HOST"
ssh -N \
  -i "$SSH_KEY" \
  -L 3307:127.0.0.1:3306 \
  -L 6380:127.0.0.1:6379 \
  -o ConnectTimeout=10 \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=accept-new \
  "$SERVER_HOST" &
TUNNEL_PID=$!
echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"

# 터널 준비 대기 (최대 10초)
for i in $(seq 1 10); do
  sleep 1
  if nc -z 127.0.0.1 3307 2>/dev/null; then
    ok "SSH 터널 연결됨 (PID $TUNNEL_PID)"
    break
  fi
  if [ "$i" -eq 10 ]; then
    err "SSH 터널 연결 실패 — 서버($SERVER_HOST)에 접근 가능한지 확인하세요"
    exit 1
  fi
done

# ── 2. 미적용 마이그레이션 자동 실행 ────────────────────────────────────────
info "마이그레이션 확인 중..."
DB_USER="junzzang"
DB_PASS="0427"
DB_NAME="secretbase"
DB_PORT="3307"
# SSH 터널은 이미 암호화되므로 SSL 불필요
MYSQL_BIN="$(command -v mysql || echo /usr/local/opt/mysql-client/bin/mysql)"
if [ ! -x "$MYSQL_BIN" ]; then
  err "mysql 클라이언트가 없습니다: brew install mysql-client 후 재시도하세요"
  exit 1
fi
# The local client may be MariaDB (Homebrew's default on macOS), which does
# not support MySQL's --ssl-mode option. The SSH tunnel already encrypts this
# connection, and --skip-ssl is supported by both MariaDB and MySQL clients.
MYSQL="$MYSQL_BIN --skip-ssl -u${DB_USER} -p${DB_PASS} -P ${DB_PORT} -h 127.0.0.1 ${DB_NAME}"

MIGRATIONS_DIR="$ROOT/services/realtime-server/migrations"

# 적용된 마이그레이션 추적 테이블이 없으면 생성
$MYSQL -e "CREATE TABLE IF NOT EXISTS _migrations (name VARCHAR(120) PRIMARY KEY, applied_at DATETIME DEFAULT NOW());" 2>/dev/null || true

for sql_file in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do
  migration_name="$(basename "$sql_file")"
  already_applied=$($MYSQL -sNe "SELECT COUNT(*) FROM _migrations WHERE name='$migration_name';" 2>/dev/null || echo "0")

  if [ "$already_applied" = "0" ]; then
    info "  적용 중: $migration_name"
    if $MYSQL < "$sql_file" 2>/tmp/sb_migration_err.txt; then
      $MYSQL -e "INSERT IGNORE INTO _migrations (name) VALUES ('$migration_name');" 2>/dev/null || true
      ok "  완료: $migration_name"
    else
      err "  실패: $migration_name"
      cat /tmp/sb_migration_err.txt >&2
      exit 1
    fi
  fi
done
ok "마이그레이션 최신 상태"

# ── 3. Node 서버 ─────────────────────────────────────────────────────────────
info "Node 서버 시작 중 (포트 4100)..."
cd "$ROOT/services/realtime-server"
NODE_LOG="/tmp/sb_node.log"
node src/index.js > "$NODE_LOG" 2>&1 &
NODE_PID=$!
echo "$NODE_PID" > "$NODE_PID_FILE"

# 서버 준비 대기 (최대 15초)
for i in $(seq 1 15); do
  sleep 1
  if nc -z 127.0.0.1 4100 2>/dev/null; then
    ok "Node 서버 준비됨 (PID $NODE_PID)"
    break
  fi
  if ! kill -0 "$NODE_PID" 2>/dev/null; then
    err "Node 서버 충돌 — 로그 확인: $NODE_LOG"
    tail -20 "$NODE_LOG"
    exit 1
  fi
  if [ "$i" -eq 15 ]; then
    err "Node 서버 타임아웃 — 로그: $NODE_LOG"
    tail -20 "$NODE_LOG"
    exit 1
  fi
done

# ── 4. Flutter Web ───────────────────────────────────────────────────────────
info "Flutter Web 실행 중 (포트 7357)..."

# .env에서 빌드 변수 로드 (GOOGLE_CLIENT_ID, KAKAO_REVIEW_AUTO_LOGIN)
FLUTTER_ENV_FILE="$ROOT/apps/secret_base_app/.env"
GOOGLE_CLIENT_ID=""
KAKAO_REVIEW_AUTO_LOGIN="false"
if [ -f "$FLUTTER_ENV_FILE" ]; then
  # These keys are optional. Avoid grep under `set -o pipefail`: a missing
  # optional key must not terminate the whole dev launcher.
  GOOGLE_CLIENT_ID="$(sed -n 's/^GOOGLE_CLIENT_ID=//p' "$FLUTTER_ENV_FILE" | tr -d '\r')"
  KAKAO_REVIEW_AUTO_LOGIN="$(sed -n 's/^KAKAO_REVIEW_AUTO_LOGIN=//p' "$FLUTTER_ENV_FILE" | tr -d '\r')"
  info ".env 로드됨 (GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID:+설정됨}${GOOGLE_CLIENT_ID:-미설정})"
else
  info ".env 없음 — Google 로그인 비활성화 (apps/secret_base_app/.env 생성 후 재시작)"
fi

echo ""
echo "  앱 URL: http://localhost:7357"
echo "  서버:   http://localhost:4100"
echo "  DB:     127.0.0.1:3307 (→ 서버 실 DB)"
echo "  Redis:  127.0.0.1:6380 (→ 서버 Redis)"
echo ""
cd "$ROOT/apps/secret_base_app"

FLUTTER_DEFINES=(
  "--dart-define=SOCKET_URL=http://localhost:4100"
  "--dart-define=KAKAO_REVIEW_AUTO_LOGIN=$KAKAO_REVIEW_AUTO_LOGIN"
)
if [ -n "$GOOGLE_CLIENT_ID" ]; then
  FLUTTER_DEFINES+=("--dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID")
fi

flutter run -d chrome \
  --web-port 7357 \
  "${FLUTTER_DEFINES[@]}"
