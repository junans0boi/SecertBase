#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/junzzang/SecertBase}"
BRANCH="${BRANCH:-main}"
WEB_ROOT="${WEB_ROOT:-/var/www/secretbase}"
SOCKET_URL="${SOCKET_URL:-https://secertbase.kro.kr}"
PM2_NAME="${PM2_NAME:-secretbase-realtime}"

cd "$REPO_DIR"

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
flutter build web --release --no-wasm-dry-run --dart-define=SOCKET_URL="$SOCKET_URL"

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
curl -fsS http://localhost:4100/health
echo
echo "Deploy complete."
