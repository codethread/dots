# Git Worktree Automation Specification

**Status:** Implemented
**Last Updated:** 2026-04-28

## 1. Overview

The worktree workflow provides a `wk` command surface for creating, reusing, listing, opening, and removing sibling git worktrees. The implementation is split between:

- `wktree` TypeScript binary: owns git worktree logic, project config parsing, pooled slot allocation/recycling, hook runner generation, fzf picker integration, and JSON plans.
- Nushell wrappers in `config/nushell/scripts/ct/git/worktree/`: keep the interactive `wk` API, call `wktree`, and hand resulting plans to tmux/opening helpers.

The binary uses plain dependency-injected interfaces (`GitRunner`, `HookRunner`, `Picker`, `Progress`) with live implementations wired at startup and test stubs wired in ring-2 integration tests.

## 2. Goals

- Provide a single `wk add` entry point for worktree creation/allocation.
- Derive stable sibling paths for non-pooled worktrees from the canonical/root worktree and encoded branch name.
- Support reusable pooled worktree slots for expensive projects.
- Run per-project bootstrap hooks with consistent `WK_ROOT` / `WK_CREATED` environment.
- Open new or allocated worktrees in tmux sessions when available.
- Remove non-pooled worktrees and branches; recycle pooled slots instead of deleting their directories.
- Keep interactive picker/confirmation behavior available when a pool is full.

## 3. Architecture

### Binary / wrapper split

`wktree` is the engine. It reads `config/ct-worktrees/trees.toml`, invokes git, emits plan JSON, and fails with targeted messages for config/git/hook/picker errors.

The Nushell module exposes:

| Command | Backing behavior |
| --- | --- |
| `wk root` | `wktree root` |
| `wk path <branch>` | `wktree path` |
| `wk list [--json]` | `wktree list` |
| `wk add <branch> [base] [--self] [--force]` | `wktree add`, then tmux/open handoff from returned AddPlan. `--self` derives `--base` from the current worktree's branch. |
| `wk remove [branch] --self --force` | `wktree remove`, then local shell/tmux cleanup from returned RemovePlan |
| `wk switch` | fzf picker over all worktrees; switches tmux focus to selected worktree. Preview shows captured tmux pane output when a pane is open, otherwise recent git log. |

`wk add` and `wk remove` intentionally call `wktree` without piping through `complete` so stdout/stderr/stdin remain attached for hook progress, fzf, and confirmation prompts.

## 4. Configuration

Live config: `config/ct-worktrees/trees.toml`.

### Current shape

```toml
[[project]]
name = "deals ui bootstrap" # optional; defaults from basename(root)
root = "~/work/app/deals-light-ui"
pool_size = 5               # optional; omit for non-pooled projects
command = '''
yarn install
notif worktree wk "$WK_CREATED" ready
'''
```

Fields:

- `root` — required canonical/root worktree path. `~` is expanded and the value is resolved to an absolute path.
- `command` — required bash body run after a worktree is created or a pool slot is materialized/allocated.
- `name` — optional human-readable label for runner output and filenames.
- `pool_size` — optional integer `>= 1`. When present, the project uses a reusable pool with that many slots. When omitted, `wk add` creates traditional branch-named sibling worktrees.

Unknown project fields are ignored for forward-compatible config evolution.

### Legacy migration

The old config used `[[post_create]]` entries and an optional `shell` field. `wktree` rejects these forms with actionable config errors:

- `[[post_create]]` is rejected with a hint to rename `[[post_create]]` to `[[project]]`.
- `shell` is rejected with a hint that `shell` is no longer supported.

Hooks now always run under bash. Nushell hook execution is intentionally removed from the config surface.

## 5. Worktree paths and pool semantics

### Non-pooled projects

For projects without `pool_size`, `wk add <branch>` creates a sibling path:

```text
<canonical-root>__<encoded-branch>
```

The branch encoder preserves existing workflow convention, including slash-to-double-dash encoding.

### Pooled projects

For projects with `pool_size = N`, `wktree ensure` materializes reusable slots:

```text
<root>__feat1
<root>__feat2
...
<root>__feat<N>
```

Each free slot uses a placeholder branch named:

```text
wk-pool/feat<N>
```

A slot is free when it is on its matching placeholder branch and has completed initialization. Allocating a branch checks that branch out into the lowest-index free slot. Removing a pooled branch recycles the slot back to its placeholder branch and leaves the filesystem directory in place so expensive artifacts such as `node_modules` survive.

When all slots are occupied, `wk add` shows an fzf picker with slot status/preview. After confirmation, the chosen slot is force-recycled and reallocated. Passing `--force` skips the confirmation step after picker selection.

## 6. Reserved branch prefix

`wk-pool/` is reserved for internal placeholder branches. User-facing `wk add` rejects branches with this prefix before performing side effects.

## 7. Hook runtime contract

Hooks always run under bash via generated runner scripts. Runner scripts export:

- `WK_ROOT` — canonical/root worktree path.
- `WK_CREATED` — created worktree path or allocated pool slot path.

For pooled projects, the generated runner writes an initialization marker in the slot git-dir after a successful hook run. This marker is used to distinguish initialized slots from half-created slots after failures.

Bootstrap commands should be idempotent. For pooled projects, commands should reconcile preserved state rather than copying from the root worktree; e.g. `yarn install` is expected to update an existing `node_modules` tree in place.

## 8. Removal and recycling

Non-pooled removal deletes the worktree and its branch.

Pooled removal delegates to recycle:

- Safe recycle refuses dirty slots, local-only branches, or branches with unmerged upstream commits before mutating anything.
- Forced recycle discards tracked changes, removes untracked non-gitignored files, resets to the placeholder branch, and force-deletes the old branch.
- Gitignored caches such as `node_modules/` are preserved.

Returned RemovePlan JSON uses `removed: true` for deleted non-pooled worktrees and `removed: false` for recycled pool slots.

## 9. Testing and verification

Automated checks cover the `wktree` binary, git parser behavior, config parsing, pooled allocation/recycle flows, Nushell wrapper importability, and generated runner scripts.

Useful manual smoke checks:

```bash
wktree list --cwd ~/work/app/deals-light-ui
wk add example-branch
wk remove example-branch --force
```

For the pooled deals-light-ui project, the first command against the repo may materialize five slots and run `yarn install` in each slot. Subsequent allocations should be much faster because slot directories and ignored caches are reused.

## 10. Code Locations

| File | Description |
| --- | --- |
| `oven/bin/wktree.ts` | Worktree engine, config parsing, pool state, allocation/recycle, hook runner generation |
| `oven/shared/git/executor.ts` | Git command runner interface and live implementation |
| `oven/shared/git/worktrees.ts` | Pure parsers for git worktree/trunk/branch output |
| `oven/shared/fzf.ts` | Shared fzf invocation helper used by picker integration |
| `config/nushell/scripts/ct/git/worktree/mod.nu` | Public `wk` command wrappers |
| `config/nushell/scripts/ct/git/worktree/tmux.nu` | Tmux/opening handoff helpers |
| `config/ct-worktrees/trees.toml` | Per-project worktree config |
| `oven/tests/wktree.test.ts` | Binary unit/integration coverage |
| `oven/tests/wktree.smoke.test.ts` | Nushell-driven end-to-end smoke for non-pool and pooled flows |
