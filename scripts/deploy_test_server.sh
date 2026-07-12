#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BRANCH="${BRANCH:-main}"
WEB_ROOT="${WEB_ROOT:-/var/www/secretbase-test}"
SOCKET_URL="${SOCKET_URL:-https://test.secertbase.kro.kr}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
KAKAO_REVIEW_AUTO_LOGIN="${KAKAO_REVIEW_AUTO_LOGIN:-false}"

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
  echo "KAKAO_REVIEW_AUTO_LOGIN=$KAKAO_REVIEW_AUTO_LOGIN"
} > "$BUILD_ENV_FILE"

flutter build web --release --no-wasm-dry-run --dart-define-from-file="$BUILD_ENV_FILE"

echo "==> Syncing tester web build to $WEB_ROOT"
rsync -a --delete build/web/ "$WEB_ROOT/"

echo "==> Verifying tester URL"
curl -fsS "$SOCKET_URL/health"
echo
curl -fsSI "$SOCKET_URL/" >/dev/null

echo "Tester deploy complete."
