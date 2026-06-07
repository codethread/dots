---
name: toil-worktrees
description: >
  Toil git-flow and worktree usage guide. Use when Toil needs to plan or route
  project work through git worktrees, choose repo/worktree scopes, or explain
  how to use the local wktree workflow.
---

# toil-worktrees

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| SPEC | /Users/ct/dev/dots/specs/git-worktrees.md | Detailed local worktree contract |
| ENGINE | wktree | Source of truth for worktree lifecycle |
| CONFIG | config/ct-worktrees/trees.toml | Project bootstrap/pool config |

## Prerequisites

- Read SPEC before giving detailed CLI guidance.
- Work is tied to a git repository or planned worktree scope.

## Knowledge

`wktree` owns git/worktree lifecycle transitions. Tmux is a navigation/runtime surface, not durable truth.

Important conventions from SPEC:

- Non-pooled path: `<canonicalRoot>__<branch encoded with / as -->`.
- Pooled slot path: `<canonicalRoot>__featN`.
- Tmux session name: `basename(worktree_path).replaceAll(".", "_")`.
- New branches default to origin's default branch/trunk unless an explicit base is chosen.
- Machine consumers should prefer `--json` and branch on outcome `kind`.

Core commands:

- `wktree root --cwd <path>`
- `wktree list --cwd <path> --json`
- `wktree path --cwd <path> --branch <branch>`
- `wktree add --cwd <path> --branch <branch> --json [--base <branch>] [--slot <path>]`
- `wktree remove --cwd <path> (--branch <branch> | --self <path>) --json`
- `wktree status --cwd <path>`
- `wktree recycle --cwd <path> --slot <path> [--force]`

## Procedures

1. Read SPEC for exact command semantics and edge cases.
2. Decide whether the task should run in the current repo scope or a new/existing worktree scope.
3. Use `wktree` to create, list, or locate the target worktree.
4. Upsert the Pithos repo/worktree scope for the selected path before enqueueing execution.
5. Put branch, worktree path, and upstream task ids in downstream task bodies.

## Constraints

- Do not invent tmux session names; derive them from worktree path.
- Do not treat tmux state as proof of worktree existence or cleanliness.
- Do not recycle pooled slots without explicit safe evidence or user intent.
- Do not silently stack branches; choose base explicitly when stacking is intended.

## Validation

- [ ] Downstream work names the repo/worktree path.
- [ ] Worktree lifecycle decisions use `wktree`, not ad hoc git commands.
- [ ] Unsafe pool/recycle states are escalated or blocked.
