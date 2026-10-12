# Push server setup and contract

The backend uses MariaDB/MySQL (`mysql2`), Redis, `firebase-admin` and `node-cron`.
Apply migrations using the normal migration workflow before starting the server.
`0043_push_notifications.sql` creates `device_tokens` and `notification_prefs`;
`0045_notification_delivery_settings.sql` adds these required settings columns:

| Column | Type | Default |
| --- | --- | --- |
| quiet_hours_enabled | TINYINT(1) NOT NULL | 1 |
| quiet_start | CHAR(5) NOT NULL | 22:00 |
| quiet_end | CHAR(5) NOT NULL | 08:00 |
| reveal_hour | TINYINT UNSIGNED NOT NULL | 21 |

The startup schema-readiness check must include both notification tables and the
four new columns. Existing applied migrations must keep their checksums.

## Credentials

Enable the Firebase Cloud Messaging API for the same Firebase project used by
the Android/web clients. Configure one of the actual server environment keys:

- `GOOGLE_APPLICATION_CREDENTIALS`: absolute path to a service-account JSON file
  outside the repository, readable by the server process.
- `FIREBASE_SERVICE_ACCOUNT_JSON`: the complete service-account JSON supplied by
  a secret manager. This takes precedence over the file environment key.

Never commit credentials, paste them into logs, or include real device tokens in
debug output. Existing `DATABASE_URL`, `REDIS_URL`, `REDIS_KEY_PREFIX`, and
`JWT_SECRET` settings continue to configure the normal runtime. There is no
`FCM_SERVER_KEY` environment setting. No Firebase credentials means the sender
is disabled and notification calls return `skipped: 'no_sender'`; API operations
and other application work remain available. SDK initialization is lazy and can
retry after an initialization failure. The installed Admin SDK uses
`firebase-admin/app` and `firebase-admin/messaging` modular APIs.

See the official [Admin SDK sending guide](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk)
and [FCM error reference](https://firebase.google.com/docs/cloud-messaging/error-codes).
Real Android/web receipt and tap routing require client Firebase configuration
and a manual device/browser check. iOS/APNs is outside #143's scope.

## Authenticated REST API

All paths below are under `/api` and require the normal Bearer JWT. The numeric
user ID is derived from that JWT. Client identity overrides are rejected by the
normal auth middleware. The notification router also rejects a missing or
invalid authenticated identity before database access.

- `POST /device-token`: `{ "token": "<FCM token>", "platform": "android" }`.
  Platforms: `android`, `web`, `ios`. Optional `appVersion` is stored up to 32
  characters. Tokens must be nonempty strings of at most 512 characters. Upsert
  refreshes `last_seen_at`, clears revocation and transfers a shared device token
  to the current user on re-login.
- `DELETE /device-token`: `{ "token": "<FCM token>" }`. Revokes only a token
  owned by the authenticated user. Repeating it is harmless.
- `GET /notification-prefs`: returns `{ "ok": true, "prefs": ... }` with every
  field shown below, including when no preference row exists.
- `PUT /notification-prefs`: accepts a nonempty partial object of these fields.
  Booleans must be booleans, clock times must be `HH:mm` in 24-hour format, and
  `reveal_hour` must be an integer from 0 to 23. Unknown fields are rejected.
  Omitted fields retain their existing values; a new row uses database defaults.
  Returns `{ "ok": true }`; GET returns the saved settings.

```json
{
  "partner_moment": true,
  "today_loop": true,
  "game_invite": true,
  "quiet_hours_enabled": true,
  "quiet_start": "22:00",
  "quiet_end": "08:00",
  "reveal_hour": 21
}
```

## Sending and scheduling

`createNotifier` exposes `notifyPartner(numericUserId, type, extraData = {})` and
`notifyUser(numericUserId, type, extraData = {})`. Partner resolution uses the
current active Couple. Invalid numeric IDs are skipped. All failures are kept
out of the triggering request. Each recipient's type preference and quiet hours
are checked before sending to non-revoked tokens. Quiet hours use KST regardless
of host timezone, include their start and exclude their end. Same-day ranges
work too; equal start/end means an empty quiet interval.

Notification title/body are fixed generic text. Extra data is allowlisted and
stringified for FCM, so captions, place names and arbitrary app content never
enter the preview or data payload:

| Type | data.screen | Allowed context |
| --- | --- | --- |
| partner_moment | moment_detail | post_id, session_id |
| today_loop | today_loop | business_date |
| game_invite | game_invite | game_type, room_code |

Provide Moment metadata from the creation callback and invite context from the
game handler. Values cannot replace `screen` or `type`. FCM sends at most 500
tokens per batch. Per-token invalid registration responses revoke that token;
temporary failures keep it registered. A rejected whole request (including an
invalid payload) is not evidence that its individual tokens are invalid.

The every-minute cron uses `Asia/Seoul` with overlapping invocations disabled.
It scans revealed Today Loops for active Couples for the current and previous
KST date. Same-day delivery waits until the recipient's `reveal_hour` (21 by
default); the notifier checks quiet hours. A late reveal skipped overnight can
deliver next morning. Previous-day retries expire from consideration after that
day, so this is a bounded reminder scan rather than a permanent message queue.

Redis keys use `push:today_loop:<couple_id>:<business_date>:<user_id>` under the
configured runtime namespace. Each recipient has a five-minute NX lease,
released with an ownership-checked Lua operation in `finally` on success,
failure and skips. Success is recorded only after FCM accepts delivery. The
48-hour completed-recipient key prevents resending to a successful partner;
the 48-hour successful-token set prevents resending to successful devices while
another device is retried. Disabled prefs, quiet hours, absent credentials and
no-device skips leave no completed marker and may recover on a later tick.

FCM acceptance is not proof of device receipt. A process crash or Redis failure
between FCM acceptance and persisting the success state can still cause a retry;
FCM and Redis do not share an atomic transaction. Redis state loss can also
remove dedupe history. Actual network timing, Redis recovery and a send that
outlives its five-minute lease are not covered by the local checks.

## Local verification

```sh
cd services/realtime-server
node --test test/notification-router.test.js test/notifications.test.js test/notification-scheduler.test.js
npm test
npm run check
```

`test/notifications.integration.test.js` uses real disposable MariaDB/Redis and
a mocked sender. Start dedicated loopback-only test services at ports 33399 and
63399, create a test-only MariaDB administrator, then set
`NOTIFICATION_TEST_DATABASE_ADMIN_URL` (`mysql://<test-user>@127.0.0.1:33399/mysql`)
and `NOTIFICATION_TEST_REDIS_URL` (`redis://127.0.0.1:63399`) and run:

```sh
node --test test/notifications.integration.test.js
```

These tests skip when the two explicit variables are absent, reject normal
runtime ports, create a unique `secretbase_test_*` database and Redis namespace,
apply all migrations, and clean up only their own fixtures. They verify JWT
checks, upsert/reassignment/revocation through REST and sender outcomes, partial
settings round trips, and real Redis retry/dedupe behavior without contacting FCM.
