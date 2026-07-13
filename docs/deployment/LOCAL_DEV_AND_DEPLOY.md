# Local Development and Server Deployment

## Goal

Use the local PC for development and Git commits. Use the server only for pulling the latest commit, building, and deploying.

## Recommended Flow

1. Develop on the local PC.
2. Run checks locally.
3. Commit and push to GitHub.
4. SSH into the server, preferably through Tailscale.
5. Run the server deploy script.

## Local PC Setup

```bash
git clone https://github.com/junans0boi/SecertBase.git
cd SecertBase
```

Backend:

```bash
cd services/realtime-server
cp .env.example .env
# edit .env for your local MariaDB/Redis/JWT values
npm ci
npm run dev
```

Required backend env keys:

- `PORT`: realtime/API server port, normally `4100`
- `CORS_ORIGIN`: comma-separated allowed browser origins
- `REDIS_URL`: Redis connection URL
- `DATABASE_URL`: MariaDB/MySQL connection URL
- `JWT_SECRET`: random 32+ character secret for login tokens
- `GOOGLE_CLIENT_ID`: Google OAuth Web Client ID. Leave empty to disable Google login.
- `ROOM_SECRET`: legacy room secret
- `ALLOWED_USERS`: comma-separated pair for the legacy two-person room flow

Flutter app:

```bash
cd apps/secret_base_app
flutter pub get
flutter run -d chrome \
  --web-hostname localhost \
  --web-port 7357 \
  --dart-define=SOCKET_URL=http://localhost:4100 \
  --dart-define=GOOGLE_CLIENT_ID=<google-web-client-id>
```

For mobile device testing against a backend running on the local PC, replace `localhost` with the local PC LAN IP:

```bash
flutter run -d chrome --dart-define=SOCKET_URL=http://192.168.x.x:4100
```

## Local Checks Before Push

```bash
cd services/realtime-server
npm test
npm run check

cd ../../apps/secret_base_app
flutter analyze
flutter build web --release --no-wasm-dry-run \
  --dart-define=SOCKET_URL=https://secertbase.kro.kr \
  --dart-define=GOOGLE_CLIENT_ID=<google-web-client-id>
```

`flutter analyze` currently reports existing lint warnings in unrelated files. Treat new errors as blockers.

## Commit and Push From Local PC

```bash
git status --short
git add <changed-files>
git commit -m "feat: describe change"
git push origin main
```

Do not commit temporary folders such as `trash/` or raw reference asset folders unless they are intentionally part of the app.

## Deploy on Server

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key -t ubuntu@100.97.58.29 'cd ~/SecertBase && exec bash -l'
cd /home/ubuntu/SecertBase
./scripts/deploy_server.sh
```

The server keeps its own `services/realtime-server/.env`. Do not commit that file. If new env keys are added, update the server `.env` from `.env.example` before restarting PM2.

As of 2026-07-13, `secertbase.kro.kr` is back to the normal production/login build. The server also has `test.secertbase.kro.kr` for friend/tester access. The tester build is served from `/var/www/secretbase-test` and should be deployed with:

```bash
cd /home/ubuntu/SecertBase
./scripts/deploy_test_server.sh
```

The tester script builds with:

```text
SOCKET_URL=https://test.secertbase.kro.kr
KAKAO_REVIEW_AUTO_LOGIN=false
```

The server's `apps/secret_base_app/.env` should keep `KAKAO_REVIEW_AUTO_LOGIN=false` for the normal production build. `scripts/deploy_server.sh` prefers that file when it exists, so check it before production deploys.

The deploy script does this:

- refuses to deploy if the server working tree has uncommitted changes
- pulls `origin/main`
- installs backend dependencies with `npm ci`
- runs backend tests and syntax check
- if `apps/secret_base_app/.env` exists, builds Flutter web from `SOCKET_URL`, `GOOGLE_CLIENT_ID`, and `KAKAO_REVIEW_AUTO_LOGIN` in that file
- otherwise, builds Flutter web from the shell `SOCKET_URL`, `GOOGLE_CLIENT_ID`, and `KAKAO_REVIEW_AUTO_LOGIN` values
- syncs `build/web/` to `/var/www/secretbase`
- restarts `secretbase-realtime` with PM2
- verifies `http://localhost:4100/health`

## First PM2 Migration Note

PM2 now owns the realtime server as `secretbase-realtime`. If a manually started `npm start` or `node src/index.js` process is already using port `4100`, stop that process before deploying.

```bash
ps -ef | rg 'node src/index.js|npm start'
kill <pid>
./scripts/deploy_server.sh
```

## Useful Overrides

```bash
BRANCH=main WEB_ROOT=/var/www/secretbase SOCKET_URL=https://secertbase.kro.kr ./scripts/deploy_server.sh
```

Do not rely on `SOCKET_URL` or `KAKAO_REVIEW_AUTO_LOGIN` environment overrides when `apps/secret_base_app/.env` exists, because the deploy script reads the `.env` file first.

## Production DB/Redis From Local PC

Use Tailscale SSH tunneling rather than opening MariaDB/Redis publicly:

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key -L 3307:127.0.0.1:3306 -L 6380:127.0.0.1:6379 ubuntu@100.97.58.29
```

Then local `services/realtime-server/.env` can use:

```text
DATABASE_URL=mysql://<server-user>:<server-password>@127.0.0.1:3307/secretbase
REDIS_URL=redis://127.0.0.1:6380
```

This points local development at production data. Use it carefully.
