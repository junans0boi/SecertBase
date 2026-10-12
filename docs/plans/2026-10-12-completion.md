# Handoff completion — authorized 2026-10-12

Baseline: bbb5b2f. Local implementation, commits and integration authorized.
Push, production deployment/database access and issue closure remain gated.

1. Backend: migration 0044; position/idempotent creation; session edits/order; revealed media protection.
2. Frontend: reorder, full editing, durable outbox/retry/drafts, grid persistence and image compression.
3. Notifications: recipient identity/payload, delivery retries, quiet hours/reveal hour; token lifecycle, exact routes and web worker.
4. Games: real telepathy expiry/late responses and reward/reconnect regressions.
5. Legal/signing: consent guard, local canonical legal routes, release signing fail-fast with existing external key.
6. Map: successful save collapses; failed save preserves inputs and state.
7. Integrate; run isolated MariaDB/Redis integration tests, Flutter tests/analyze, Web and signed Android builds.
8. Review the final diff against #138–158; update handoff/report with evidence and honest remaining external checks.

## Shared contracts

- POST /api/setlog accepts position (0–32767) and client_request_id (1–64 chars); first 201, replay 200 with existing post; replays remove new upload and do not repeat side effects.
- PATCH /api/setlog/session/:sessionId updates caption/taken_at/tags/map_pin_id atomically for an author's active-Couple group.
- PATCH /api/setlog/session/:sessionId/order accepts all owned ids in order.
- GET posts carry position and media_edit_locked; session_id immutable, revealed Today Moment group cannot add/delete media.
- Push data carries screen plus post_id/session_id or game_type/room_code; numeric UserId is the server notification identity.
- Notification preferences: partner_moment, today_loop, game_invite, quiet_hours_enabled, quiet_start, quiet_end, reveal_hour; defaults true/true/true/true/22:00/08:00/21, KST.
- MomentLoopScreen accepts initialPostId and initialDraftId; upload failure handler opens the persisted draft.

## Evidence boundaries

REST responses, Socket events, widget actions, persisted queue retry outcomes;
FCM is mocked at the external sender boundary. Production OAuth/FCM and device
delivery require actual external credentials and user-side checks. #148's
original symptom needs the affected screen/date; inspect all safe paths while
waiting. Existing keystore stays untouched and secrets stay ignored.
