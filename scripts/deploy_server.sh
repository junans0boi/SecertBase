#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BRANCH="${BRANCH:-main}"
WEB_ROOT="${WEB_ROOT:-/var/www/secretbase}"
SOCKET_URL="${SOCKET_URL:-https://secertbase.kro.kr}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
KAKAO_REVIEW_AUTO_LOGIN="${KAKAO_REVIEW_AUTO_LOGIN:-false}"
PM2_NAME="${PM2_NAME:-secretbase-realtime}"

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
  if ! "$REPO_DIR/scripts/backup.sh"; then
    echo "ERROR: 배포 전 백업 실행 중 에러가 발생하여 배포가 중단되었습니다." >&2
    exit 1
  fi
fi

echo "==> Installing backend dependencies"
cd "$REPO_DIR/services/realtime-server"
npm ci
npm test
npm run check

echo "==> Installing Flutter dependencies"
cd "$REPO_DIR/apps/secret_base_app"
flutter pub get
if [ -f .env ]; then
  echo "==> Using apps/secret_base_app/.env for build config"
  BUILD_ENV_FILE="$(mktemp)"
  grep -E '^(SOCKET_URL|GOOGLE_CLIENT_ID|KAKAO_REVIEW_AUTO_LOGIN)=' .env > "$BUILD_ENV_FILE" || true
  flutter build web --release --no-wasm-dry-run --dart-define-from-file="$BUILD_ENV_FILE"
  rm -f "$BUILD_ENV_FILE"
else
  flutter build web --release --no-wasm-dry-run \
    --dart-define=SOCKET_URL="$SOCKET_URL" \
    --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
    --dart-define=KAKAO_REVIEW_AUTO_LOGIN="$KAKAO_REVIEW_AUTO_LOGIN"
fi

BUILD_ID="$(date +%Y%m%d%H%M%S)"
sed -i.bak "s/flutter_bootstrap.js?v=[^']*/flutter_bootstrap.js?v=$BUILD_ID/" build/web/index.html
rm -f build/web/index.html.bak
sed -i.bak "s/\"main.dart.js\"/\"main.dart.js?v=$BUILD_ID\"/" build/web/flutter_bootstrap.js
rm -f build/web/flutter_bootstrap.js.bak

echo "==> Syncing web build to $WEB_ROOT"
rsync -a --delete build/web/ "$WEB_ROOT/"

echo "==> Restoring flutter-modified files after build"
cd "$REPO_DIR"
git checkout -- apps/secret_base_app/analysis_options.yaml apps/secret_base_app/pubspec.lock 2>/dev/null || true

echo "==> Restarting realtime server with PM2"
cd "$REPO_DIR/services/realtime-server"
if pm2 describe "$PM2_NAME" >/dev/null 2>&1; then
  pm2 restart "$PM2_NAME" --update-env
else
  pm2 start src/index.js --name "$PM2_NAME" --cwd "$REPO_DIR/services/realtime-server" --update-env
fi
pm2 save

echo "==> Verifying health"
for attempt in {1..10}; do
  if curl -fsS http://localhost:4100/health; then
    echo
    echo "Deploy complete."
    exit 0
  fi

  echo "Health check failed, retrying ($attempt/10)..."
  sleep 1
done

echo
echo "Realtime server did not become healthy in time."
exit 1
