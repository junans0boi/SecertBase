#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BRANCH="${BRANCH:-main}"
WEB_ROOT="${WEB_ROOT:-/var/www/secretbase}"
SOCKET_URL="${SOCKET_URL:-https://secertbase.kro.kr}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
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

echo "==> Installing backend dependencies"
cd "$REPO_DIR/services/realtime-server"
npm ci
npm test
npm run check

echo "==> Installing Flutter dependencies"
cd "$REPO_DIR/apps/secret_base_app"
flutter pub get
flutter build web --release --no-wasm-dry-run \
  --dart-define=SOCKET_URL="$SOCKET_URL" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"

echo "==> Syncing web build to $WEB_ROOT"
rsync -a --delete build/web/ "$WEB_ROOT/"

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
