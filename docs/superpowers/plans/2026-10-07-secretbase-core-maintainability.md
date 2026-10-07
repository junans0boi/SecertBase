# SecretBase Core Maintainability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep SecretBase usable while moving Home and MomentLoop behind maintainable feature boundaries, preserving existing game behavior and REST/Socket contracts, then verify the local app with the supplied test account through Playwright.

**Architecture:** Core-first modular monolith migration. Flutter screens depend on feature controllers/repositories, repositories use one authenticated HTTP boundary, and Node gains app composition, explicit access context, and one server feature registry. Games remain a legacy Play island.

**Tech Stack:** Flutter/Dart, `ChangeNotifier`, Node.js ESM, Express, Socket.IO, MariaDB/mysql2, Redis, Playwright Test.

**Spec:** `docs/superpowers/specs/2026-10-07-secretbase-core-maintainability-design.md`

## Global Constraints

- Home, MomentLoop, Couple/auth, and their seams are in scope; game screens and engines remain behaviorally unchanged.
- Existing REST and Socket contracts remain compatible.
- No Riverpod, Bloc, GoRouter, microservices, unrelated visual redesign, or game rewrite.
- Do not run migrations, DDL, fixtures, pairing, account mutation, deletion, or uploads against the operational DB without a read-only precheck.
- Credentials never enter git, logs, traces, screenshots, or reports.
- Unit tests use fakes/isolated environments. Operational DB/Redis is used only by the local backend/E2E path.
- Required loops: `cd apps/secret_base_app && flutter test`; `cd services/realtime-server && npm test && npm run check`.
- Playwright is read-only after login: Home, MomentLoop, feed read, refresh, diagnostics on failure only.

## Review Focus

- Unpaired authenticated account stays on pairing instead of requesting Couple/Socket data: auth/Home tests and Playwright branch.
- Partial Home failure leaves other cards usable and retryable: `home_controller_test.dart`.
- 401/403/network/non-JSON responses become safe typed transport errors: `api_client_test.dart`.
- MomentLoop author mutation and partner read-only behavior remain scoped: controller and existing integration tests.
- Local browser to operational backend works over `127.0.0.1` with local `SOCKET_URL`: Playwright and startup checks.

## File Map

Create: `e2e/package.json`, `e2e/playwright.config.js`, `e2e/tests/core-path.spec.js`, Flutter `core/http/*`, `features/home/*`, `features/moment_loop/*`, and tests for each controller; backend `src/app/*`, `src/shared/access-context.js`, `src/shared/feature-registry.js`, and `test/app-factory.test.js`.

Modify: `home_screen.dart`, `home_shell.dart`, `moment_loop_screen.dart`, `auth_service.dart`, `today_api.dart`, `server_config.dart`, backend `index.js`, `backend-access.js`, `routes.js`, `socket.js` only where registration/boundaries require it, and `api-test-server.js`.

## Implementation Tasks

### Task 1: Baseline, DB safety, and Playwright harness

**Files:** Create `e2e/package.json`, `e2e/playwright.config.js`, `e2e/tests/core-path.spec.js`; modify ignore rules only for E2E artifacts.

**Interfaces:** `npm test --prefix e2e`; runtime-only `E2E_EMAIL` and `E2E_PASSWORD`; local Flutter `127.0.0.1:7357`; local backend `127.0.0.1:4100`.

- [ ] Run `node scripts/migrate.js status --json` from `services/realtime-server`; confirm read-only and inspect `.env` variable names/hostnames without printing secrets.
- [ ] Run the existing Flutter and backend loops; record pre-existing failures.
- [ ] Add Playwright Test with `test`, `test:headed`, and browser-install scripts. Keep test credentials out of source and artifacts.
- [ ] Configure/reuse Flutter web with `--dart-define=SOCKET_URL=http://127.0.0.1:4100` and backend with existing operational DB/Redis plus CORS for `http://127.0.0.1:7357`.
- [ ] Test `test@test.com`/`test` login, authenticated shell or pairing state, paired Home → MomentLoop → feed/empty state → refresh. Never create, edit, delete, pair, or upload.
- [ ] Run `E2E_EMAIL='test@test.com' E2E_PASSWORD='test' npm test --prefix e2e`; account-state failures must be explicit, never skipped.
- [ ] Commit `test: add local Playwright core path`.

### Task 2: Shared Flutter transport seam

**Files:** Create `lib/core/http/api_client.dart`, `lib/core/http/api_exception.dart`, `test/api_client_test.dart`; modify `auth_service.dart`, `today_api.dart`.

**Interfaces:** `ApiClient({required String baseUrl, required String? Function() tokenProvider, http.Client? client})`; `getJson`, `postJson`, `sendMultipart`; `ApiException(statusCode, code, message)`.

- [ ] Write failing tests for 2xx JSON, 401/403, non-JSON 5xx, network failure, bearer header, and URI joining.
- [ ] Run `flutter test test/api_client_test.dart` and verify failure.
- [ ] Implement token injection, JSON/error decoding, client ownership, and safe logging without changing login/logout behavior.
- [ ] Run `flutter test test/api_client_test.dart test/today_api_test.dart test/auth_screen_test.dart`.
- [ ] Commit `refactor: add authenticated Flutter transport boundary`.

### Task 3: Home controller/repository migration

**Files:** Create `features/home/domain/home_overview.dart`, `data/home_overview_repository.dart`, `application/home_controller.dart`, `test/home_controller_test.dart`; modify `home_screen.dart`, `home_shell.dart`, `home_screen_test.dart`.

**Interfaces:** `HomeOverviewRepository.fetch() -> Future<HomeOverview>`; `HomeController(repository)` with `state`, `load()`, `refresh()`; `HomeScreen(onNavigate, {HomeController? controller, ...})`.

- [ ] Test successful load, empty memory card, Today partial failure, all failure, retry, and stale refresh protection with a fake repository.
- [ ] Implement typed `HomeOverview`, `HomeState`, and `HomeStatus` while preserving current endpoint contracts: Couple info, memory card, assessment catalog, Today state.
- [ ] Move HTTP/JSON orchestration into the repository and load/refresh state into the controller.
- [ ] Make Home render controller state and preserve labels, navigation, existing test hooks, and tab behavior.
- [ ] Run `flutter test test/home_controller_test.dart test/home_screen_test.dart test/home_shell_navigation_test.dart` and `flutter analyze`.
- [ ] Commit `refactor: move Home orchestration behind controller`.

### Task 4: MomentLoop feature boundary

**Files:** Create `features/moment_loop/domain/moment.dart`, `data/moment_loop_repository.dart`, `data/media_upload_service.dart`, `application/moment_loop_controller.dart`, `presentation/moment_loop_state_view.dart`, `test/moment_loop_controller_test.dart`; modify `moment_loop_screen.dart` and its tests.

**Interfaces:** `MomentLoopRepository.fetchFeed(DateTime)`, `create(MomentDraft)`, `updateCaption(int, String)`, `delete(int)`, reaction methods; `MomentLoopController.loadWeek`, `createMoment`, `updateCaption`, `deleteMoment`, `designateToday`, `removeTodayDesignation`.

- [ ] Test feed success/empty/error/retry, author edit/delete, partner read-only rejection, Today lock, and upload failure preserving draft.
- [ ] Keep `/api/setlog`, reaction, map, media, and Today endpoint contracts; parse JSON only in data adapters and preserve multipart field names/limits.
- [ ] Move mutation orchestration and privacy decisions into the controller/domain layer.
- [ ] Keep `MomentLoopScreen` as composition shell; extract feed, viewer, detail, editor, and map picker presentation without changing behavior.
- [ ] Adapt current `client`, `baseUrl`, and test hooks into dependency injection; no operational credentials in widget tests.
- [ ] Run focused tests, `flutter test`, and `flutter analyze`.
- [ ] Commit `refactor: isolate MomentLoop data and state`.

### Task 5: Backend composition and access boundaries

**Files:** Create `src/app/create-app.js`, `src/app/create-realtime-server.js`, `src/shared/access-context.js`, `src/shared/feature-registry.js`, `test/app-factory.test.js`; modify `index.js`, `backend-access.js`, `api-test-server.js`.

**Interfaces:** `createApp(options) -> express.Application`; `createRealtimeServer(options) -> { app, httpServer, io }`; `getAuthenticatedActor(req)`; `resolveActiveCouple(userId)`; registry `isRestEnabled`/`isGameEnabled`.

- [ ] Test health, JSON/static middleware, route registration, Socket construction, and shutdown with stubs.
- [ ] Move composition from `index.js` without changing routes, CORS, Socket transports, or `/health` response.
- [ ] Wrap JWT identity and active-Couple resolution; retain `req.auth` compatibility and reject client scope overrides.
- [ ] Centralize server-authoritative REST/socket/game feature policy based on `MVP_DEFINITION.md`; test disabled prefixes and unknown games. Do not enable legacy games accidentally.
- [ ] Switch production entry and isolated test server to factories; do not split game handlers.
- [ ] Run `npm test` and `npm run check`; commit `refactor: add backend composition and access boundaries`.

### Task 6: Extract the MomentLoop backend vertical slice

**Files:** Create `services/realtime-server/src/modules/moment-loop/http-router.js`, `application.js`, `repository.js`, `domain.js`, and focused tests; modify `routes.js` only to remove the moved handlers and register the module router.

**Interfaces:** `createMomentLoopRouter({ service, uploadStore })`; `MomentLoopService({ repository, policy, media })`; repository methods matching the Flutter `MomentLoopRepository`; `resolveMomentScope(actor, couple)`.

- [ ] Inventory the current MomentLoop endpoints, upload path, author checks, partner read behavior, reactions, map links, and Today Moment interactions before moving code.
- [ ] Write service/domain tests for author-only mutation, active-Couple read scope, clip limits, delete behavior, and error mapping.
- [ ] Move SQL/query code into the repository and policy decisions into the service/domain layer; route handlers only validate input, pass access context, and serialize responses.
- [ ] Register the new router through `createApp` and remove duplicate legacy route registration without changing endpoint paths or response shapes.
- [ ] Run the existing MomentLoop, map, Today Moment, account-scope, full backend, and check suites; confirm no game tests or handlers changed.
- [ ] Commit `refactor: isolate MomentLoop backend module`.

### Task 7: Runtime schema mutation audit/removal

**Files:** Modify `routes.js` and startup module only after audit; create a numbered migration only if a read-only audit proves a committed schema gap; use existing migration safety tests.

**Interface:** Optional `assertSchemaReady({ requiredMigrations, database }) -> Promise<void>` that fails clearly but never mutates schema.

- [ ] Run migration status only and inspect required tables/columns through `INFORMATION_SCHEMA`; do not run `up`.
- [ ] Compare `ensure*` requirements with applied migrations and production schema; do not expose row data.
- [ ] If schema is ready, remove request-time DDL and use startup assertion or migration-state validation. If not ready, document the exact SQL and stop before production apply.
- [ ] Run migration tests, full backend tests, and `npm run check`; commit `refactor: stop mutating schema during requests`.

### Task 8: Local run and completion gate

**Files:** Modify only E2E/local diagnostics if necessary; do not deploy production.

- [ ] Start backend locally with operational DB/Redis env; verify `/health` and local CORS without migrations.
- [ ] Start Flutter web with local `SOCKET_URL`; verify requests and Socket.IO stay local.
- [ ] Run `flutter test && flutter analyze`, `npm test && npm run check`, and `npm test --prefix e2e`.
- [ ] Run headed Playwright with `E2E_EMAIL='test@test.com' E2E_PASSWORD='test' npm run test:headed --prefix e2e`; inspect login, Home, MomentLoop, refresh, and Socket state.
- [ ] On failure, inspect trace/logs with secrets and personal payloads removed, fix the smallest failing test, then rerun the full gate.
- [ ] Run `git diff --check` and `git status --short --branch`; verify no secrets/E2E artifacts are tracked and no deployment occurred.
- [ ] Commit `refactor: stabilize SecretBase core feature boundaries` only after every checklist item is green or an explicitly documented external blocker remains.
