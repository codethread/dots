---
name: pandora-shutdown
description: >
  End-of-day Pandora tidy-up. Use when the user asks to shutdown, wrap up,
  tidy finished work, clean old worktrees/scopes, or ensure repos touched today
  are pull/push updated.
---

# pandora-shutdown

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| AGENT | Pandora | HITL coordinator |
| WINDOW | today | Repos/scopes updated during today's work |

## Knowledge

Shutdown is a tidy pass. It must not interrupt ongoing work.

Targets:

- Finished task chains that need final summaries or obvious cleanup.
- Old disposable worktrees and inactive scopes.
- Repositories updated today that need push/pull hygiene.

## Decisions

Entry state: SURVEY

### SURVEY

- guard: ongoing live work exists → TIDY_FINISHED_ONLY
- guard: no ongoing live work exists → TIDY_ALL_SAFE

### TIDY_FINISHED_ONLY

- action: clean only completed/inactive work that cannot affect live runs.
- always → REPO_HYGIENE

### TIDY_ALL_SAFE

- action: clean completed work, stale worktrees, and inactive scopes when safe.
- always → REPO_HYGIENE

### REPO_HYGIENE

- action: inspect repos updated today for clean status and push/pull state.
- guard: all safe → DONE
- guard: conflicts, dirty work, or ambiguous branch state → REPORT_BLOCKED

### REPORT_BLOCKED

- terminal state; report what needs user action.

### DONE

- terminal state.

## Procedures

1. Check Pithos/pdx state for live runs and held tasks.
2. Identify completed work from today and any associated repo/worktree scopes.
3. Tidy completed-only artifacts/worktrees/scopes that are clearly inactive.
4. For repos updated today, inspect git status and remote sync state.
5. Pull/push only when the repo is clean enough and the direction is unambiguous.
6. Report what was tidied, what was synced, and what remains blocked.

## Constraints

- Never stop, kill, cancel, or interrupt ongoing work.
- Never delete dirty worktrees or scopes with unclear ownership.
- Never force-push.
- Ask or report blocked when branch sync direction is ambiguous.

## Validation

- [ ] Ongoing work was left running.
- [ ] Finished work cleanup is summarized.
- [ ] Repos updated today are either synced or listed with a blocker.
