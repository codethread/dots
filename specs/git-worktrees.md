# Git Worktree Automation Specification

**Status:** Implemented
**Last Updated:** 2026-04-27

## 1. Overview

### Purpose

This system wraps `git worktree` with repo-local Nushell helpers so worktrees can be created, removed, listed, opened in tmux, and post-processed consistently. The boundary exists to make sibling worktrees predictable: stable paths, automatic tmux session switching, optional per-repo bootstrap hooks, and cleanup that keeps shell and tmux state aligned.

### Goals

- Provide a single `wk add` entry point for creating sibling worktrees
- Derive a stable sibling path from the canonical/root worktree
- Open new worktrees in tmux sessions when available, otherwise fall back to the current shell
- Support repo-local post-create hooks keyed by canonical/root worktree path
- Pass hook context as environment variables rather than requiring shell-specific closure serialization
- Remove worktrees and their branches with matching cleanup helpers
- Preserve compatibility with the repo’s Nushell-centric workflow

### Non-Goals

- General-purpose worktree UI or TUI management
- Watching for filesystem changes after a worktree is created
- Cross-repo orchestration or remote worktree distribution
- Git hook injection into `.git/hooks/`
- Replacing `git worktree` semantics with a custom storage model
- Building a full task runner; hook execution stays intentionally lightweight

## 2. Design Decisions

- **Decision:** Worktree helpers live in Nushell modules under `config/nushell/scripts/ct/git/worktree/`.
  - **Rationale:** The repo already treats Nushell as the interactive automation layer, so keeping worktree commands there makes the feature discoverable and composable with existing shell helpers.

- **Decision:** Stable sibling paths are derived from the canonical/root worktree plus an encoded branch name.
  - **Rationale:** This avoids ad hoc path selection and keeps worktrees predictably colocated with the main clone.

- **Decision:** Post-create behavior is configured in TOML under `config/ct-worktrees/trees.toml`.
  - **Rationale:** A repo-local declarative config is easy to edit, easy to version, and keeps per-project bootstrap rules out of shell functions.

- **Decision:** Hook matching keys off the canonical/root worktree path.
  - **Rationale:** The root path is stable and unambiguous for a given repo; branch names alone are not enough because the same automation can apply to different clones.

- **Decision:** Hook context is passed via `WK_ROOT` and `WK_CREATED` environment variables.
  - **Rationale:** Env vars work for both Bash and Nushell hooks and avoid encoding a Nushell closure boundary into TOML.

- **Decision:** When tmux is available, the worktree opens in a tmux session and post-create hooks run in a `post-create` window.
  - **Rationale:** This keeps the post-create workflow attached to the terminal context the user will actually use for the tree, rather than executing in the parent shell and then switching away.

- **Decision:** When tmux is not available, hooks run in the current shell after `cd` into the new worktree.
  - **Rationale:** The same configuration remains useful from plain shells and headless automation.

- **Decision:** Hook execution supports both `bash` and `nu`.
  - **Rationale:** Bash is the simplest portable default, while Nu keeps repo-local shell logic available when the command needs Nu semantics.

- **Decision:** Worktree removal also deletes the associated branch.
  - **Rationale:** The helper is intended to manage the full worktree lifecycle, not only detach the filesystem entry. The branch deletion makes cleanup symmetric with creation.

## 3. Architecture

### Component structure

Implemented in `config/nushell/scripts/ct/git/worktree/` and the repo-local TOML config at `config/ct-worktrees/trees.toml`.

### Data flow

1. `wk add` resolves the canonical/root worktree and sibling path.
2. `git worktree add` creates or checks out the branch.
3. Matching post-create hooks are loaded from TOML.
4. `wk-open-dir` either:
   - creates/switches to a tmux session for the worktree and starts a `post-create` window when hooks exist, or
   - `cd`s into the new tree and runs hooks directly outside tmux.
5. Hook commands receive `WK_ROOT` and `WK_CREATED`.
6. `wk remove` resolves the target tree, optionally moves the shell away from the soon-to-be-deleted directory, removes the worktree, deletes the branch, and closes matching tmux sessions.

## 4. Data Model

### Core config shape

See `config/ct-worktrees/trees.toml` for the live config schema.

Current hook entries are objects with these fields:

- `root`: canonical/root worktree path to match
- `command`: Bash or Nushell command body to run
- `shell`: optional executor selector, `bash` or `nu`
- `name`: optional human-friendly label used in runner output and filenames

### Core shell values

The runtime contract is env-based:

- `WK_ROOT` — canonical/root worktree path
- `WK_CREATED` — created worktree path

## 5. Interfaces

### Nushell commands

| Command | Description |
| --- | --- |
| `wk root` | Print canonical/root worktree path |
| `wk path <branch>` | Print stable sibling path for a branch |
| `wk add <branch> [base]` | Create/check out a sibling worktree, then open it and run any matching post-create hooks |
| `wk remove [branch] --self --force` | Remove a worktree and delete its branch |
| `wk list [--json]` | List worktrees, optionally as structured JSON |

### Tmux integration

When running inside tmux, `wk-open-dir` creates or switches to a tmux session rooted at the new worktree. If post-create hooks exist, it opens a detached `post-create` window in that session to run them. Outside tmux, it falls back to `cd` and runs hooks inline.

## 6. Testing

Automated checks currently cover:

- Nushell module importability for `helpers.nu`, `tmux.nu`, and `mod.nu`
- A smoke test that exercises post-create hook execution outside tmux using a temporary state directory
- Manual verification of tmux session creation and post-create hook windows

Manual checks are still useful for:

- confirming the new tmux session opens with the expected title and cwd
- confirming hook output appears in the `post-create` window
- confirming `wk remove` cleans up both worktree path and branch as expected

## 7. Code Locations

| File | Description |
| --- | --- |
| `config/nushell/scripts/ct/git/worktree/helpers.nu` | Root detection, path derivation, and hook config loading/filtering |
| `config/nushell/scripts/ct/git/worktree/tmux.nu` | Tmux session launch and hook runner generation/execution |
| `config/nushell/scripts/ct/git/worktree/mod.nu` | Public `wk` command surface for add/remove/list/path/root |
| `config/ct-worktrees/trees.toml` | Repo-local post-create hook configuration |

## 8. Open Questions

- Should root matching support globs or prefixes instead of exact path equality?
- Should hook execution report failures back to the original `wk add` call even when the hook runs inside tmux?
- Should more hook phases be added later, such as pre-create or post-remove?
