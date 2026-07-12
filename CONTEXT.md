# Secret Base Agent Context

Last updated: 2026-07-12

This file is the first project context document for Claude, Codex, or any AI coding agent.
Read this before planning, editing, debugging, or reviewing code in this repository.

## Product

Secret Base is a private two-person couple app. It combines:

- account login and partner pairing
- a shared couple home screen
- realtime two-player arcade games
- archive features for shared memories, Q&A, maps, challenges, jukebox, and capsules

Production and staging URLs:

```text
https://secertbase.kro.kr       Kakao review build, temporarily loginless/auto-login for map review
https://test.secertbase.kro.kr  tester build, normal login and partner pairing enabled
```

## Current Architecture

```text
Flutter Web/Android
  -> REST API: /api/*
  -> Socket.IO: /socket.io/

Node.js realtime-server
  -> Express REST API
  -> Socket.IO realtime events
  -> Redis for room/game state
  -> MariaDB/MySQL for persistent user, couple, and archive data
```

Main paths:

```text
apps/secret_base_app/        Flutter app
services/realtime-server/    Node.js Express + Socket.IO backend
services/realtime-server/schema.sql
docs/                        Product, API, socket, deployment docs
scripts/deploy_server.sh     Production deploy script
```

Current Server 2 access:

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key -t ubuntu@100.97.58.29 'cd ~/SecertBase && exec bash -l'
```

## Source Of Truth

Use these files first:

- Product and architecture: `docs/PROJECT_OVERVIEW.md`
- REST contract: `docs/REST_API.md`
- Socket contract: `docs/SOCKET_EVENTS.md`
- Deployment/local dev: `docs/deployment/LOCAL_DEV_AND_DEPLOY.md`
- Current handoff/risk: `HANDOFF.md`
- Roadmap: `docs/ROADMAP.md`

Known stale docs:

- `PROGRESS_SUMMARY.md`, `DEVELOPMENT_LOG.md`, and parts of `docs/WORKLOG.md` still mention PostgreSQL.
- The current backend uses MariaDB/MySQL through `mysql2`, not PostgreSQL.
- Treat `docs/PROJECT_OVERVIEW.md`, `docs/ROADMAP.md`, `docs/REST_API.md`, and live code as newer than those stale references.

## Domain Language

- Couple: the two linked users who share one private app space.
- Partner pairing: the flow where two users connect into a couple.
- Room: the realtime Socket.IO room for one couple.
- RoomCode: stable room identifier returned by profile/couple APIs.
- RoomSecret: shared secret used by the client to join the realtime room.
- UserCode: short public user identifier used for pairing and realtime presence.
- HomeShell: the paired/logged-in app shell shown after auth and socket connection.
- Archive: persistent couple content such as setlog, map pins, daily Q&A, challenges, jukebox, and capsules.
- Setlog: daily text/image/video record stored through `/api/setlog`.
- Game lobby: pre-game realtime waiting state before yut, UNO, bomb, or lightweight games start.
- Realtime game state: ephemeral Redis-backed state for active games.
- Production DB: the MariaDB database used by the deployed service. Local tests against it mutate real data.

## Current Deployment State

As of 2026-07-12:

- DNS for `test.secertbase.kro.kr` points at the same Server 2 IP as `secertbase.kro.kr`.
- Caddy serves `secertbase.kro.kr` from `/var/www/secretbase`.
- Caddy serves `test.secertbase.kro.kr` from `/var/www/secretbase-test`.
- Both domains proxy `/api/*`, `/uploads/*`, `/health`, and `/socket.io/*` to `127.0.0.1:4100`.
- Backend `CORS_ORIGIN` on the server must include both `https://secertbase.kro.kr` and `https://test.secertbase.kro.kr`.
- Server `apps/secret_base_app/.env` currently has `KAKAO_REVIEW_AUTO_LOGIN=true` for the Kakao review build. Do not use the deploy script blindly for the tester build unless you override or bypass that `.env`.

Deployment matrix:

```text
Purpose       Domain                         Web root                  Socket URL                         Review auto-login
Kakao review  https://secertbase.kro.kr      /var/www/secretbase       https://secertbase.kro.kr          true on current server .env
Tester        https://test.secertbase.kro.kr /var/www/secretbase-test  https://test.secertbase.kro.kr     false
```

Tester deploy command on Server 2:

```bash
cd ~/SecertBase
./scripts/deploy_test_server.sh
```

## Current Operational Risk

Kakao review and staging:

- `secertbase.kro.kr` is under Kakao Developers review, so it is intentionally kept as the review-accessible build for now.
- `test.secertbase.kro.kr` is the working tester URL with normal login. Use it for friends and external testers until Kakao review is complete.
- Add `https://test.secertbase.kro.kr` in Kakao Developers web domain and JavaScript SDK domain settings before testing Kakao SDK calls there.

Production schema issue found on 2026-07-12:

- PM2 logs show `/api/album/folders` fails with `Unknown column 'sort_order' in 'ORDER BY'`.
- The backend query expects `album_folders.sort_order`, but the production MariaDB schema appears not to have that column.
- Fix with a schema migration or compatibility query before relying on the album folder feature.

Resolved deployment divergence:

- server-only commit `e792dc7` was recovered into `origin/main` as `b190e9a`
- production server `main` and `origin/main` were aligned at `b190e9a`
- Google login schema fixes and Caddy/deployment recovery were deployed and verified

The most important active product/security risk is now the Secret Map scope:

- `/api/map` currently reads all `map_pins`
- map pin creation/update trust client-provided identifiers or raw ids
- before launch, map data must be scoped to the authenticated couple/user

See `HANDOFF.md` for the latest Secret Map planning notes.

## Testing And Feedback Loops

Backend:

```bash
cd services/realtime-server
npm test
npm run check
```

Flutter:

```bash
cd apps/secret_base_app
flutter test
```

Use a tight pass/fail loop before editing bugs:

- backend API bug: failing Node test or repeatable curl/HTTP script
- socket/game bug: engine test first when possible, then socket harness if needed
- Flutter UI bug: widget test or browser/manual repro with exact steps
- deployment bug: command transcript from server/GitHub Actions plus a minimal command to verify the fix

## AI Workflow Rules

Use small vertical slices. A useful issue should normally pass through the relevant layers:

```text
database/schema or state -> backend contract -> frontend integration -> test/check
```

Do not split work as "all DB first", "all API second", "all UI third" unless the user explicitly asks.

For new behavior:

1. Align on behavior and terms.
2. Update this `CONTEXT.md` if new domain language appears.
3. Write or identify the smallest test/check that can fail.
4. Implement the smallest vertical slice.
5. Run the relevant test/check.
6. Update docs only when contracts or operational behavior changed.

For bugs:

1. Build the feedback loop first.
2. Reproduce or capture the failure.
3. Generate 3-5 falsifiable hypotheses.
4. Instrument only when needed, using a temporary unique debug tag.
5. Fix and add/keep a regression check.
6. Remove temporary logs and summarize the prevention lesson.

## Local Development Notes

Production-like local web testing may use a local reverse proxy so browser requests stay same-origin while `/api`, `/socket.io`, `/uploads`, and `/health` proxy to production.

Be careful with production DB tunnels:

```bash
ssh -L 3307:127.0.0.1:3306 -L 6380:127.0.0.1:6379 junzzang@100.82.126.57
```

Any local backend pointed at that tunnel can mutate production data.
