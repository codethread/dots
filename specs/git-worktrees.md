# Git Worktrees

**Status:** Partial  
**Last Updated:** 2026-05-01

## 1. Overview

### Purpose

The git worktree system provides a deterministic local engine for creating, reusing, inspecting, and removing repository worktrees. It exists to make branch/task switching fast for humans while exposing the same underlying contract to agents and orchestration tools. Tmux is the expected shared navigation/runtime surface, but durable state lives in git and the filesystem, not in tmux.

### Goals

- Keep git/worktree lifecycle complexity inside `wktree`, a deep engine with a small command interface.
- Use deterministic branch, path, and session identity so humans, agents, tmux, and filesystem state stay aligned.
- Support fast interactive switching for humans and non-focus-stealing machine workflows for agents.
- Reconstruct current state by parsing authoritative sources instead of maintaining a synchronized app database/cache.
- Provide opt-in pooled slots for rare high-cost repositories where bootstrapping each worktree is expensive.
- Surface destructive or ambiguous choices with enough structured information for safe human or agent decisions.

### Non-Goals

- No durable worktree/session database beyond git metadata, filesystem paths, project config, and ephemeral tmux state.
- No tmux resurrection or persistent session registry for worktrees.
- No requirement that every worktree always has a live tmux session.
- No generalized pooled-worktree abstraction for all repositories; pools are expected for only one or two high-cost repos.
- No detailed specification of Nushell wrapper UX, fzf previews, keybindings, or exact tmux window layout.

## 2. Design Decisions

- **Decision:** `wktree` is the source of truth for git/worktree state transitions.
  - **Rationale:** Worktree creation, removal, pool allocation, recycling, safety checks, and bootstrap planning are the complex parts. Keeping them in one engine avoids duplicated shell logic and gives agents the same behavior humans use.

- **Decision:** Tmux is a first-class consumer but not durable state.
  - **Rationale:** Tmux is the shared navigation/runtime layer: humans and agents can inspect the same sessions when they exist. However, sessions are ephemeral; after reboot, worktrees may exist without tmux sessions. Commands must be able to recreate/navigation state from git and filesystem parsing.

- **Decision:** Session identity is concrete and derived from worktree path.
  - **Rationale:** Existing switching logic depends on stable tmux session names. Consumers must not invent names. The contract is:
    - `session.name = basename(worktree_path).replaceAll(".", "_")`
    - `session.path = worktree_path`
    - default window/title = branch name

- **Decision:** Branch/path naming is the coordination spine.
  - **Rationale:** Deterministic naming keeps git, filesystem, tmux, humans, and agents synchronized. Naming changes are high-risk migrations.
    - Non-pooled path: `<canonicalRoot>__<branch encoded with / as -->`
    - Pooled slot path: `<canonicalRoot>__featN`
    - Pooled placeholder branch: `wk-pool/featN`

- **Decision:** Canonical/root worktree is protected and anchors defaults.
  - **Rationale:** The canonical root drives config lookup, sibling path generation, default branch detection, and safety checks. It must not be removed or reused as a disposable worktree.

- **Decision:** New branches default to origin's default branch/trunk, not current HEAD.
  - **Rationale:** This avoids accidental stacked branches when running from another worktree. Intentional stacking is supported through explicit base selection, including `wk add --self` in the human wrapper.

- **Decision:** Pooled worktrees are explicit per-project optimizations.
  - **Rationale:** Pools trade simple branch-named paths for bounded reusable environments. This is valuable for high-cost repos but unnecessary complexity for normal repositories.

- **Decision:** Pool exhaustion is a recoverable blocked state, not an implicit expansion.
  - **Rationale:** Current behavior keeps pool capacity fixed and requires explicit recycling. Future pool growth may be useful, but should be added only when needed. Machine consumers need structured slot/risk data so they can decide whether to recycle safely.

- **Decision:** Interactive and machine modes differ in presentation, not engine semantics.
  - **Rationale:** Humans can use fzf/prompts and focus-following tmux behavior. Agents need non-interactive, non-focus-stealing behavior with structured outcomes and explicit destructive intent.

- **Decision:** Bootstrap hooks are part of ready-to-work semantics.
  - **Rationale:** Configured project commands prepare worktrees/slots for use, especially expensive pooled repos. Hook failures must fail loudly and avoid marking an unusable slot as initialized.

- **Decision:** Prefer fresh parsing over synchronized caches.
  - **Rationale:** Git worktree metadata, filesystem paths, config files, and live tmux state are quick enough to inspect. Avoiding extra state reduces drift and recovery complexity.

## 3. Engine Contract

`wktree` owns the git/worktree lifecycle contract. Shell, tmux, and agent wrappers are consumers.

### Current command surface

- `wktree root --cwd <path>` prints canonical worktree root.
- `wktree list --cwd <path> [--json]` lists worktrees and initializes configured pools.
- `wktree path --cwd <path> --branch <branch>` prints the worktree path for a branch.
- `wktree add --cwd <path> --branch <branch> [--json] [--slot <path>] [--base <branch>] [--force]` creates/allocates a worktree and emits a structured ready/pool-full/blocked payload in machine mode.
- `wktree remove --cwd <path> (--branch <branch> | --self <path>) [--json] [--force]` removes/recycles and emits a structured ready/blocked payload in machine mode.
- `wktree ensure --cwd <path>` materializes configured pool slots.
- `wktree status --cwd <path>` prints pool status JSON.
- `wktree recycle --cwd <path> --slot <path> [--force]` recycles a pooled slot.


### Machine-readable direction

Structured output is required where a command returns multi-field data or a decision state. Scalar commands may remain plain text unless metadata becomes necessary.

Machine/JSON mode should follow these rules:

- `--json` enables direct machine stdout for structured commands.
- stdout contains only the structured payload.
- stderr contains diagnostics, progress, warnings, and human-readable errors.
- exit `0` means the requested action/query completed.
- non-zero JSON outcomes are allowed for blocked/recoverable states.
- agents branch on a `kind` field rather than parsing stderr.

Important planned outcome kinds include:

- `ready` — worktree exists and is ready for consumers.
- `pool_full` — no free pooled slot; candidates and risk metadata are provided.
- `blocked` — operation refused because it would be unsafe without explicit force/choice.

A successful add-like outcome should include at least:

```json
{
  "kind": "ready",
  "worktree_path": "/repo__feature--foo",
  "branch": "feature/foo",
  "title": "feature/foo",
  "session": {
    "name": "repo__feature--foo",
    "path": "/repo__feature--foo"
  },
  "runner_script_path": null,
  "created_new_branch": true
}
```

A successful remove-like outcome should include at least:

```json
{
  "kind": "ready",
  "worktree_path": "/repo__feature--foo",
  "removed": true,
  "session": {
    "name": "repo__feature--foo",
    "path": "/repo__feature--foo"
  }
}
```

`list --json` returns an array of worktree objects using snake_case metadata keys such as `branch_ref`, `lock_reason`, and `prunable_reason`, plus `session = { name, path }` derived from each worktree path.

A pool-full outcome should provide enough data for a human or agent to choose deliberately:

```json
{
  "kind": "pool_full",
  "root": "/repo",
  "branch": "feature/foo",
  "candidates": [
    {
      "slot": 1,
      "path": "/repo__feat1",
      "branch": "feature/old",
      "dirty": false,
      "ahead": 0,
      "local_only": false,
      "last_commit_iso": "2026-05-01T00:00:00Z",
      "last_commit_subject": "example"
    }
  ]
}
```

## 4. Tmux and Wrapper Boundary

Tmux integration is central to the workflow but should be driven from engine outputs.

- `wktree` must emit deterministic worktree/session identity.
- Human wrappers may focus/switch to the returned session.
- Agent/orchestration wrappers may create or update detached tmux sessions without stealing focus.
- Tmux state must not be required to prove git/worktree correctness.
- Missing tmux sessions are normal and reconstructable from worktree state.

Current consumers include:

- Nushell `wk` commands in `config/nushell/scripts/ct/git/worktree/`.
- Tmux keybindings in `config/tmux/tmux.conf`.
- General session switching in `home/.local/bin/tmux-session`.

These consumers may evolve independently as long as they preserve the engine contract and session identity convention.

## 5. Pool Semantics

A configured project with `pool_size` uses fixed reusable slots:

- slot path: `<root>__featN`
- placeholder branch: `wk-pool/featN`
- placeholder branches are reserved protocol names
- initialized slots contain a `wk-pool-initialized` marker in git metadata

Allocation uses initialized placeholder slots first. When no free slot exists, interactive consumers may present a picker; machine consumers should receive structured pool-full data and must provide an explicit choice/force-like intent to recycle.

Safe recycling refuses dirty slots, branches without upstreams, and branches not merged to upstream. Forced recycling may discard tracked/untracked local work and delete the old branch, while preserving gitignored files such as dependency directories.

Future note: growing a pool may become useful for high-concurrency work on heavy repos, but dynamic pool expansion is not part of the current contract.

## 6. Bootstrap Hooks

Project config lives at `ct-worktrees/trees.toml`.

Each `[[project]]` may define:

- `name`
- `root`
- `command`
- optional `pool_size`

The command always runs under bash and receives:

- `WK_ROOT` — canonical/root worktree path
- `WK_CREATED` — created worktree or allocated slot path

Hook output may be streamed to users. Hook failure must fail loudly. Newly-created pooled slots are rolled back on bootstrap failure; existing half-initialized slots remain uninitialized until a later successful run.

## 7. Code Locations

| File | Purpose |
| --- | --- |
| `oven/bin/wktree.ts` | Main engine, CLI dispatch, pool lifecycle, add/remove plans, bootstrap runners |
| `oven/shared/git/worktrees.ts` | Pure git worktree parsers and pool-slot detection |
| `oven/tests/wktree.test.ts` | Behavioral reference for engine and integration cases |
| `oven/tests/wktree.smoke.test.ts` | Nushell wrapper smoke coverage |
| `config/ct-worktrees/trees.toml` | Local project bootstrap/pool configuration |
| `config/nushell/scripts/ct/git/worktree/` | Human-facing Nushell consumers of `wktree` |
| `home/.local/bin/tmux-session` | General tmux session switching and path-derived naming |
| `config/tmux/tmux.conf` | Keybindings that expose worktree/session workflows |

## 8. Testing

Automated behavioral coverage lives in:

- `oven/tests/wktree.test.ts`
- `oven/tests/wktree.smoke.test.ts`

The tests are the detailed reference for edge cases. This spec captures durable contracts, boundaries, and rationale rather than restating every assertion.

## 9. Resolved Questions

- Direct machine stdout uses `--json` on `add` and `remove`.
- Exit codes are standardized as: `0` success/ready, `10` blocked/recoverable, `11` unsafe operation refused without force, `12` usage/config error, `130` cancelled.
- Explicit non-interactive slot selection uses `wktree add --slot <path>` for allocation/recycle targeting, while `wktree recycle --slot <path>` remains the direct recycle primitive.
