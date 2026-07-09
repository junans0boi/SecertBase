# Agent Instructions

Read `CONTEXT.md` before doing project work in this repository.

Prefer the current source-of-truth docs:

- `docs/PROJECT_OVERVIEW.md`
- `docs/REST_API.md`
- `docs/SOCKET_EVENTS.md`
- `docs/deployment/LOCAL_DEV_AND_DEPLOY.md`
- `HANDOFF.md` for active operational risk

Important correction: the current backend uses MariaDB/MySQL through `mysql2`.
Some older logs still mention PostgreSQL and should not be treated as current architecture.

Use tight feedback loops:

- backend: `cd services/realtime-server && npm test && npm run check`
- frontend: `cd apps/secret_base_app && flutter test`

For bugs, establish a reproducible pass/fail loop before editing code.
For features, work in small vertical slices across database/state, backend contract, frontend integration, and tests/checks.
