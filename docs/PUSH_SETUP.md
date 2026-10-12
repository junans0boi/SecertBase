# Push and local notifications (#143 / #156)

Android and web are supported; APNs/iOS remain out of scope. Firebase configuration
is optional: missing configuration disables remote push without blocking startup.
Android local upload-failure notifications initialize independently of Firebase.
No real keys or service-account credentials are committed.

## Android

Supply the Firebase Android project's ignored `android/app/google-services.json`
for the app's application ID. Notification permission is requested after couple
connection. A denied result prevents token acquisition and server registration.
The app checks current permission on later syncs, so enabling permission in system
settings is honored. Native Firebase setup/build integration is owned by the
Android integration agent; verify its Gradle configuration before device testing.

## Web build and runtime config

Create a local, uncommitted JSON defines file outside the repository with:

```json
{
  "FIREBASE_WEB_API_KEY": "<public web API key>",
  "FIREBASE_WEB_APP_ID": "<web app ID>",
  "FIREBASE_MESSAGING_SENDER_ID": "<sender ID>",
  "FIREBASE_PROJECT_ID": "<project ID>",
  "FIREBASE_WEB_VAPID_KEY": "<public VAPID key>"
}
```

From `apps/secret_base_app`:

```sh
flutter build web --release --dart-define-from-file=/absolute/local/firebase-web-defines.json
node lib/core/push/generate_worker_config.mjs /absolute/local/firebase-web-defines.json build/web
```

The generation step writes only `build/web/firebase-push-config.json`. The page
loads that public file with `cache: no-store`, falling back to build defines when
the file is missing. For runtime configuration, build without defines and generate
the file afterward with the same command. No service-worker source edits needed.
Do not pass Firebase Admin/private service-account JSON to this generator.

The page registers `/firebase-messaging-sw.js` explicitly under `/messaging/`,
waits for activation, and passes the exact `ServiceWorkerRegistration` to the
[supported Firebase JS getToken API](https://firebase.google.com/docs/reference/js/messaging.gettokenoptions).
The worker receives the same public Firebase config in its script query. Cache
cleanup preserves the `/messaging/` registration. Host at the origin root over
HTTPS (localhost also works), serve the worker as JavaScript and the config as
JSON. Missing or incomplete configuration initializes neither Firebase nor a
worker. Builds require no configuration. Keep the generated JSON with the
published build; Flutter rebuilds can replace build output.

## Targets and shared notification API

`lib/core/push/push_target.dart`: `PushTarget(screen:, postId:, gameType:,
roomCode:, draftId:)`. Wire payload keys are `screen`, `post_id`, `game_type`,
`room_code`, `draft_id`. Payloads remain intact through Android remote/local taps,
web worker `postMessage`, and cold-start URL queries.

Routes: `moment_detail` → `MomentLoopScreen(initialPostId:)`; `moment_draft` →
`MomentLoopScreen(initialDraftId:)`; `today_loop` → fetched `TodayLoopViewer`;
`game_invite` → the matching `GameLobbyScreen` and actual game screen. Game invites
must match the authenticated socket's couple room; another room is rejected.
The MomentLoop constructor parameters are supplied by the frontend/outbox agent.

`lib/core/push/local_notification_service.dart`:

```dart
await LocalNotificationService.instance.start();
await LocalNotificationService.instance.showUploadFailure(draftId);
// Parent integrates the outbox's injectable callback after its implementation:
// onFailure: LocalNotificationService.instance.showUploadFailure
```

`main.dart` initializes local notifications. The parent owns outbox startup wiring.
Local notifications still require OS permission; initializing the plugin does
not grant it. Unsupported platforms or notification failures do not lose drafts.

## Verification

```sh
flutter test test/push_service_test.dart test/local_notification_service_test.dart test/notification_settings_screen_test.dart
node --test test/notification_web_test.cjs
flutter analyze
flutter build web --release
```

Client worktree verification (baseline `bbb5b2f`): targeted Flutter tests pass
(17 tests), web bridge/worker/config generation tests pass (7 tests), scoped
analysis of push core, settings and their tests passes. Full app analysis and
web compilation require the frontend agent's `MomentLoopScreen.initialPostId`
and `initialDraftId` constructor additions; the baseline screen has neither.
Do not call those integration checks complete before merging that dependency.

Reproduced red → green: logout while token registration is pending; failed revoke
blocking another identity's registration; startup tap loss; web clicks losing
query fields/opening another window; selecting a same-origin privacy page;
missing quiet-hours/reveal controls. Permission denial, repeated login/start,
late token lookup, save rollback/disposal and actual Today viewer data loading
are additionally covered.

Manual checks with real Firebase configuration: two-user Android/web receipt,
foreground/background and cold/running taps, Android 13+ permission denial/grant,
logout during registration, token refresh, every game invite context, cron reveal,
quiet hours and per-type preferences. No production deployment or database access
is needed for the automatic client checks.
