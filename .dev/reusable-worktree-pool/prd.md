# Reusable Worktree Pool

**Status:** Planned
**Created:** 2026-04-21
**Related spec:** [specs/git-worktrees.md](../../specs/git-worktrees.md)
**Related research:** [learning-tests.md](./learning-tests.md)

## 1. Overview

### Problem

The existing `wk add` flow (see `specs/git-worktrees.md`) runs a post-create hook after `git worktree add`. For small projects this is fine. For `~/work/app/deals-light-ui` — a yarn-classic monorepo with hundreds of thousands of files in `node_modules` — the hook takes several minutes because:

- The current hook rsyncs `node_modules` from the canonical clone into the new worktree.
- Corporate antivirus scans every file touched, multiplying the cost.
- `yarn install` from cold still takes minutes even with the rsync'd cache.

Result: creating a feature branch is slow enough to break flow.

### Solution

Pre-create a fixed-size pool of reusable worktree slots per pooled repo. Each slot keeps its `node_modules` (and any other gitignored install output) forever. Slot branches rotate — they're recycled back to a placeholder branch rather than torn down. When the user runs `wk add <branch>`, an idle slot is claimed and the hook runs against a warm filesystem. `yarn install` now reconciles an almost-identical `node_modules` instead of building it — expected to drop from multiple minutes to seconds.

### Goals

- Add an opt-in `pool_size` field to the unified `[[project]]` entries in `config/ct-worktrees/trees.toml`. Presence of `pool_size` switches a project into pooled mode; its absence keeps the existing post-create behaviour.
- On first `wk` command against a pooled repo, materialise any missing slots sequentially in the calling terminal, streaming hook output, so first-run cost is explicit to the user.
- `wk add <branch>` on a pooled repo claims a free slot, checks out/creates the branch, and runs the hook in a new kitty window (same handoff UX as today).
- When the pool is full, present an fzf picker to recycle an existing slot.
- `wk remove` on a pooled slot recycles the slot (placeholder + fresh trunk) rather than tearing down the worktree.
- Move the full `wk add` / `wk remove` / `wk list` / `wk path` / `wk root` decision logic — including existing non-pooled behaviour — into a new TypeScript binary. Nushell keeps only what requires shell-specific primitives (cwd changes via `--env`, kitty session open/close). Single source of truth for `trees.toml` parsing.
- Preserve today's non-pooled **observable** behaviour bit-for-bit; the implementation path changes.

### Non-Goals

- Shrinking a pool after it's been sized up — grow-only for now.
- Concurrent `wk` invocations or locking — assume single-user, single-invocation.
- Cross-machine pool state sharing.
- An explicit `wk pool init` command — initialisation is always implicit.
- Separate init / recycle hooks — one command body for both.
- Non-node specifics — the feature is project-type-agnostic; the hook string decides behaviour.
- Changing user-facing post-create behaviour — execution env (`WK_ROOT` / `WK_CREATED`), hook output, and error semantics stay identical for entries without `pool_size`. (The TOML array name changes from `[[post_create]]` to `[[project]]`, but that's a one-shot rename users do once — the runtime contract is unchanged.)
- Shadowing or renaming the user-facing `wk …` nushell commands — they remain the public API.

## 2. Research summary

The existing system is documented in `specs/git-worktrees.md`. Current touchpoints — most MOVE into the new binary rather than gain a sibling pool path:

- `wk-canonical-root` in `helpers.nu` — identifies the root worktree. **Moves to binary** (`gitResolveCanonicalRoot`).
- `wk-worktree-path` in `helpers.nu` — pure function today; becomes a lookup for pooled repos, pure for non-pooled. **Moves to binary**; nushell `wk path` becomes a stdout pass-through.
- `wk-matching-post-create-hooks` in `helpers.nu` — reads `config/ct-worktrees/trees.toml`. **Moves to binary**; binary becomes the sole reader of the unified `[[project]]` config.
- `wk-post-create-runner` in `kitty.nu` — generates the bash runner script for post-create hooks. **Moves to binary** as a single generator that covers both pooled and non-pooled projects (the only difference is whether the pool init-marker is appended).
- `wk-open-dir` in `kitty.nu` — handles kitty session launch. **Stays in nushell**; runner-script generation is extracted out of it (binary supplies `runner_script_path`).
- `wk-default-branch` in `helpers.nu` — auto-detects trunk. **Moves to binary**.
- `wk-list-data` in `helpers.nu` — parses `git worktree list --porcelain`. **Moves to binary**.
- `config/nushell/scripts/ct/git/worktree/mod.nu` — public `wk` surface. **Thinned** to a glue layer that invokes the binary, reads a JSON plan, then performs the shell-only follow-up (cd, `wk-open-dir`, `wk-close-dir`).

## 3. Learning-test findings

See [learning-tests.md](./learning-tests.md) for raw output. Load-bearing results:

1. **node_modules survives across `git checkout -B`** — both branch switching and recycle. This is the whole feature's premise and it holds.
2. **Recycle is a two-command sequence:** `git -C <slot> checkout -B wk-pool/featN origin/<trunk>` then `git branch -D <old>`. Tracked files from the old branch are cleared; gitignored paths are not touched.
3. **`git checkout -B` silently carries dirty tracked changes into the new branch.** Recycle must gate on dirty state — any `git status --porcelain=v1` output, including untracked non-gitignored files — and refuse without `--force`.
4. **Git refuses to check out the same branch into two worktrees** — so allocation must error if the requested branch is already in any slot.
5. **Pool slots are detectable** via `branch_ref` starting with `refs/heads/wk-pool/`.

## 4. Architecture

### Component split

A new TypeScript binary owns all worktree-engine logic: `trees.toml` parsing, canonical-root resolution, git operations, pool state + recycle, hook-runner generation, and all add/remove/list decisions. Nushell keeps only shell-specific primitives: cwd changes (`--env`) and kitty session control (`kitten @` commands).

Binary name: **`wktree`**. The old draft used `wk-pool`, but scope grew beyond the pool once the non-pooled flow moved in too. Name is distinct from the user-facing nushell `wk …` commands because those must remain `--env`-capable to change caller cwd; a binary cannot do that. No shadowing is attempted.

| Layer | Location | Role |
|---|---|---|
| Worktree engine | `oven/bin/wktree.ts` → `~/.local/bin/wktree` | Sole reader of `trees.toml`. Performs all fetch / checkout / worktree-add / branch / recycle git work. Generates the unified post-create / pool-hook runner script. Emits a machine-readable plan on stdout-redirected `--result-file`. Runs fzf picker and confirm prompts on `/dev/tty` when needed. |
| Shell wrapper | `config/nushell/scripts/ct/git/worktree/mod.nu` | `wk add / remove / list / path / root` — thin glue. Invokes `wktree`, reads the plan JSON, does the cd and the `wk-open-dir` / `wk-close-dir` follow-up. No config parsing, no git operations, no branch logic. |
| Kitty handoff | `config/nushell/scripts/ct/git/worktree/kitty.nu` | `wk-open-dir` and `wk-close-dir` — session file authoring, `kitten @ action goto_session`, tab close. Runner-script generation is REMOVED from here; `wk-open-dir` now accepts a `runner_path` provided by the binary. |

### `wktree` subcommand surface

All mutating subcommands take `--cwd <path>` so the binary can resolve the canonical root without relying on its own process cwd (nushell may invoke it from anywhere). All mutating subcommands write their machine-readable plan to `--result-file` rather than stdout, so progress banners and any TTY interaction can coexist cleanly.

| Subcommand | Purpose | Output |
|---|---|---|
| `wktree add --cwd <path> --branch <b> --result-file <p> [--base <b>] [--force]` | Create-or-allocate a worktree for `<b>`. Pooled projects (`pool_size` set): ensure + allocate (fzf picker on full pool). Non-pooled projects (no `pool_size`): today's fetch → detect local/remote/new → `git worktree add` path. In both cases, generates a runner script for the kitty handoff using the project's `command`. | Streams progress to stderr, may prompt on `/dev/tty`. Writes `AddPlan` JSON `{worktree_path, title, runner_script_path, root}` to `<p>`. Exit 0 success, 130 cancel, 2 malformed config, non-zero on other failure. |
| `wktree remove --cwd <path> --result-file <p> (--branch <b> \| --self <path>) [--force]` | Remove-or-recycle. Pool slot → recycle with dirty/unmerged gates. Non-pool worktree → `git worktree remove` + `git branch -d` (matching today). | Writes `RemovePlan` JSON `{worktree_path, removed: bool}` to `<p>`. `removed: true` when the filesystem entry is gone, `false` when a slot was recycled in place. |
| `wktree list --cwd <path> [--json]` | Enumerate worktrees with pool annotation. | Stdout text (human) or JSON. Pooled slots annotated `[pool:free]` or `[pool:feat3]`; JSON gets a `pool` field. |
| `wktree path --cwd <path> --branch <b>` | Resolve stable path for a branch. Pool repo: lookup in slot state (errors if branch not in a slot). Non-pool repo: pure derivation from canonical root + encoded branch. | Stdout string. |
| `wktree root --cwd <path>` | Canonical-root path. | Stdout string. |
| `wktree ensure --cwd <path>` | Materialise missing pool slots inline. No-op on non-pooled repos (exit 0). | Streams banners + hook stdout/stderr to the caller's terminal. Exit non-zero on first failure. |
| `wktree recycle --cwd <path> --slot <path> [--force]` | Direct single-slot recycle (used by `wktree remove` internally, exposed for manual use + tests). | Exit code driven; no result file. |

Subcommands removed from the previous draft (`wk-pool config`, `wk-pool status`, `wk-pool allocate`) collapse into `wktree add` / internal helpers. `wktree status --cwd <path>` is retained as a debugging read-only subcommand (JSON slot table) — useful for tests and manual inspection.

### Config-broken semantics

A malformed `trees.toml` — missing required `[[project]]` fields, an invalid `pool_size`, a duplicate `root`, a legacy `[[post_create]]` section, or an unsupported `shell` field — produces exit code 2 from any subcommand, with a human-readable message on stderr. The nushell wrapper surfaces the stderr and aborts. Repos with valid config (pooled OR non-pooled) see exit 0 and proceed. "Not pooled" is an internal signal, not an exit code, because there is no longer a caller who needs to fork behaviour on it — the binary handles both cases.

### `wk add <branch>` flow (unified)

Nushell `wk add` becomes:

1. `mktemp` a result file.
2. Invoke `wktree add --cwd $env.PWD --branch <b> --result-file <tmp> [--base <b>] [--force]` WITHOUT `| complete` so stdin/stdout/stderr pass through (fzf, prompts, progress streaming all need the real TTY).
3. On non-zero exit: surface the error and stop. On exit 130 (cancel): print "cancelled" and stop. Both paths rm the tmp file.
4. On exit 0: read the `AddPlan` JSON, delete the tmp file.
5. Call `wk-open-dir $plan.worktree_path $plan.title $plan.root --runner-path $plan.runner_script_path`.

Binary side, `wktree add`:

- Resolve canonical root from `--cwd`.
- Parse `trees.toml`. Pooled? Non-pooled? Broken?
- Pooled: run `ensure` inline (sequential slot materialisation); then allocate (duplicate check → free-slot checkout OR fzf picker + recycle + checkout). Details in technical-design.md.
- Non-pooled: `git fetch origin`; decide local / remote / new-branch; `git worktree add …`; `git merge --ff-only origin/<b>` when a remote exists. This matches today's `mod.nu` `wk add` behaviour one-for-one.
- Generate a bash runner script at `~/.config/kitty/sessions/<session>.runner.sh` (identical path + shape to today). Content:
  - Pooled: project `command` body with `WK_ROOT` / `WK_CREATED` AND the init-marker write appended (§Half-init recovery).
  - Non-pooled: project `command` body with `WK_ROOT` / `WK_CREATED`. No init marker (markers are pool-only). If the repo has no matching `[[project]]` entry, no runner is generated (runner_script_path in plan is null).
- Write `AddPlan` to `--result-file`.

### `wk remove` flow (unified)

Nushell `wk remove` becomes:

1. `mktemp` a result file.
2. Invoke `wktree remove --cwd $env.PWD --result-file <tmp> [--branch <b> | --self <tree_dir>] [--force]`.
3. On failure: surface and stop.
4. On success: read `RemovePlan`. If the current `$env.PWD` is inside `plan.worktree_path`, `cd ~` (nushell-only side effect — binary can't change caller cwd). Then `wk-close-dir $plan.worktree_path`.

Binary side, `wktree remove`:

- Resolve target worktree path from `--branch` or `--self`.
- Fetch (needed for safe-recycle merged-upstream check).
- If the path is a pool slot (placeholder or feature branch under `wk-pool/feat<N>` layout), recycle per §Recycle sequence. Filesystem entry stays.
- Else: refuse to remove the canonical root; otherwise `git worktree remove [--force] <path>` + `git branch -{d,D} <branch>`. Matches today's nushell `wk remove` semantics.
- Write `RemovePlan`.

### `wk list` (unified)

Nushell `wk list [--json]` pipes straight through to `wktree list --cwd $env.PWD [--json]`. No post-processing; the binary owns the annotated output format.

### Pool-slot annotations (unchanged from previous draft)

- Human: `[pool:free]` or `[pool:feat3]` suffix per line.
- JSON: `pool` field — `null` for non-pool worktrees, `{index, placeholder}` for pool slots.

### Pool state model

Git is the primary source of truth. A single untracked marker file per slot covers the one case git cannot represent: "was this slot's init hook actually completed?"

- Slot index N has path `<canonical-root>__featN`.
- Slot is "present" iff `git worktree list --porcelain` includes it.
- Slot is "initialized" iff the marker file at `git -C <slot> rev-parse --git-path wk-pool-initialized` exists (resolves to `<root>/.git/worktrees/<slot>/wk-pool-initialized` — inside per-worktree git metadata, NOT in the working tree). The init hook writes this as its last step. Storing the marker inside the git dir rather than the worktree keeps it invisible to `git add` / `git clean` / `checkout -B`. Rollback-on-hook-failure is the primary recovery path; the marker is a second line of defence for the rare case where rollback itself fails.
- Slot is "free" iff its branch ref equals `refs/heads/wk-pool/featN` AND it is initialized.
- Slot is "taken" iff on any other branch.
- Slot is "dirty" iff `git status --porcelain=v1` in the slot produces ANY output — tracked modifications OR untracked files (`??` lines). `git status` already excludes gitignored paths by default, so `node_modules/` and friends never appear there and never trigger the gate; they're preserved by the recycle mechanism itself (`checkout -B` doesn't touch gitignored files). Anything that does appear in porcelain output is potentially-user work that must not be silently destroyed.
- Reserved branch namespace: user branches starting with `wk-pool/` are rejected by `wktree add` — the prefix is exclusively for internal placeholders.

### Config shape

`config/ct-worktrees/trees.toml` has a single top-level array, `[[project]]`. Each entry describes one repo's post-create automation. A `pool_size` field turns the project into pooled mode; without it, the entry behaves exactly like today's `[[post_create]]`. The binary is the SOLE reader of this file — nushell no longer opens it.

```toml
# Pooled project — pool_size present
[[project]]
name = "deals-light-ui"
root = "~/work/app/deals-light-ui"
pool_size = 5
command = '''
yarn install
notif worktree wk "$WK_CREATED" ready
'''

# Non-pooled project — no pool_size, same semantics as today's [[post_create]]
[[project]]
name = "some-other-repo"
root = "~/code/some-other-repo"
command = '''
pnpm install
'''
```

Rules:

- `root` and `command` are required for every entry. Missing → config error, exit code 2.
- `pool_size` optional. When present it must be an integer ≥ 1. Its presence is the sole signal that this project uses a pool.
- `name` optional human-friendly label used in log lines and runner-script filenames; defaults to a derivation from `root`.
- Each `root` may appear at most once. Duplicate → config error. This replaces the previous draft's cross-array overlap rule and is strictly simpler — there's nothing to cross-check.
- Unknown fields are ignored (forward-compat).
- Hook language is always **bash**. The previous draft's `shell = "bash" | "nu"` option is dropped — there is no real-world user of `shell = "nu"` in the repo's current `trees.toml`, and the runner is simpler without the branch. If a nushell body is ever needed, the user can put `nu -c '…'` inside the bash command.

**Migration.** The existing `[[post_create]]` section for `deals-light-ui` is replaced by a single `[[project]]` entry with `pool_size = 5`. Any other repos the user has today (currently zero in-repo) move from `[[post_create]]` to `[[project]]` with no other changes; a migration note goes in `specs/git-worktrees.md`. Old `[[post_create]]` entries are not auto-accepted — the binary errors on them with a clear "rename to `[[project]]`" message so nothing silently does the wrong thing. Any entry carrying a `shell` field is rejected with a clear "`shell` is no longer supported; command always runs under bash" message.

### Internal conventions (not configurable in v1)

- Slot prefix: `feat`. Slot paths: `<root>__feat1`, `<root>__feat2`, …
- Placeholder branch prefix: `wk-pool/`. Slot N's placeholder is `wk-pool/featN` (a local branch in the canonical repo, tracking `origin/<trunk>`).
- Trunk: detected via `git symbolic-ref refs/remotes/origin/HEAD`, falling back to parsing `git remote show origin`. If git can't determine it, `wktree ensure` errors.

### Execution contexts for the hook

| Context | Where it runs | Output |
|---|---|---|
| Pool init (missing slot) | Inline in the caller's shell, sequential across slots | Streams to stdout; `[wk-pool] initializing feat3…` banner per slot |
| Allocation (handoff) | New kitty window via `wk-open-dir --hold` | Runner prints the human-friendly hook label; hook stdout visible in the held window |

`WK_ROOT` and `WK_CREATED` are set identically in both contexts, matching the existing contract documented in `specs/git-worktrees.md`.

### Recycle sequence (high-level)

See `technical-design.md` for full git commands. High-level shape:

- Default (no `--force`): refuse if dirty (any porcelain output — tracked OR untracked non-gitignored), refuse if feature branch unmerged upstream (`branch -d` semantics). Otherwise checkout placeholder on latest trunk, delete feature branch.
- Forced: `checkout -f -B` + `reset --hard` to actually discard tracked dirt; `branch -D` to force-delete unmerged branch. Untracked non-gitignored files are NOT explicitly deleted — `checkout -B` leaves them in place, and the user consented to losing state via `--force`. Gitignored files (node_modules/, caches) are always preserved — that's the feature.

Invoked from three places: `wktree remove` on a pooled slot, `wktree recycle`, and inside the picker's confirm path (always `--force` because picker confirmation IS the consent).

### Picker UX

When `wktree add` finds no free slot it spawns fzf with:

- Header: `pool full — pick a slot to recycle, or esc to cancel`
- Each row: `featN  <branch>  <relative-last-commit>  <dirty-flag>`
- Preview pane: `git -C <slot> log -5 --oneline` + `git status --porcelain | head` for dirty lines.
- Cancel (exit 130) → `wktree add` exits 130 with "cancelled" on stderr; nushell surfaces that as an error and does not open kitty.
- Pick → confirm prompt (`Recycle feat3 (my-old-feature, 12 days old)? [y/N]`) → on y, recycle with `--force`, then allocate.

### First-run behaviour walk-through

User has a `[[project]]` entry for `~/work/app/deals-light-ui` with `pool_size = 5`, currently zero slots exist.

```text
$ cd ~/work/app/deals-light-ui && wk add cool-feature
[wk-pool] initializing feat1…
  creating worktree at …/deals-light-ui__feat1 on wk-pool/feat1
  running hook (inline):
    + yarn install
    yarn install v1.22.22 …
    Done in 180s
[wk-pool] initializing feat2…
  …
[wk-pool] initializing feat5…
  …
[wk-pool] allocating cool-feature → feat1
opening kitty session 'deals-light-ui--feat1'
```

Subsequent invocations skip init entirely.

## 5. User stories and acceptance criteria

### Story 1 — configure a pool

**As** a developer with a slow-install monorepo,
**I want** to declare a fixed number of reusable worktree slots, with config errors surfaced loudly,
**so that** each new feature branch reuses a pre-warmed `node_modules` — and a typo in config doesn't silently succeed on a broken config.

**Acceptance:**
- `config/ct-worktrees/trees.toml` accepts `[[project]]` entries with `root`, `command`, and optional `pool_size` + `name`.
- Missing or invalid fields produce a helpful error at next `wk` invocation against that root — the `wk` command aborts rather than completing silently.
- A duplicate `root` across entries produces the same helpful abort.
- Legacy `[[post_create]]` sections and legacy `shell` fields are rejected with migration-hint messages.
- The binary is the only reader of `trees.toml`. Config errors surface uniformly with exit code 2 + stderr detail; the nushell wrapper relays the stderr and stops.

### Story 2 — first-run pool materialisation

**As** a developer running any `wk` command against a pooled repo for the first time,
**I want** all missing slots to be created sequentially in my current terminal with live progress,
**so that** I can see what's happening and the one-time cost is obvious.

**Acceptance:**
- `wk add`, `wk remove`, `wk list` (any of them) trigger pool-ensure inside `wktree` if the repo is pooled.
- Slots are created one at a time in numeric order (`feat1`, then `feat2`, …) — never in parallel.
- Each slot's hook runs inline in the current terminal WITH cwd=slot_path, streaming stdout/stderr live (nushell invokes the binary without `| complete` so nothing buffers).
- A banner identifies the slot being initialised: `[wk-pool] initializing feat3…`.
- On slot hook failure: progress reports the error; the half-materialised slot is rolled back via `git worktree remove --force`; the binary exits non-zero immediately. Already-initialized slots are left intact. The user can re-run any `wk` command to retry from the failed slot.
- A slot that has a worktree on disk but no completed initialisation marker is treated as "needs work" on the next ensure — the hook re-runs against it rather than being silently skipped.

### Story 3 — allocate with free slots

**As** a developer running `wk add my-branch [base]` on a pooled repo with at least one free slot,
**I want** the lowest-indexed free slot claimed and opened in kitty with my branch checked out, updated to remote if it exists,
**so that** I can start working immediately against the latest code — matching today's non-pooled behaviour.

**Acceptance:**
- `wktree add --branch my-branch` picks the lowest-index free slot.
- If `my-branch` exists locally or remotely, it's checked out (no recreation). If it also has `origin/my-branch`, the binary runs `git merge --ff-only origin/my-branch` after checkout to match today's wk-add behaviour; a diverged local branch emits a warning and the user's work is preserved.
- If `my-branch` doesn't exist anywhere, it's created from `origin/<base>` (if `base` supplied) or `origin/<trunk>` (default). A supplied `base` is ignored for existing branches with a stderr warning.
- The hook runs in a new kitty window with `WK_ROOT` + `WK_CREATED` set AND cwd=slot_path, so `yarn install` and similar warm the correct tree.

### Story 4 — allocate when pool is full

**As** a developer with all slots in use,
**I want** an fzf picker showing each slot's branch, activity, dirty state, and unpushed-commit count, and the chance to cancel,
**so that** I can consciously recycle something I'm done with or back out and handle it manually — with full visibility of what force-recycle would destroy.

**Acceptance:**
- Picker rows show `featN  <branch>  <relative-age>  [dirty]?  [N ahead]?`.
- Preview shows recent commits, uncommitted-file list, and ahead/behind-upstream counts. A warning line flags "⚠ N unpushed commits will be lost" when the branch has commits not on its upstream, or "⚠ local-only branch" when no upstream is set.
- Cancel (esc) → `wk add` exits cleanly with a "cancelled" message; no changes.
- Select → confirm prompt showing the dirty / unpushed / local-only warnings inline → on `y`, slot recycles with `--force` semantics (discards tracked dirt, force-deletes the old branch) and the branch is allocated into it.
- Confirm prompt is suppressed by passing `--force` to `wk add`.

### Story 5 — duplicate allocation is an error

**As** a developer,
**I want** `wk add <branch>` to fail loudly if `<branch>` is already checked out anywhere,
**so that** I don't end up with inconsistent state (and so the error beats git's own confusing "already used" message).

**Acceptance:**
- `wktree add` scans EVERY worktree (canonical root, pool slots, any ad-hoc worktrees) before recycle/checkout.
- If any worktree's current branch equals the requested branch, exit non-zero with a message naming the worktree path.
- No recycle, checkout, or kitty window opens.
- Branch names under the reserved `wk-pool/` prefix are rejected with a clear message before any other check.

### Story 6 — recycle via `wk remove`

**As** a developer,
**I want** `wk remove <branch>` (or `wk remove --self`) on a pooled slot to recycle rather than delete, AND to refuse atomically by default if that would lose work,
**so that** node_modules is preserved AND I can't accidentally throw away unmerged commits or uncommitted edits — and a refused recycle leaves the slot exactly as it was.

**Acceptance:**
- Default recycle (`wk remove <branch>`):
  - Checks are performed BEFORE any mutation (dirty state + branch merged-into-upstream). If either check fails, the command aborts with a clear message and the slot + branch are untouched.
  - Refuses if `git status --porcelain=v1` in the slot has ANY output — tracked modifications OR untracked non-gitignored files (e.g. a new `notes.md` that wasn't `git add`ed). User must pass `--force`, or `git add` + commit/stash their work first. Gitignored paths (node_modules/, caches) are excluded by `git status` by default and never trigger the gate.
  - Refuses to delete the feature branch if it has commits not merged into its upstream, or if it has no upstream configured. `--force` escalates to `-D`.
  - On success: slot checked out to placeholder on latest trunk; feature branch deleted; kitty tab closed.
- Forced recycle (`wk remove <branch> --force`):
  - Skips dirty gate and merged-upstream check.
  - Uses `git checkout -f -B` + `git reset --hard` to ensure tracked dirt is actually discarded (learning test LT10 showed `checkout -B` alone can carry dirt).
  - Uses `git branch -D` to force-delete the old branch even if unmerged.
  - Gitignored paths (`node_modules/`, caches) are preserved in both cases — the whole point. Untracked non-gitignored files reach the forced path only when the user explicitly opted in via `--force`; `checkout -B` leaves them in place rather than deleting them.
- The slot's worktree directory is NOT removed in either case.
- After recycle, `wk list` reports the slot as `[pool:free]`.

### Story 7 — visibility via `wk list`

**As** a developer,
**I want** `wk list` to tell me which worktrees are pool slots and what they currently hold,
**so that** I can reason about pool state without remembering the convention.

**Acceptance:**
- Human output annotates pool slots: `[pool:free]` for placeholder, `[pool:feat3]` with slot index for taken slots.
- `wk list --json` emits a `pool` field per worktree, null for non-pool.

### Story 8 — non-pooled repos keep today's behaviour via the new binary

**As** a developer working on a non-pooled repo,
**I want** `wk` to behave identically to today,
**so that** even though the implementation moved from nushell into a binary, nothing I see changes.

**Acceptance:**
- For non-pooled projects (a `[[project]]` entry without `pool_size`), `wk add`, `wk remove`, `wk list`, `wk path`, `wk root` produce the same observable output, side effects, and exit behaviour as today's nushell implementation.
- Non-pooled project hooks run with the same `WK_ROOT` / `WK_CREATED` env, the same kitty-window handoff, and the same bash execution as today's `shell = "bash"` path.
- The runner script's path and shape remain compatible with today's kitty session file (same `launch … --hold bash <runner>` invocation), so muscle memory and any ad-hoc tooling that inspects sessions keeps working.
- Implementation path changes: nushell helpers `wk-canonical-root`, `wk-worktree-path`, `wk-encode-branch`, `wk-default-branch`, `wk-list-data`, `wk-post-create-hooks`, `wk-matching-post-create-hooks`, and `wk-post-create-runner` are removed. Their callers in `mod.nu` are replaced by `wktree` invocations.
- The existing `[[post_create]]` section in `trees.toml` is migrated in the same PR: the deals-light-ui entry becomes a single `[[project]]` entry with `pool_size = 5`. No other `[[post_create]]` entries exist today.
- Removed capability: `shell = "nu"`. There is no in-repo user of this option; it can be reintroduced by inlining `nu -c '…'` in a bash command body if needed.
- Ring-2 integration tests cover the non-pool flow through the new binary with at least the same coverage the nushell smoke test has today.

## 6. Technical considerations

### Binary surface IS the public API

All `wk …` nushell commands become thin adapters over `wktree` subcommands. The decision "which subcommand to call" is fixed per user-facing verb; there is no remaining per-repo branching in nushell. This gives one place to change behaviour, one place to test, one place to log.

### Path / branch decoupling

Today `wk-worktree-path $branch` is a pure function. For pooled repos it becomes a lookup into slot state. Both paths live in the binary under `wktree path`. If the branch isn't in a pool slot for a pooled repo, the binary errors. Non-pooled repos keep the pure derivation. Nushell `wk path` is a stdout pass-through.

### Placeholder-branch hygiene

The recycle step uses `git checkout -B wk-pool/featN origin/<trunk>`, which resets the placeholder branch to the current trunk tip. This means the placeholder is always fresh at the point a slot becomes free — subsequent allocations branch off a current trunk without an extra step.

### Dirty-gate scope

The recycle dirty gate blocks on ANY line in `git status --porcelain=v1` — tracked modifications AND untracked non-gitignored files (`??` lines). A `??` line represents a file the user created but hasn't added yet; silently losing that on recycle would be a footgun. Gitignored paths (`node_modules/`, `.cache/`, build outputs covered by `.gitignore`) do not appear in porcelain output and so don't trigger the gate — preserving them is the feature's point, and they survive recycle independently via `checkout -B`'s behaviour.

Consequence: if the user explicitly wants to throw away an untracked scratch file on a pool slot, they pass `--force` (or delete the file first). Consistent with `git clean`'s own default safety stance.

### Hook execution parity

The hook runs in two execution contexts (inline init, kitty handoff) with identical env (`WK_ROOT`, `WK_CREATED`). During init `WK_CREATED` points at the slot being initialised; the hook should be idempotent because it runs once per slot at init and again on each allocation. `yarn install` is idempotent-enough for practical purposes.

### Error propagation from kitty handoff

Open question from the original spec: hook failures in kitty don't bubble back to `wk add`. This feature does not change that. Init-time failures DO bubble back because init runs inline. Documenting as an accepted limitation; keeps scope tight.

### TypeScript layer details

- Follow `oven/CLAUDE.md` conventions: per-subcommand lib functions exported from `shared/wktree/`, CLI wrapper in `bin/wktree.ts` guarded by `import.meta.main`, dependency-injected executors (`GitExecutor`, `HookExecutor`, `Picker`, `ProgressReporter`) for tests.
- Use `Bun.spawn` (not `Bun.$`) inside `GitExecutor` so tests can introspect args exactly.
- Subcommand dispatch: first positional arg picks the subcommand; remaining args go through `parseArgs`.
- Tests in `oven/tests/wktree/`. Two rings as described in technical-design.md — ring 1 mocked, ring 2 real git in tmp repos.

### What stays in nushell (and why)

- **cwd changes**: `cd ~` before removing the worktree the caller is sitting in; `cd <new>` in the non-kitty fallback inside `wk-open-dir`. Only `--env` defs in nushell can move the caller's shell.
- **Kitty session open/close**: `wk-open-dir` writes a `.session` file and calls `kitten @ action goto_session`; `wk-close-dir` calls `kitten @ ls` + `kitten @ close-tab`. These are kitty-IPC calls whose convenient client is already in nushell; no value in reimplementing.
- **Plan-result glue**: `mktemp`, invoke binary, `open <tmp> | from json`, delete. Trivial lines but they must live in shell to avoid breaking inherited-TTY behaviour for interactive subcommands.

Everything else — `trees.toml` parse, canonical-root resolution, branch inspection, fetch, worktree add / remove / list, runner-script generation — moves to the binary.

### Nushell shape after the move

`mod.nu` `wk add` collapses from ~40 lines of git-inspection + conditional logic to roughly:

```nu
export def --env "wk add" [branch: string, base?: string, --force] {
  let result_file = (mktemp)
  let args = ([add --cwd $env.PWD --branch $branch --result-file $result_file]
    ++ (if $base  == null { [] } else { [--base  $base] })
    ++ (if $force         { [--force] } else { [] }))

  ^wktree ...$args          # inherits TTY; may prompt; streams
  let exit = $env.LAST_EXIT_CODE
  if $exit != 0 { rm -f $result_file; error make { msg: $"wktree add failed (exit ($exit))" } }

  let plan = (open $result_file | from json)
  rm -f $result_file
  wk-open-dir $plan.worktree_path $branch $plan.root --runner-path $plan.runner_script_path
}
```

`wk remove`, `wk list`, `wk path`, `wk root` follow the same pattern — invoke, read, maybe cd / close-tab. Full shapes in technical-design.md.

## 7. QA criteria

### Agent-verifiable

- **TS unit tests (ring 1)** in `oven/tests/wktree/` covering: config parse (happy + errors — missing `root`/`command`, bad `pool_size`, duplicate `root`, legacy `[[post_create]]`, legacy `shell` field), canonical-root / trunk detection, `wktree list` porcelain parsing, slot state detection over mocked git, allocate to free slot, allocate with full pool triggers picker (mocked), recycle sequence both paths (safe + forced), dirty-gate behaviour, duplicate-across-all-worktrees detection, reserved-prefix rejection, `--base` handling (new vs existing branch), hook-failure rollback, half-init recovery via marker absence, **non-pool `add` local/remote/new-branch matrix**, **non-pool `remove` safe + forced paths**.
- **TS integration tests (ring 2)** against real git in tmp repos; run BY DEFAULT in `bun run verify`. Covers the same matrix end-to-end to catch git-version drift and flag changes. Includes the non-pool flow end-to-end (today's nushell smoke coverage ported).
- **Nushell syntax check:** `nu -c 'nu-check --debug --as-module config/nushell/scripts/ct/git/worktree/mod.nu'` (and `kitty.nu`) passes. (`helpers.nu` is deleted as part of this feature.)
- **Build:** `cd oven && bun run verify` passes (includes ring-2 integration tests).
- **Smoke test:** extend the existing worktree smoke test to exercise BOTH a non-pool `[[project]]` and a pooled `[[project]]` (with `pool_size`) against a synthetic `$XDG_CONFIG_HOME` — non-pool path verifies the post-create command still runs via the binary; pool path verifies init, allocate, recycle.

### Human-verifiable

- Real run on `deals-light-ui` — timings for:
  - First `wk add cool-feature` (cold init, 5 slots) — expected multi-minute one-time cost.
  - Second `wk add another-feature` (already initialised) — expected seconds to ~1 minute.
  - `wk remove cool-feature` — recycle timing and visible state (`wk list`).
  - `wk add` when pool is full — picker UX, preview readability, cancel path.
- Visual: kitty session opens for handoff; init phase stays in caller terminal (no rogue windows).
- Error paths: kill network mid-init → see failure bubble back; try `wk add` with branch already in a slot → see duplicate error.

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `yarn install` reconciliation isn't as fast as hoped on the real repo | Timing is human-verifiable before merge; if disappointing, revisit (maybe `yarn install --offline --prefer-offline` in the hook) |
| Placeholder branches accumulate cruft (e.g. rebased commits) across recycles | `checkout -B … origin/<trunk>` resets them every recycle — no accumulation |
| User commits on a placeholder branch by mistake | Dirty-gate blocks recycle; user can rescue via normal git; feature surface doesn't add new ways to lose work |
| `wktree` binary not built yet on fresh machine | `make build` is part of bootstrap; nushell wrappers fail loudly with "wktree not in PATH" if missing; boot order is: `make build` before any `wk …` invocation |
| Non-pool behaviour regresses when porting from nushell to TS | Ring-2 integration tests cover today's full matrix (new branch, existing local, existing remote, existing local with diverged remote, missing project entry); smoke test exercises a real post-create command end-to-end; manual verification on an existing non-pool repo before merge |
| Shadowing `wk` binary confuses users | Binary name is `wktree`, not `wk`. The nushell `wk …` commands remain the user-facing surface and keep their `--env` ability to change caller cwd. Documented in spec update |
| Deleted nushell helpers called by something outside this module | Grep the monorepo for `wk-canonical-root`, `wk-worktree-path`, `wk-encode-branch`, `wk-default-branch`, `wk-list-data`, `wk-post-create-hooks`, `wk-matching-post-create-hooks`, `wk-post-create-runner` before deletion; any external caller gets migrated to `wktree` subcommand invocations |
| Two `wk add` invocations race and both pick feat1 | Documented non-goal (no concurrency). Unlikely in practice; acceptable risk for v1 |
| Hook fails mid-init, leaves a half-materialised slot | Rollback on failure (`git worktree remove --force`); init marker (in per-worktree git dir) ensures next `ensure` catches any slot that slipped through rollback |
| Malformed config silently does the wrong thing | Exit code 2 from any subcommand on any config error; nushell wrapper always surfaces the binary's stderr and aborts |
| Picker / confirm prompt invisible when output is captured | `Picker` impl attaches fzf + prompt to `/dev/tty` directly; allocate writes machine result to `--result-file` so stdout/stderr stay reserved for the interactive channel |
| Safe recycle mutates slot and then fails to delete branch | Preflight check for dirty + unmerged-upstream runs BEFORE `checkout -B`; mutation only happens once delete is proven safe |
| User has unpushed commits in a slot and selects it in the picker | Picker preview surfaces ahead-count + unpushed warning; confirm prompt requires explicit consent |
| User creates a branch under `wk-pool/*` manually, confusing allocation | Validation at allocate time rejects the reserved prefix; documented in PRD |

## 9. Open questions

None blocking. Captured for later:

- Whether to support shrinking a pool.
- Whether to reintroduce a `shell` option for `[[project]]` entries (now always bash). Unlikely — `nu -c '…'` inside a bash command body is a sufficient escape hatch.
- Whether to bubble kitty-side hook failures back to `wk add` — shared with existing spec's open questions.

## 10. Technical design

See [technical-design.md](./technical-design.md) for the `wktree` binary's module layout, injectable interfaces, exact git command inventory, control flow per subcommand, nushell integration, and the two-ring testing strategy.


