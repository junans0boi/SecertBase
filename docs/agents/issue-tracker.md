# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`.
- **Read an issue**: `gh issue view <number> --comments` and include labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments` with appropriate filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`.
- **Apply or remove labels**: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- **Close an issue**: `gh issue close <number> --comment "..."`.

Infer the repository from `git remote -v`; `gh` resolves it automatically inside this clone.

## Pull requests as a triage surface

**PRs as a request surface: no.**

GitHub shares one number space across issues and PRs. Resolve an ambiguous number with `gh pr view <number>` and fall back to `gh issue view <number>`.

## Skill operations

- When a skill says to publish to the issue tracker, create a GitHub issue.
- When a skill says to fetch a ticket, run `gh issue view <number> --comments`.
- Use GitHub's native issue dependencies when available. Otherwise, put `Blocked by: #<number>` in the issue body.
- Apply `ready-for-agent` only to tickets whose descriptions and blocking edges are complete.
