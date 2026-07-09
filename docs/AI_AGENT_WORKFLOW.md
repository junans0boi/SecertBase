# AI Agent Workflow For Secret Base

Last updated: 2026-07-08

This guide adapts the skills workflow you researched to this repository.
Use it with Claude Code, Codex, or any coding agent.

## 0. First Principle

Do not start by asking the agent to "look at everything".

Start each session with a narrow goal and the smallest context pack:

```text
Read CONTEXT.md, docs/PROJECT_OVERVIEW.md, and the files directly relevant to this task.
Then follow the workflow below.
```

For this repo, the three work areas are:

- Server: `services/realtime-server`
- Frontend: `apps/secret_base_app`
- Database: `services/realtime-server/schema.sql` and MariaDB migrations/ensure-table logic in `routes.js`

## 1. Recommended Skill Flow

Use this default path for new features:

```text
align -> PRD -> vertical issues -> TDD implementation -> review -> handoff
```

In Matt Pocock skill terms:

```text
/grill-with-docs
/to-prd
/to-issues
/tdd
/code-review
/handoff
```

In plain Codex/Claude prompts:

```text
Read CONTEXT.md and docs/PROJECT_OVERVIEW.md.
Interview me one question at a time until this feature is clear.
Use current code to answer questions when possible.
When aligned, produce a PRD and split it into vertical slices.
```

## 2. When To Use Each Workflow

### New Feature

Use for things like a new archive screen, new game mode, notification flow, or Android release flow.

Prompt:

```text
Read CONTEXT.md.
Use a grill-with-docs style interview for this feature: <feature>.
Ask one question at a time, recommend an answer, and inspect code before asking if code can answer it.
```

Output should be:

- domain terms to add to `CONTEXT.md`
- PRD with Problem, Solution, User Stories, Implementation Decisions
- vertical-slice issues

### Bug

Use for Google login failures, socket restore bugs, game rule bugs, upload bugs, or deployment failures.

Prompt:

```text
Read CONTEXT.md and HANDOFF.md.
Use a diagnosing-bugs workflow.
First create or identify a tight pass/fail loop. Do not edit code until the loop exists.
Bug: <bug description>
```

Expected loop examples:

- Google login API: repeatable HTTP request or targeted backend test around `/api/auth/google`
- game engine bug: `node --test` test in `services/realtime-server/test`
- Flutter UI bug: `flutter test` or exact browser reproduction
- deployment bug: server command transcript plus local deploy script check

### One Issue Implementation

Use this in a fresh session per issue.

Prompt:

```text
Read CONTEXT.md and the issue text below.
Use TDD. Work one vertical slice only.
Start with the smallest failing test/check, make it pass, then refactor.
Issue: <issue>
```

### Architecture Improvement

Use when the agent keeps touching too many files, testing is hard, or the same concepts are duplicated.

Prompt:

```text
Read CONTEXT.md.
Find codebase-design/deep-module opportunities in server, frontend, and database.
Return a numbered list of improvements, but do not edit code yet.
For each item, explain current complexity, proposed interface, and expected test boundary.
```

## 3. Secret Base Vertical Slice Examples

Good vertical slice:

```text
Daily Q&A answer visibility
  -> DB row/state rule
  -> REST endpoint behavior
  -> Flutter screen state
  -> test/check proving both users' answers reveal correctly
```

Good vertical slice:

```text
UNO discard_all rule fix
  -> engine test
  -> server event behavior if needed
  -> Flutter rendering only if state shape changes
```

Bad horizontal split:

```text
Build all archive DB tables
Build all archive APIs
Build all archive screens
```

That creates a long period where nothing is end-to-end verifiable.

## 4. Context Budget Rules

Use the smallest useful context set:

- Always: `CONTEXT.md`
- Product/architecture: `docs/PROJECT_OVERVIEW.md`
- REST work: `docs/REST_API.md`, `services/realtime-server/src/routes.js`, `services/realtime-server/src/db.js`
- Socket work: `docs/SOCKET_EVENTS.md`, `services/realtime-server/src/socket.js`, relevant engine file
- Flutter auth/app flow: `auth_service.dart`, `socket_service.dart`, `server_config.dart`, target screen
- Deployment: `HANDOFF.md`, `scripts/deploy_server.sh`, `docs/deployment/*`
- Database: `schema.sql`, `routes.js` table creation helpers, `db.js`

Avoid loading old broad logs unless needed:

- `PROGRESS_SUMMARY.md`
- `DEVELOPMENT_LOG.md`
- `docs/WORKLOG.md`

Those are useful history, but some DB details are stale.

## 5. Claude And Codex Usage

### Claude

Best for:

- long design interviews
- product/UX clarification
- turning discussion into PRD/issues
- broad architecture exploration

Suggested style:

```text
/grill-with-docs
Feature: <one feature only>
Read CONTEXT.md first. Keep questions one at a time.
```

### Codex

Best for:

- local code reading and edits
- tests/checks
- bug diagnosis with command feedback
- repo-specific refactors

Suggested style:

```text
Read CONTEXT.md.
Implement issue <id/text> using TDD.
Run the relevant checks and summarize changed files.
```

## 6. First Practice Session For This Repo

Start with the current real risk instead of a new feature:

```text
Read CONTEXT.md and HANDOFF.md.
Use diagnosing-bugs.
Goal: resolve production deployment divergence and Google login deployment state.
First, list the exact pass/fail checks needed before editing.
```

Why this is the right first exercise:

- it touches server, deployment, and database auth behavior
- it has a clear pass/fail signal
- it prevents future AI sessions from building on a broken deployment state

## 7. Handoff Template

Use this when a session gets long:

```markdown
## Goal

## Current State

## Decisions Made

## Files Changed

## Tests/Checks Run

## Known Risks

## Next Action
```
