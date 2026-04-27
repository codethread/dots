---
name: build
description: |
  Implement the next pending task from a feature plan.
  One task per invocation — the user loops externally.
  Triggers on: "dev/build", "build next task", "implement next"
argument-hint: [feature-name-or-path]
---

# Build

Implement exactly one task per invocation. Each call gets a fresh context window.

## Variables

- `FEATURE`: `$ARGUMENTS` — optional feature name or path
- `WORKTREE_MANAGER_AGENT`: `worktree-manager`
- `PLANNING_SKILL`: `dev/what`
- `DECOMPOSE_SKILL`: `dev/how`

## Prerequisites

- `.dev/<feature>/tasks.yml` exists
- `$WORKTREE_MANAGER_AGENT` has judged the checkout safe for build

## Knowledge

### Feature Resolution

Resolve the target feature under `.dev/`:

- normalize an explicit name/path by stripping an optional `.dev/` prefix and trailing slash
- if no feature is supplied and exactly one `.dev/*/tasks.yml` exists, use it
- if no feature is supplied and multiple candidates exist, stop and require explicit selection

### Retry Limits

- Typecheck, lint, and tests each get at most 3 fix attempts
- Code review gets at most 3 cycles

### Code Review

See `references/build-protocol.md` for the review prompt, feedback classification, blocked vs fatal guidance, and `progress.md` format.

## Workflow

1. Read nearby code first and follow existing conventions.
2. Read `.dev/<feature>/tasks.yml` and, if it exists, the `Codebase Patterns` section of `.dev/<feature>/progress.md`.
3. Run each requirement check from `tasks.yml` before picking a task.
4. Stop if any task is `blocked` or `fatal`; otherwise pick the first `pending` task and mark it `in_progress`.
5. Implement only files listed in the task's `files` section.
6. If the task is impossible or the plan is wrong, mark it `fatal` and explain why.
7. Run typecheck, lint, tests, then code review, following `references/build-protocol.md` for review handling and failure classification.
8. Mark the task `done`, populate `notes`, append to `progress.md`, and commit all changes together.

## Constraints

- Never implement more than one task per invocation.
- Never modify files outside the task's `files` list without updating `tasks.yml` first.
- Never skip quality checks or code review.
- If a task's acceptance criteria conflict with reality, mark it `fatal`.
- Always append learnings after completing a task.
- Do not build in a checkout judged unsafe.
- Leave the git tree clean after the commit.

## Validation

- Exactly one task was implemented
- All acceptance criteria are met
- Typecheck, lint, and tests all pass
- Code review completed or the retry limit was documented
- Task status is `done` with notes populated
- `.dev/<feature>/progress.md` has an entry for the task
- `git status --porcelain` is clean
