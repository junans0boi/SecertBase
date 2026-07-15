# Domain Docs

Secret Base is a single-context repository.

## Before exploring

- Read the root `CONTEXT.md`.
- Read relevant ADRs under `docs/adr/` when that directory exists.
- Prefer the current source-of-truth documents named in `AGENTS.md`.

Proceed silently when an optional ADR directory or document does not exist.

## Vocabulary

Use terms exactly as defined in `CONTEXT.md` in issue titles, specifications, tests, and implementation notes. Do not replace domain terms with near-synonyms when a canonical term exists.

When a required concept is missing or conflicts with existing language, resolve it through `domain-modeling` before implementation.

## Decisions

Surface any conflict with an existing ADR instead of silently overriding it. System-wide ADRs belong under `docs/adr/`.
