#!/usr/bin/env bash
# deploy_test_server.sh — 격리된 테스터 배포 스크립트
#
# 이 스크립트는 test.secertbase.kro.kr 테스터 환경에서만 실행한다.
# 운영 환경(secertbase.kro.kr)과는 완전히 격리된 별도 서비스를 배포한다.
#
# 격리 요건:
#   - PM2 프로세스: secretbase-test (운영은 secretbase-realtime)
#   - MariaDB DB:   secretbase_test (운영은 secretbase)
#   - Redis prefix: test: (운영은 prefix 없음)
#   - 업로드 루트:  $TESTER_UPLOADS_ROOT (운영은 $REPO_DIR/uploads 또는 서버 설정)
#   - .env 파일:    services/realtime-server/.env.test (운영은 .env)
#
# 사용 예:
#   cd ~/SecertBase && ./scripts/deploy_test_server.sh
#
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BRANCH="${BRANCH:-main}"
WEB_ROOT="${WEB_ROOT:-/var/www/secretbase-test}"
SOCKET_URL="${SOCKET_URL:-https://test.secertbase.kro.kr}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
# 테스터 전용 PM2 프로세스 이름 (운영과 반드시 다르게 유지)
PM2_NAME="${PM2_NAME:-secretbase-test}"
# 테스터 전용 .env 파일 (없으면 .env 사용 — 서버에서 분리 필수)
TESTER_ENV_FILE="${TESTER_ENV_FILE:-$REPO_DIR/services/realtime-server/.env.test}"

cd "$REPO_DIR"

echo "==> Restoring flutter-modified files"
git checkout -- apps/secret_base_app/analysis_options.yaml apps/secret_base_app/pubspec.lock 2>/dev/null || true

echo "==> Checking server working tree"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Server working tree is dirty. Commit and push from local PC, then deploy on server."
  git status --short
  exit 1
fi

echo "==> Pulling origin/$BRANCH"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

# ── 배포 전 백업 실행 조건 확인 ───────────────────────────────────────────
REQUIRE_BACKUP_BEFORE_DEPLOY="${REQUIRE_BACKUP_BEFORE_DEPLOY:-false}"
if [ "$REQUIRE_BACKUP_BEFORE_DEPLOY" = "true" ]; then
  echo "==> 배포 전 백업 실행이 활성화되어 있습니다. 백업을 수행합니다."
  if [ -z "${BACKUP_ENCRYPTION_KEY:-}" ]; then
    echo "ERROR: REQUIRE_BACKUP_BEFORE_DEPLOY=true 이나, BACKUP_ENCRYPTION_KEY 가 지정되지 않았습니다." >&2
    exit 1
  fi

  # 테스터 환경용 DATABASE_URL / UPLOADS_ROOT 강제 적용을 위해 .env.test 로드
  LOCAL_DATABASE_URL="${DATABASE_URL:-}"
  LOCAL_UPLOADS_ROOT="${UPLOADS_ROOT:-}"
  if [ -f "$TESTER_ENV_FILE" ]; then
    if [ -z "$LOCAL_DATABASE_URL" ]; then
      LOCAL_DATABASE_URL="$(grep -E "^DATABASE_URL=" "$TESTER_ENV_FILE" | cut -d'=' -f2- || true)"
    fi
    if [ -z "$LOCAL_UPLOADS_ROOT" ]; then
      LOCAL_UPLOADS_ROOT="$(grep -E "^UPLOADS_ROOT=" "$TESTER_ENV_FILE" | cut -d'=' -f2- || true)"
    fi
  fi

  if ! DATABASE_URL="$LOCAL_DATABASE_URL" UPLOADS_ROOT="$LOCAL_UPLOADS_ROOT" "$REPO_DIR/scripts/backup.sh"; then
    echo "ERROR: 배포 전 백업 실행 중 에러가 발생하여 배포가 중단되었습니다." >&2
    exit 1
  fi
fi

# ── 백엔드 검증 ────────────────────────────────────────────────────────────
echo "==> Installing backend dependencies"
cd "$REPO_DIR/services/realtime-server"
npm ci

echo "==> Running backend tests"
npm test

echo "==> Running backend check"
npm run check

# ── 테스터 .env 확인 ───────────────────────────────────────────────────────
if [ -f "$TESTER_ENV_FILE" ]; then
  echo "==> Using tester env: $TESTER_ENV_FILE"
  cp "$TESTER_ENV_FILE" .env.tester_active
else
  echo "WARNING: $TESTER_ENV_FILE not found. Falling back to .env"
  echo "         테스터 격리를 위해 .env.test 파일을 별도로 생성하세요."
  echo "         (DATABASE_URL, REDIS_URL, UPLOADS_ROOT 등을 테스터용으로 분리)"
fi

# ── Flutter 빌드 ───────────────────────────────────────────────────────────
echo "==> Installing Flutter dependencies"
cd "$REPO_DIR/apps/secret_base_app"
flutter pub get

echo "==> Building tester web app"
BUILD_ENV_FILE="$(mktemp)"
trap 'rm -f "$BUILD_ENV_FILE"' EXIT

{
  echo "SOCKET_URL=$SOCKET_URL"
  if [ -n "$GOOGLE_CLIENT_ID" ]; then
    echo "GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID"
  elif [ -f .env ]; then
    grep -E '^GOOGLE_CLIENT_ID=' .env || true
  fi
  echo "KAKAO_REVIEW_AUTO_LOGIN=false"
} > "$BUILD_ENV_FILE"

flutter build web --release --no-wasm-dry-run --dart-define-from-file="$BUILD_ENV_FILE"

BUILD_ID="$(date +%Y%m%d%H%M%S)"
sed -i.bak "s/flutter_bootstrap.js?v=[^']*/flutter_bootstrap.js?v=$BUILD_ID/" build/web/index.html
rm -f build/web/index.html.bak
sed -i.bak "s/\"main.dart.js\"/\"main.dart.js?v=$BUILD_ID\"/" build/web/flutter_bootstrap.js
rm -f build/web/flutter_bootstrap.js.bak

echo "==> Syncing tester web build to $WEB_ROOT"
rsync -a --delete build/web/ "$WEB_ROOT/"

# ── 테스터 백엔드 PM2 프로세스 재시작 ─────────────────────────────────────
echo "==> Restarting tester backend: $PM2_NAME"
cd "$REPO_DIR/services/realtime-server"
if [ -f .env.tester_active ]; then
  # 테스터 전용 .env 파일을 임시로 활성화해 PM2 재시작
  cp .env .env.prod_backup_tmp
  cp .env.tester_active .env
  pm2 restart "$PM2_NAME" --update-env 2>/dev/null \
    || pm2 start src/index.js --name "$PM2_NAME" --update-env
  cp .env.prod_backup_tmp .env
  rm -f .env.prod_backup_tmp .env.tester_active
  pm2 save
else
  pm2 restart "$PM2_NAME" --update-env 2>/dev/null \
    || echo "WARNING: PM2 process '$PM2_NAME' not found. Start it manually."
fi

# ── 검증 ──────────────────────────────────────────────────────────────────
echo "==> Verifying tester health"
sleep 3
curl -fsS "$SOCKET_URL/health"
echo
curl -fsSI "$SOCKET_URL/" >/dev/null

echo "==> Restoring flutter-modified files after build"
cd "$REPO_DIR"
git checkout -- apps/secret_base_app/analysis_options.yaml apps/secret_base_app/pubspec.lock 2>/dev/null || true

echo ""
echo "Tester deploy complete."
echo "  URL:     $SOCKET_URL"
echo "  PM2:     $PM2_NAME"
echo "  WebRoot: $WEB_ROOT"
