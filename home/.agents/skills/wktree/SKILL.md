---
name: wktree
description: Use when creating, switching, listing, or removing git worktrees in this environment; agents should prefer wktree over raw git worktree commands.
---

# wktree

- Use `wktree` directly; prefer `--json` whenever available.
- Always pass `--cwd <path>` so the engine resolves the intended repository/worktree.
- Add/create: `wktree add --cwd <path> --branch <branch> --json`.
- If an add result includes `post_create_script_path`, run that script with `bash` before treating the worktree as ready.
- List: `wktree list --cwd <path> --json`.
- Path lookup: `wktree path --cwd <path> --branch <branch>`.
- Remove by branch: `wktree remove --cwd <path> --branch <branch> --json`.
- Remove current worktree: `wktree remove --cwd <path> --self <path> --json`.
- Use `--force` only when explicitly discarding local work is intended.
- Inspect pool status: `wktree status --cwd <path>`.
- Recycle a pool slot: `wktree recycle --cwd <path> --slot <path> [--force]`.

## Constraints

- Do not invent tmux session names; use the `session` fields emitted by `wktree` JSON.
- Do not bypass `wktree` for pooled repos unless explicitly repairing git state.
- Treat non-zero exits as meaningful: inspect JSON `kind` when present rather than parsing stderr.
