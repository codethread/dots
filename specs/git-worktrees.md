# Git Worktree Automation Specification

**Status:** Implemented
**Last Updated:** 2026-04-21

## 1. Overview

### Purpose

This system wraps `git worktree` with repo-local Nushell helpers and kitty-session automation so worktrees can be created, removed, listed, and post-processed consistently. The boundary exists to make sibling worktrees predictable: stable paths, automatic session switching, optional per-repo bootstrap hooks, and cleanup that keeps shell and kitty state aligned.

### Goals

- Provide a single `wk add` entry point for creating sibling worktrees
- Derive a stable sibling path from the canonical/root worktree
- Open new worktrees in kitty sessions when available, otherwise fall back to the current shell
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
  - **Rationale:** This avoids ad hoc path selection and keeps worktrees predictably colocated with the main clone, which matters for kitty session naming and cleanup.

- **Decision:** Post-create behavior is configured in TOML under `config/ct-worktrees/trees.toml`.
  - **Rationale:** A repo-local declarative config is easy to edit, easy to version, and keeps per-project bootstrap rules out of shell functions.

- **Decision:** Hook matching keys off the canonical/root worktree path.
  - **Rationale:** The root path is stable and unambiguous for a given repo; branch names alone are not enough because the same automation can apply to different clones.

- **Decision:** Hook context is passed via `WK_ROOT` and `WK_CREATED` environment variables.
  - **Rationale:** Env vars work for both Bash and Nushell hooks and avoid encoding a Nushell closure boundary into TOML.

- **Decision:** When kitty is available, the hook is run in the newly opened kitty session/window for the worktree.
  - **Rationale:** This keeps the post-create workflow attached to the terminal context the user will actually use for the tree, rather than executing in the parent shell and then switching away.

- **Decision:** When kitty is not available, the hook runs in the current shell after `cd` into the new worktree.
  - **Rationale:** The same configuration remains useful from non-kitty shells and headless automation.

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
   - writes a kitty session file and launches a new kitty window/session runner, or
   - `cd`s into the new tree and runs the hook directly.
5. Hook commands receive `WK_ROOT` and `WK_CREATED`.
6. `wk remove` resolves the target tree, optionally moves the shell away from the soon-to-be-deleted directory, removes the worktree, and deletes the branch.

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

### Kitty integration

When running inside kitty, `wk-open-dir` creates a session file in `~/.config/kitty/sessions/` and uses `kitten @ action goto_session` to switch to the new session. The generated kitty session launches a shell command that runs the post-create runner and keeps the window open with `--hold`.

## 6. Testing

Automated checks currently cover:

- Nushell module importability for `helpers.nu`, `kitty.nu`, and `mod.nu`
- A smoke test that exercises post-create hook execution outside kitty using a temporary `XDG_CONFIG_HOME`
- Manual verification of kitty-mode session generation via generated session files and runner scripts

Manual checks are still useful for:

- confirming the new kitty session opens with the expected title and cwd
- confirming hook output appears in the new kitty window
- confirming `wk remove` cleans up both worktree path and branch as expected

## 7. Code Locations

| File | Description |
| --- | --- |
| `config/nushell/scripts/ct/git/worktree/helpers.nu` | Root detection, path derivation, and hook config loading/filtering |
| `config/nushell/scripts/ct/git/worktree/kitty.nu` | Kitty session launch and hook runner generation/execution |
| `config/nushell/scripts/ct/git/worktree/mod.nu` | Public `wk` command surface for add/remove/list/path/root |
| `config/ct-worktrees/trees.toml` | Repo-local post-create hook configuration |

## 8. Open Questions

- Should root matching support globs or prefixes instead of exact path equality?
- Should hook execution report failures back to the original `wk add` call even when the hook runs inside kitty?
- Should more hook phases be added later, such as pre-create or post-remove?
- Should generated kitty session runner files be cleaned up automatically after use?
