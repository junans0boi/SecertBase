# Android release signing and launch handoff

Scope: #145, #146 and #147, parent #139. Baseline: `bbb5b2f`.
Package/application ID: `com.secretbase.secret_base_app`.

## Existing key: reference it in place

The existing material belongs to the owner's other worktree:

```text
/Users/junzzang/BACKUP/workspace/SecertBase/.claude/worktrees/agent-a78544b03a2a769ef/apps/secret_base_app/android/key.properties
/Users/junzzang/BACKUP/workspace/SecertBase/.claude/worktrees/agent-a78544b03a2a769ef/apps/secret_base_app/android/keystore/release.jks
```

Do not generate a replacement, copy, move, remove, commit or print these files.
Both `key.properties` and `*.jks` are already ignored by Android's `.gitignore`.
Keep this location available until the owner chooses a durable signing storage
location. A disposable worktree is not a long-term backup of a signing key.

Use Android Studio's bundled JDK and point Gradle at the external properties:

```bash
export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
export KEYSTORE_PROPERTIES_PATH='/Users/junzzang/BACKUP/workspace/SecertBase/.claude/worktrees/agent-a78544b03a2a769ef/apps/secret_base_app/android/key.properties'
cd apps/secret_base_app
flutter build apk --debug --config-only
cd android
./gradlew :app:signingReport --console=plain
```

Configuration-only generation prepares local Flutter/Gradle files; it does not
package an APK. If the wrapper has not been generated, use an installed Gradle
8.14 executable for `:app:signingReport`.
The `release` block must report `Config: release` and the existing external
`release.jks`, with valid certificate fingerprints. Check the output locally;
do not paste credentials or signing files into logs, issues or commits.

Property precedence is: nonblank properties file value, usual environment
variable, legacy environment variable, then `keystore/release.jks` for the store
path only. The external properties path itself is relative to `android/` when
not absolute; without it Gradle uses `android/key.properties`.

| Property | Usual environment | Legacy environment |
| --- | --- | --- |
| `storeFile` | `KEYSTORE_PATH` | `RELEASE_STORE_FILE` |
| `storePassword` | `KEYSTORE_PASSWORD` | `RELEASE_STORE_PASSWORD` |
| `keyAlias` | `KEY_ALIAS` | `RELEASE_KEY_ALIAS` |
| `keyPassword` | `KEY_PASSWORD` | `RELEASE_KEY_PASSWORD` |

An absolute `storeFile` is used as written. A relative `storeFile` is resolved
against the parent directory of the selected properties file, including an
external one. In the environment-only case, relative store paths use
`android/`. A missing explicitly selected properties file, missing store file
or incomplete credentials fails release packaging before compilation. Wrong
passwords or aliases are rejected by Android signing validation.

Debug builds and `signingReport` remain available without release signing.
Release APK/AAB packaging, including assemble/bundle/package/install tasks,
must fail rather than silently use the debug key. For local testing only,
`ALLOW_DEBUG_RELEASE_SIGNING=true` explicitly enables debug-signed release
packaging. Never use this opt-in for Play submission; omit it for certificate
verification and the release build.

## Merged artifact validation (main integrator)

The assigned legal worktree checks configuration and signing reports. The main
integrator builds and validates the merged APK; this change does not claim a
merged APK or device Google login was verified.

```bash
cd apps/secret_base_app
flutter build apk --release --no-pub \
  --dart-define=SOCKET_URL=https://secretbase.cloud \
  --dart-define=GOOGLE_CLIENT_ID='<existing-web-client-id>'
```

Use the Android SDK's `build-tools/<installed-version>/apksigner` locally:

```bash
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Compare the APK certificate SHA-1/SHA-256 with the external-key release report.
An APK signed by Android Debug is not an acceptable release result. Play upload
normally uses an AAB: run `flutter build appbundle --release` with the same
configuration when the main integrator is ready for that artifact.

## Google OAuth: manual console registration remains required

No console credentials were accessed and no OAuth client was registered here.
The owner must perform these steps in the same Google Cloud project as the
existing Web client ID used by `GOOGLE_CLIENT_ID`:

1. Take the SHA-1 from the **release** block of the external-key signing report
   and confirm it against the merged APK certificate.
2. Open [Google Auth Platform → Clients](https://console.cloud.google.com/auth/clients).
   The older console entry is APIs & Services → Credentials → Create
   credentials → OAuth client ID.
3. Choose Create client → Application type **Android**. Enter a descriptive
   name, package name `com.secretbase.secret_base_app`, and the exact release
   certificate SHA-1. Create/save. If that exact package/SHA-1 already exists in
   this project, verify the existing client. Preserve debug clients still used
   for local builds. Do not replace the existing Web client ID with the Android
   client ID; the app sends the Web client ID as `serverClientId`.
4. If Play App Signing signs distributed builds with a different certificate,
   obtain the **app signing certificate** SHA-1 from Play Console → App
   integrity → App signing and register a separate Android client for the same
   package and that fingerprint. The upload key fingerprint alone does not
   identify the Play-delivered app.
5. Install the merged release APK, sign in with Google, log out and sign in
   again. Separately test an app installed from Play's internal test track after
   the Play certificate is registered. If OAuth is in testing mode, ensure the
   tester is an allowed test user. Record success/failure without tokens or
   account data. Console registration and these device checks remain pending.

References: [Google OAuth client setup](https://support.google.com/cloud/answer/15549257),
[Android app signing](https://developer.android.com/studio/publish/app-signing).

## Legal pages: integration prerequisites

Canonical URLs: `https://secretbase.cloud/privacy`, `/terms`, `/delete-account`.
The legacy host alias is **`secertbase.kro.kr`**; the tickets' other spelling is
not a deployment domain. Express serves the canonical paths, trailing-slash
paths and `privacy.html`, `terms.html`, `delete-account.html` and the existing
`account-deletion.html` alias. All HTML copies have canonical links and are
checked against `web/<route>/index.html` to prevent content drift.

Flutter's build copies these route folders plus `web/legal/` into `build/web/`.
The current repository Caddyfile only tries `{path}` before SPA fallback. Caddy
requires a trailing slash to match a directory, so the main integrator must
update **both** production and tester `handle` blocks in
`docs/deployment/Caddyfile` (outside this agent's file ownership):

```diff
- try_files {path} /index.html
+ try_files {path} {path}/ /index.html
```

This matches `/privacy` to `/privacy/` and serves that folder's legal
`index.html`, rather than Flutter's SPA entry. Apply equivalent routing to the
actual Caddy configuration during an authorized deployment; none was changed
here. See [Caddy directory matching](https://caddyserver.com/docs/caddyfile/directives/try_files).
Until this is integrated, a bare canonical URL on the current Caddy configuration
can still return the SPA; Express and direct/trailing-slash static paths work.

Missing owner information: the legal operator's identity, privacy/deletion
request 담당자, and a verified receiving email address. Existing app labels do
not verify mailbox ownership or receipt. The email field and mailto composition
are implemented, but the request button remains disabled while
`web/legal/deletion-request.js` has an empty `verifiedOperatorEmail`. After owner
confirmation, set that value and update all page copies with the confirmed
operator/contact information and enabled-state notice. Validate delivery using
an owner-approved test, never by sending real user data speculatively.

The privacy draft describes actual collection, tombstone deletion, retained
records, media deletion attempts and the documented 30-generation backup policy.
It does not promise complete erasure within 30 days. Full deletion coverage,
backup expiry, operational logs, external providers/transfers and final
retention deadlines require owner confirmation. Legal review is explicitly
unfinished and outside parent #139's implementation scope. Do not mark legal
review, deletion-request availability, deployment or Play readiness complete
based on these local code checks alone.

## Local verification evidence (2026-10-12)

- Red: keyboard Done and revoked consent both sent registration HTTP requests;
  canonical consent URLs used the legacy host and account deletion link was
  absent. Green: all 7 public widget tests pass, including consented button and
  keyboard success, revocation, and all canonical URL launches.
- Red: Express canonical routes returned 404; legal route folders and the email
  request flow were missing. Green: 11 legal/static/request tests plus 4 app
  factory tests pass. Operator-email tests use synthetic `.test` addresses;
  no actual deletion request was sent.
- Red: an external properties path was ignored, release signing used debug,
  and unsigned `assembleRelease --dry-run` succeeded. Green: the original
  external store path resolves with `Config: release` and a valid certificate;
  missing signing rejects assemble/package/bundle release task graphs. Debug
  signing validation and assembly task graph pass. Explicit debug release
  opt-in works; nonexistent external properties rejects release packaging.
- `flutter analyze` for the three owned source files and consent tests: no
  issues. `flutter build web --release --no-pub --no-wasm-dry-run` succeeds;
  all 9 legal HTML/CSS/JS assets in `build/web` match the sources exactly.
- Backend `npm test`: 270 pass, 40 integration tests skipped, no failures when
  `FFMPEG_BIN` references the already-installed root-workspace ffmpeg dependency
  read-only. The first run without that override had one existing Moment Clip
  fixture failure because this worktree's npm install policy blocked the binary
  download script. `npm run check` passes. No DB-backed integration suite was
  enabled and no operational database was accessed.
- Full Flutter suite, full Android APK/AAB build, actual Caddy routing,
  certificate verification of the merged artifact, console registration and
  device sign-in remain the main integrator's checks. No push or deployment was
  performed. Only owned source/test/document files are included in local commits.
