# Google Login Setup

Last updated: 2026-06-20

Secret Base uses Google Sign-In without Firebase:

```text
Flutter -> Google ID token -> /api/auth/google -> verify token -> Secret Base JWT
```

Implementation references:

- Flutter package: `google_sign_in`
- Web button package: `google_sign_in_web`
- Backend verifier: `google-auth-library`

## Google Cloud Console

Create an OAuth 2.0 Web application client.

Authorized JavaScript origins should include:

```text
https://secertbase.kro.kr
http://localhost
http://localhost:7357
```

Use a fixed local web port when testing Google login:

```bash
flutter run -d chrome \
  --web-hostname localhost \
  --web-port 7357 \
  --dart-define=SOCKET_URL=http://localhost:4100 \
  --dart-define=GOOGLE_CLIENT_ID=<google-web-client-id>
```

## Server Env

Set this in `services/realtime-server/.env` on the server:

```env
GOOGLE_CLIENT_ID=<google-web-client-id>
```

Restart backend after changing it:

```bash
pm2 restart secretbase-realtime --update-env
```

## Flutter Build

The same client ID must be passed to Flutter at build time:

```bash
flutter build web --release --no-wasm-dry-run \
  --dart-define=SOCKET_URL=https://secertbase.kro.kr \
  --dart-define=GOOGLE_CLIENT_ID=<google-web-client-id>
```

The deploy script reads `GOOGLE_CLIENT_ID` from the shell environment:

```bash
GOOGLE_CLIENT_ID=<google-web-client-id> ./scripts/deploy_server.sh
```

If `GOOGLE_CLIENT_ID` is empty, the Google login button is hidden in the Flutter login screen and `/api/auth/google` returns `google_login_not_configured`.

## Database Behavior

On first Google login, the server:

1. verifies the ID token audience against `GOOGLE_CLIENT_ID`
2. finds an existing user by `GoogleSubject` or email
3. links the Google subject to that user, or creates a new user
4. creates `User_Preference` for new users
5. returns the normal Secret Base JWT and user object

The server lazily adds these nullable columns to `Users` if missing:

```text
AuthProvider
GoogleSubject
GooglePictureUrl
```
