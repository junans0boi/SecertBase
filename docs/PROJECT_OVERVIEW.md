# Secret Base Project Overview

## Current MVP

The public MVP is the mobile-web Couple core: consent-based pairing, persistent
separation/reunion, D-day, MomentLoop text/photo/10-second clips, Secret Map,
Yut/Bomb/RPS, and author-only inactive-history export. REST and Socket identity
come from JWT, and a user can have only one active Couple. Deferred Archive and
game surfaces remain feature-gated; UNO is absent from the public UI/assets.

Last updated: 2026-06-20

## What This Project Is

Secret Base is a private two-person realtime web/app service. It combines:

- account login and partner pairing
- Google login without Firebase
- a shared couple home screen
- realtime arcade games
- archive features for daily records, maps, Q&A, challenges, jukebox, and capsules

The production web app is served at:

```text
https://secertbase.kro.kr
```

## Repository Layout

```text
apps/secret_base_app/        Flutter app for Web and Android
services/realtime-server/    Node.js Express + Socket.IO backend
docs/                        Product, API, socket, and deployment docs
scripts/deploy_server.sh     Server build/deploy script
```

Reference-only local folders that should not be committed unless intentionally promoted:

```text
trash/                       Screenshots/reference images
uno/                         Raw UNO reference sound assets
```

## Runtime Architecture

```text
Flutter Web/App
  -> REST API over HTTPS: /api/*
  -> Socket.IO over HTTPS/WSS: /socket.io/

Nginx
  -> serves Flutter build from /var/www/secretbase
  -> proxies /api, /uploads, /health, /socket.io to Node on localhost:4100

Node realtime-server
  -> Express REST API
  -> Socket.IO realtime events
  -> Redis for ephemeral room/game state
  -> MariaDB for account/couple/archive persistence
```

## Production Infrastructure

- Domain: `secertbase.kro.kr`
- Web server: nginx
- HTTPS: Let's Encrypt certificate
- Static root: `/var/www/secretbase`
- Backend path: `/home/junzzang/SecertBase/services/realtime-server`
- Backend port: `4100`
- Backend process manager: PM2 service named `secretbase-realtime`
- MariaDB: local server, accessed by backend through `DATABASE_URL`
- Redis: local server, accessed by backend through `REDIS_URL`
- SSH from outside: prefer Tailscale, server IP `100.82.126.57`

## Frontend App Flow

Entry point: `apps/secret_base_app/lib/main.dart`

Current screen flow:

1. `AuthService.init()` restores saved token and user data from SharedPreferences.
2. If no token exists, app shows `LoginScreen`.
3. If logged in but not paired, app shows `PartnerScreen`.
4. If paired, app auto-connects Socket.IO using `RoomCode`, `RoomSecret`, and `UserCode`.
5. When socket is connected, app shows `HomeShell`.

Important client services:

- `core/auth_service.dart`: register, login, partner pairing, profile refresh
- `widgets/google_sign_in_button.dart`: platform-specific Google login button wrapper
- `core/socket_service.dart`: Socket.IO connection and game state
- `core/server_config.dart`: server URL resolution
- `core/uno_audio.dart`, `core/yut_audio.dart`: game sound playback

Server URL behavior:

- In production web, the app uses `Uri.base.origin`, so HTTPS domain deployment works without a separate hardcoded API host.
- In local Flutter dev, pass `--dart-define=SOCKET_URL=http://localhost:4100` or a LAN/Tailscale URL.

## Backend Modules

Backend entry: `services/realtime-server/src/index.js`

- `config.js`: validates `.env`
- `db.js`: MariaDB query/transaction wrapper
- `redis.js`: Redis client
- `routes.js`: REST API
- `socket.js`: Socket.IO event handlers
- `uno-engine.js`: UNO deck/rules
- `yut-engine.js`: 윷놀이 state machine
- `bomb-engine.js`: bomb quiz/pass logic

Required backend env keys are documented in `services/realtime-server/.env.example`.

Google login requires the same OAuth Web Client ID in two places:

- backend `.env`: `GOOGLE_CLIENT_ID`
- Flutter build: `--dart-define=GOOGLE_CLIENT_ID=<client-id>`

## Realtime Games

Game lobby types:

```text
dice
roulette
rps
telepathy
pirate
yut
uno_classic
uno_go_wild
bomb
```

UNO is selected through a mode screen before entering the lobby:

- `uno_classic` starts server mode `classic`
- `uno_go_wild` starts server mode `go_wild`
- `go_wild` is the backend default

### UNO Current Rules

- 2 players, 7 initial cards
- classic mode excludes `discard_all`
- go wild mode includes colored `discard_all`
- `discard_all` is a colored card: playing it discards every remaining card of that color from the same hand
- +2/+4 draw stack defense is enabled only in go wild mode
- +4 challenge is implemented
- UNO call/catch uses one unified visible client button
- Gift reactions are supported: cake, candy, coffee, pizza, pillow, tomato, flyby, sportscar
- Gift reactions play local wav assets and show throw-like burst animations

### Yut Current Rules

- 2 players
- roll-order phase before real play
- characters: `honggilldong`, `nolbu`, `miho`
- optional BGM: `yut1.mp3`, `yut2.mp3`, `yut3.mp3`
- supports do/gae/geol/yut/mo/backdo
- yut/mo bonus throws
- backdo can become `nak` when no piece can move backward
- catches, carried pieces, shortcut routes, and finish detection are server-driven

### Bomb Current Rules

- 2 players
- configurable duration 10-120 seconds, default 30
- current holder answers quiz
- correct answer passes bomb to opponent with a new quiz
- wrong answer is broadcast but game continues
- timeout explodes and ends the game

### Lightweight Realtime Games

The server also supports synchronized one-shot or simple two-choice games:

- dice
- roulette
- rock-paper-scissors
- telepathy
- pirate roulette

## Archive Features

REST-backed archive screens include:

- Setlog/Moment Loop: text/image/video entries via `/api/setlog`
- Map pins: `/api/map`
- Daily Q&A: `/api/qa/today`, `/api/qa/answer`
- Challenges: `/api/challenges`, `/api/challenges/:id/log`
- Jukebox: `/api/jukebox`
- Couple info and D-day: `/api/couple/info`
- Time capsules: `/api/capsules`

## Deployment Flow

Normal server deployment:

```bash
cd /home/junzzang/SecertBase
./scripts/deploy_server.sh
```

The script:

1. refuses to deploy when tracked files are dirty
2. pulls `origin/main`
3. runs backend install/test/check
4. runs `flutter pub get`
5. builds Flutter Web with `SOCKET_URL=https://secertbase.kro.kr`
6. syncs `build/web/` to `/var/www/secretbase`
7. starts or restarts PM2 process `secretbase-realtime`
8. waits for `http://localhost:4100/health`

## Local Development

Backend:

```bash
cd services/realtime-server
cp .env.example .env
npm ci
npm run dev
```

Flutter web:

```bash
cd apps/secret_base_app
flutter pub get
flutter run -d chrome --dart-define=SOCKET_URL=http://localhost:4100
```

Using the production DB/Redis from a local Mac should be done through Tailscale + SSH tunnel:

```bash
ssh -L 3307:127.0.0.1:3306 -L 6380:127.0.0.1:6379 junzzang@100.82.126.57
```

Then local `.env` can point to:

```text
DATABASE_URL=mysql://user:password@127.0.0.1:3307/secretbase
REDIS_URL=redis://127.0.0.1:6380
```

Be careful: this mutates production data.
