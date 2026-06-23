# Git Worktrees Workflow

**Status:** Implemented  
**Last Updated:** 2026-06-16

## 1. Overview

This dotfiles workflow uses the external `wktree` project to make git worktree creation, reuse, switching, and removal fast and predictable across personal shell, tmux, and agent workflows.

The implementation contract lives in `~/dev/projects/wktree/specs/git-worktrees.md`. This spec owns only the local workflow: how dotfiles wire `wktree` into Nushell, PATH, project bootstrap config, and tmux navigation.

## 2. Goals

- Use `wktree` as the single engine for git/worktree lifecycle operations.
- Keep local project bootstrap policy in dotfiles config, not in the engine repo.
- Import the `wk` human wrapper from the external repo into the normal Nushell config.
- Keep tmux session names aligned with worktree paths so sessions are easy to inspect and reconstruct.
- Make `wk add` mean "create/allocate, run bootstrap, then navigate" for human workflows.

## 3. Non-goals

- Dotfiles do not implement worktree lifecycle logic.
- Dotfiles do not own `wktree` tests or edge-case behavior.
- Dotfiles do not maintain a worktree database or tmux session registry.
- Dotfiles do not define a generalized bootstrap language beyond the local `trees.toml` commands consumed by `wktree`.

## 4. Local integration points

### PATH

`config/nushell/env.nu` adds `~/.local/bin` to PATH. The external `wktree` repo build writes `~/.local/bin/wktree`, so no dotfiles-specific binary wrapper is needed.

### Nushell wrapper import

`config/nushell/config.nu` imports the human-facing `wk` wrapper directly from the external repo:

```nu
use ~/dev/projects/wktree/nu/wktree *
```

`wk` is for interactive shell/tmux workflows. Agents and scripts should use the core `wktree` CLI, preferably with `--json` where available.

### Project config

`config/ct-worktrees/trees.toml` is local machine/user configuration read by `wktree` from `$XDG_CONFIG_HOME/ct-worktrees/trees.toml`.

Each project entry may define:

- `name`
- `root`
- `command`
- optional `pool_size`

The command runs under bash with:

- `WK_ROOT` — canonical/root worktree path
- `WK_CREATED` — created worktree or allocated pool slot path

This dotfiles repo currently uses that file for local bootstrap policy such as expensive app setup commands and notifications.

### Observable worktree identity

The canonical root is Git-derived. Use `wktree root --cwd <path>` or `wktree list --json` (`canonical: true`) to identify it; do not infer root identity from path names.

Observable path conventions introduced by this workflow:

- Non-pooled worktrees: `<canonicalRoot>__<branch with / encoded as -->`
- Pooled worktrees: fixed slots `<canonicalRoot>__featN`
- Pooled placeholder branches: `wk-pool/featN`

In pooled projects, branch names do not determine paths. Use `wktree add`, `wktree list --json`, or `wktree status` to discover the allocated slot.

### Tmux navigation

The imported `wk` wrapper opens or switches tmux sessions after post-create work succeeds. Tmux is a navigation/runtime surface only; missing sessions are normal and can be recreated from git worktree state.

## 5. Human workflow contract

### Add/switch

For humans, `wk add <branch>` should:

1. Ask `wktree` to create or allocate the worktree.
2. Receive a structured `ready`, `pool_full`, or `blocked` outcome.
3. If ready, run the returned post-create script synchronously in the current Nushell flow.
4. Only after bootstrap succeeds, create/switch to the tmux session or `cd` to the worktree outside tmux.

This avoids hidden background bootstrap work: if the command returns and navigation happens, the worktree is genuinely ready for use.

### Pool-full handling

When a configured pool is full, the human wrapper may present candidates and ask which slot to recycle. The destructive choice remains explicit. Machine/agent behavior should use the structured `wktree add --json` outcome instead of scraping prompts.

### Remove/recycle

`wk remove` delegates safety checks to `wktree`. Non-pooled worktrees are removed. Pooled slots are recycled back to placeholder branches.

## 6. Boundaries with the external repo

Owned by `~/dev/projects/wktree`:

- CLI command behavior and JSON payload details
- path, branch, and pool semantics
- exit codes and blocked/unsafe outcome kinds
- post-create script generation
- Nushell wrapper implementation and tests

Owned by this dotfiles repo:

- importing the wrapper from Nushell config
- local `trees.toml` project entries
- PATH setup that makes `wktree` available
- tmux/keybinding integration around the workflow
- personal conventions for which repos use pools and what bootstrap commands run

## 7. Code locations

| Location                         | Purpose                                                     |
| -------------------------------- | ----------------------------------------------------------- |
| `~/dev/projects/wktree`          | External implementation, wrapper, and tests                 |
| `config/nushell/config.nu`       | Imports the external `wk` wrapper                           |
| `config/nushell/env.nu`          | Ensures `~/.local/bin` is on PATH                           |
| `config/ct-worktrees/trees.toml` | Local project bootstrap/pool config                         |
| `config/tmux/tmux.conf`          | Tmux keybindings that may expose worktree/session workflows |
| `home/.local/bin/tmux-session`   | General session switching and path-derived naming           |

## 8. Validation

For workflow changes in dotfiles:

```bash
nu --config config/nushell/config.nu --env-config config/nushell/env.nu -c 'print ok'
```

For engine/wrapper behavior, run validation in `~/dev/projects/wktree`:

```bash
bun test
bun run typecheck
bun run check
```
