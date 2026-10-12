# Secret Map save audit repair

Date: 2026-10-12. Baseline: `bbb5b2f`.
Worktree: `.claude/worktrees/codex-map-20261012`.

Read `CONTEXT.md`, the shared checkout's `CLAUDE.md` (absent from this
worktree), `docs/AI_AGENT_WORKFLOW.md`, current project/API docs, and GitHub
issues [#138](https://github.com/junans0boi/SecertBase/issues/138),
[#144](https://github.com/junans0boi/SecertBase/issues/144),
[#157](https://github.com/junans0boi/SecertBase/issues/157), and
[#158](https://github.com/junans0boi/SecertBase/issues/158) before edits.

## Changes

- The baseline already uses `flutter_map ^8.2.2` for #157. No dependency edits.
- Add-pin submission checks the HTTP status before applying success effects.
  Non-2xx responses display the existing save error and retain the entered
  name, memo, status, category, half-height form, and current map filters.
- Successful save and pin reload finish before closing the form and snapping
  the sheet to 0.12. The form remains open while the save response is pending.
- Mounted checks protect save completion, pin reload, map movement, and the
  form callback when the screen or form has been removed during an await.
- Marker/detail half height (0.45), expanded list (0.92), drag and filter
  behavior remain covered by the existing widget tests. Edit/delete handlers
  were not changed.

## Verification

All commands ran in `apps/secret_base_app` unless noted.

- Baseline: `flutter test --no-pub --reporter expanded test/map_screen_test.dart`
  passed all 11 existing tests after local `flutter pub get --offline`.
- Red: the delayed-success test failed because the form closed before a save
  response; the completed-success test observed 0.45 instead of 0.12;
  HTTP 400 and 500 tests failed because the entered form disappeared.
- Green: the same map test command passed all 15 tests after the repair.
  Failure fixtures deliberately contain a success-shaped body to prove that
  HTTP failures cannot change the filters or count as successful saves.
- `flutter analyze --no-pub lib/screens/archive/map_screen.dart test/map_screen_test.dart`:
  no issues found.
- `flutter test --no-pub --reporter expanded`: all 210 tests passed.
- `git diff --check`: passed.

HTTP calls in the new UI regressions use `MockClient`; no live API or production
UI smoke was used. Live tile rendering and device CRUD smoke were not run.
The existing OpenStreetMap debug notice and a registration-test tap warning
appeared during verification; neither caused a test failure.

Only the map screen, map widget tests, and this map report are in the patch.
No push, deployment, database operation, or issue write was performed.
