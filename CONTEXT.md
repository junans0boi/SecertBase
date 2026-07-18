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
https://secertbase.kro.kr       production build, normal login and partner pairing enabled
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

- Couple: the enduring relationship between the same two users that owns their shared private history. A user may retain multiple inactive Couples but may belong to only one active Couple at a time.
- Pairing request: an invitation from one user to another to activate a Couple; knowing a UserCode does not imply consent.
- Partner pairing: the flow where one user sends a Pairing request and the other explicitly accepts it, activating a Couple.
- Pairing-wait state: the normal signed-in state for a user without an active Couple, where they can manage their profile and Pairing requests but cannot enter shared couple features.
- Separation: unilateral deactivation of a Couple without deleting its shared history; either user may leave without the other user's consent.
- Reunion: reactivation of an inactive Couple after a new Pairing request is accepted by the same two users, restoring access to their previous shared history.
- Room: the realtime Socket.IO room for one couple.
- RoomCode: stable room identifier returned by profile/couple APIs.
- RoomSecret: shared secret used by the client to join the realtime room.
- UserCode: short public user identifier used for pairing and realtime presence.
- HomeShell: the paired/logged-in app shell shown after auth and socket connection.
- Archive: persistent couple content such as setlog, map pins, daily Q&A, challenges, jukebox, and capsules.
- Setlog: an author-owned daily text/image/video record shared for viewing within its active Couple; only its author may change or delete it.
- Album (우리 앨범): if built, a read-only gallery over media attached to the couple's Setlog records — never a separate upload destination. Not exposed in the first release; whether it exists at all awaits private-beta feedback (2026-07-18 decision). Legacy folder/photo data is not part of any album contract.
- One Card (원카드): the couple card game formerly labeled UNO. The user-visible name and card artwork are Secret Base originals to avoid Mattel trademark/trade dress; internal identifiers may still say `uno`.
- Zero (제로): the standalone arcade game split out of the RPS 하나빼기 mode; presented as its own game, not an RPS mode.
- Drawing Quiz (그림 맞히기): the drawing-and-guessing game formerly labeled 캐치마인드; renamed to avoid the Netmarble trademark. Internal identifiers still say `catch`.
- Game lobby: pre-game realtime waiting state before yut, One Card, bomb, or lightweight games start.
- Realtime game state: ephemeral Redis-backed state for active games.
- Production DB: the MariaDB database used by the deployed service. Local tests against it mutate real data.

## Current Deployment State

As of 2026-07-13:

- DNS for `test.secertbase.kro.kr` points at the same Server 2 IP as `secertbase.kro.kr`.
- Caddy serves `secertbase.kro.kr` from `/var/www/secretbase`.
- Caddy serves `test.secertbase.kro.kr` from `/var/www/secretbase-test`.
- Both domains proxy `/api/*`, `/uploads/*`, `/health`, and `/socket.io/*` to `127.0.0.1:4100`.
- Backend `CORS_ORIGIN` on the server must include both `https://secertbase.kro.kr` and `https://test.secertbase.kro.kr`.
- Server `apps/secret_base_app/.env` currently has `KAKAO_REVIEW_AUTO_LOGIN=false`; both production and tester builds should show normal login.

Deployment matrix:

```text
Purpose     Domain                         Web root                  Socket URL                         Review auto-login
Production  https://secertbase.kro.kr      /var/www/secretbase       https://secertbase.kro.kr          false
Tester      https://test.secertbase.kro.kr /var/www/secretbase-test  https://test.secertbase.kro.kr     false
```

Tester deploy command on Server 2:

```bash
cd ~/SecertBase
./scripts/deploy_test_server.sh
```

## Current Operational Risk

Production and staging:

- `secertbase.kro.kr` is the primary production build with full login and all features enabled as of 2026-07-14.
- `test.secertbase.kro.kr` remains available as a tester URL.
- Kakao JavaScript Maps SDK: 200 OK on both domains (domains registered in Kakao Developers).
- Kakao REST Local API: working, key set in server `.env`.

DB migrations applied 2026-07-14 (via `ensureTables` ALTER TABLE on server restart):

- `album_folders`: `sort_order`, `description`, `cover_url` added ✅
- `album_photos`: `caption`, `is_premium_quality`, `file_size_kb` added ✅
- `private_reflections`: `mood_tag`, `category` added ✅
- `map_pins`: `couple_id`, `user_id`, `status`, `emotion_tags` added ✅
- `Users`: `is_premium`, `premium_since`, `premium_expires_at` added ✅
- `premium_subscriptions` table created ✅
- Existing `map_pins` backfilled with `couple_id`/`user_id` from `created_by` UserCode ✅

Recently completed Secret Map slice:

- MomentLoop ↔ 비밀지도 setlog 연결: map detail now loads `/api/setlog?user_id=...` and shows matching MomentLoop records by visit date/place text.
- `map_pins` PATCH/DELETE use JWT identity: either active partner can update shared fields, while only the original author can delete. Linked pins are archived.
- `PATCH /api/map/:id` now persists `rating`, `memo`, `visit_date`, `status`, and `emotion_tags`.

Recently completed relationship management slice:

- Users can disconnect via `DELETE /api/user/partner`; the Couple becomes inactive and same-pair acceptance restores it.
- Disconnect clears both users' `PartnerCode` values and deletes the active `Couples` row so either user can pair again later.
- Existing archive rows tied to the old `couple_id` are preserved but no longer appear under a future new couple.

Resolved deployment divergence:

- server-only commit `e792dc7` was recovered into `origin/main` as `b190e9a`
- production server `main` and `origin/main` were aligned at `b190e9a`
- Google login schema fixes and Caddy/deployment recovery were deployed and verified

Remaining Secret Map product/security risk:

- `/api/map` scope and creator identity are derived from JWT. Active partners share edits; creator-only deletion archives linked pins.
- Socket.IO authenticates the handshake JWT and derives the active Couple room server-side; client room secrets and shared-secret bypasses are not accepted.

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
