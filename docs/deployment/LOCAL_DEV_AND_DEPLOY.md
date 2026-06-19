# Local Development and Server Deployment

## Goal

Use the local PC for development and Git commits. Use the server only for pulling the latest commit, building, and deploying.

## Recommended Flow

1. Develop on the local PC.
2. Run checks locally.
3. Commit and push to GitHub.
4. SSH into the server.
5. Run the server deploy script.

## Local PC Setup

```bash
git clone https://github.com/junans0boi/SecertBase.git
cd SecertBase
```

Backend:

```bash
cd services/realtime-server
cp .env.example .env  # if an example file is added later
npm ci
npm run dev
```

Flutter app:

```bash
cd apps/secret_base_app
flutter pub get
flutter run -d chrome --dart-define=SOCKET_URL=http://localhost:4100
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
flutter build web --release --no-wasm-dry-run --dart-define=SOCKET_URL=http://secertbase.kro.kr
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
ssh junzzang@<server-ip-or-domain>
cd /home/junzzang/SecertBase
./scripts/deploy_server.sh
```

The deploy script does this:

- refuses to deploy if the server working tree has uncommitted changes
- pulls `origin/main`
- installs backend dependencies with `npm ci`
- runs backend tests and syntax check
- builds Flutter web with `SOCKET_URL=http://secertbase.kro.kr`
- syncs `build/web/` to `/var/www/secretbase`
- restarts `secretbase-realtime` with PM2
- verifies `http://localhost:4100/health`

## First PM2 Migration Note

If a manually started `npm start` or `node src/index.js` process is already using port `4100`, stop that process once before the first PM2-managed deploy. After that, PM2 should own the realtime server.

```bash
ps -ef | rg 'node src/index.js|npm start'
kill <pid>
./scripts/deploy_server.sh
```

## Useful Overrides

```bash
BRANCH=main WEB_ROOT=/var/www/secretbase SOCKET_URL=http://secertbase.kro.kr ./scripts/deploy_server.sh
```
