# Technical design — `wktree` binary

Companion to [prd.md](./prd.md). Covers module layout, Effect service definitions, git command inventory, control flow per subcommand, nushell integration, and testing strategy.

Scope: the binary owns all worktree-engine logic (both pooled and non-pooled flows), is the sole reader of `trees.toml`, and generates the unified hook runner script. Nushell keeps only shell-specific primitives.

## Module layout

```
oven/
├── bin/
│   └── wktree.ts                    # CLI entry, subcommand dispatch, and all wktree logic
│                                    # Types, config, pool state, hook gen, progress, fzf picker
│                                    # Effect Services, Layers, and all subcommand implementations
├── shared/
│   ├── git/
│   │   ├── executor.ts              # Git Service (Context.Tag + live Layer via Bun.spawn)
│   │   └── worktrees.ts             # pure parsers: parseWorktreeList, detectTrunk, branchExists
│   ├── fzf.ts                       # extended: header, preview, confirm opts (replaces picker.ts)
│   ├── report.ts                    # existing
│   ├── ansi.ts                      # existing
│   └── claude-hooks.ts              # existing
└── tests/
    └── wktree.test.ts               # single file; real git in mkdtemp /tmp; Layer substitution
```

`shared/git/executor.ts` and `shared/git/worktrees.ts` are deliberately outside `wktree.ts` — they contain reusable git infrastructure any future `oven/bin` tool can import. Everything specific to the worktree pool feature lives directly in `wktree.ts`.

## Effect dependency

Add to `oven/package.json`:

```json
"dependencies": {
  "effect": "^3"
}
```

`@effect/platform` is NOT added — Bun-native IO (Bun.spawn, Bun.file, Bun.write) is wrapped in `Effect.tryPromise` directly. The `effect` package is sufficient for services, layers, errors, and control flow.

## Type surface

All types live at the top of `wktree.ts`.

```ts
// ── Config types ──────────────────────────────────────────────────────────────
interface ProjectConfig {
  name: string | null;
  root: string;             // expanded absolute path — unique across config
  command: string;          // always-bash body
  poolSize: number | null;  // null => non-pooled; >= 1 => pooled
}

type TreesConfig = { projects: ProjectConfig[] };

const isPooled = (p: ProjectConfig): boolean => p.poolSize !== null;

// ── Worktree / slot types ─────────────────────────────────────────────────────
interface Worktree {
  path: string;
  head: string | null;
  branch: string | null;
  branchRef: string | null;
  detached: boolean;
  bare: boolean;
  canonical: boolean;
  pool: { index: number; placeholder: boolean } | null;
}

interface Slot {
  index: number;            // 1-based
  path: string;             // <root>__feat<N>
  exists: boolean;
  branch: string | null;
  placeholder: boolean;     // branch === `wk-pool/feat<N>`
  dirty: boolean;
  lastCommitIso: string | null;
  lastCommitSubject: string | null;
  initialized: boolean;     // marker file present in per-worktree git dir
}

interface PoolState {
  root: string;
  trunk: string;
  size: number;
  slots: Slot[];
}

type Allocation =
  | { kind: "free-slot"; slotIndex: number; branchExists: "local" | "remote" | "none" }
  | { kind: "pool-full"; candidateSlots: Slot[] }
  | { kind: "duplicate"; slotIndex: number; branch: string };

interface AddPlan {
  worktreePath: string;
  branch: string;
  root: string;
  title: string;
  runnerScriptPath: string | null;
  createdNewBranch: boolean;
}

interface RemovePlan {
  worktreePath: string;
  removed: boolean;   // true: fs entry gone; false: pool slot recycled in place
}

// Plans are serialized to --result-file as JSON with snake_case keys so nushell's
// `open | from json` produces idiomatic record field names without any custom transform.
// e.g. { worktree_path, runner_script_path, ... }
```

## Error types

All domain errors use `Data.TaggedError`. `catchTag` / `catchTags` provide exhaustive handling at call sites.

```ts
import { Data } from "effect";

class ConfigError extends Data.TaggedError("ConfigError")<{ message: string }> {}
class GitError extends Data.TaggedError("GitError")<{
  args: string[]; stderr: string; exitCode: number
}> {}
class DuplicateBranchError extends Data.TaggedError("DuplicateBranchError")<{
  branch: string; worktreePath: string
}> {}
class DirtySlotError extends Data.TaggedError("DirtySlotError")<{ slotPath: string }> {}
class UnmergedBranchError extends Data.TaggedError("UnmergedBranchError")<{ branch: string }> {}
class ReservedPrefixError extends Data.TaggedError("ReservedPrefixError")<{ branch: string }> {}
class CanonicalRootError extends Data.TaggedError("CanonicalRootError")<{ path: string }> {}
class PickerCancelled extends Data.TaggedError("PickerCancelled")<{}> {}
class HookError extends Data.TaggedError("HookError")<{ exitCode: number; slotPath: string }> {}
class TrunkDetectionError extends Data.TaggedError("TrunkDetectionError")<{}> {}
```

## Effect services (`shared/git/executor.ts` + `wktree.ts`)

Services replace the manual `Executors` bag. Each IO-touching concern is a `Context.Tag` with a live `Layer`. Tests substitute layers without touching production code.

### `shared/git/executor.ts`

```ts
import { Context, Effect, Layer } from "effect";

export interface GitResult { stdout: string; stderr: string; exitCode: number }

export class Git extends Context.Tag("Git")<Git, {
  // Fails with GitError when exit code is non-zero. Use for most git calls.
  run(args: string[], opts?: { cwd?: string }): Effect.Effect<GitResult, GitError>;
  // Always succeeds. Use when exit code itself is the signal (e.g. merge-base --is-ancestor).
  runRaw(args: string[], opts?: { cwd?: string }): Effect.Effect<GitResult, GitError>;
}>() {}

async function spawnGit(args: string[], cwd?: string): Promise<GitResult> {
  const proc = Bun.spawn(["git", ...args], {
    cwd,
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  return { stdout, stderr, exitCode: await proc.exited };
}

export const GitLive = Layer.succeed(Git, {
  run: (args, opts) =>
    Effect.tryPromise({
      try: () => spawnGit(args, opts?.cwd),
      catch: (e) => new GitError({ args, stderr: String(e), exitCode: -1 }),
    }).pipe(
      Effect.flatMap((result) =>
        result.exitCode === 0
          ? Effect.succeed(result)
          : Effect.fail(new GitError({ args, stderr: result.stderr, exitCode: result.exitCode }))
      )
    ),
  runRaw: (args, opts) =>
    Effect.tryPromise({
      try: () => spawnGit(args, opts?.cwd),
      catch: (e) => new GitError({ args, stderr: String(e), exitCode: -1 }),
    }),
});
```

### Services defined in `wktree.ts`

```ts
import { Context, Effect, Layer } from "effect";

// ── Hook service ──────────────────────────────────────────────────────────────
interface HookExecutor {
  runInline(
    scriptPath: string,
    cwd: string,
    env: Record<string, string>,
    onLine: (stream: "stdout" | "stderr", line: string) => void,
  ): Effect.Effect<void, HookError>;
}
class Hook extends Context.Tag("Hook")<Hook, HookExecutor>() {}

const HookLive = Layer.succeed(Hook, {
  runInline: (scriptPath, cwd, env, onLine) =>
    Effect.tryPromise({
      try: async () => { /* Bun.spawn bash scriptPath, stream lines via onLine */ },
      catch: (e) => new HookError({ exitCode: -1, slotPath: cwd }),
    }),
});

// ── Picker service ─────────────────────────────────────────────────────────────
interface PickerItem { key: string; display: string; preview: string }
interface PickerService {
  // attaches fzf to /dev/tty directly — never uses process.stdin/stdout
  pick(items: PickerItem[], header: string): Effect.Effect<PickerItem, PickerCancelled>;
  confirm(prompt: string): Effect.Effect<boolean, never>;
}
class Picker extends Context.Tag("Picker")<Picker, PickerService>() {}

const PickerLive = Layer.succeed(Picker, {
  pick: (items, header) => /* invoke shared/fzf.ts with header+preview on /dev/tty */,
  confirm: (prompt) => /* write prompt to /dev/tty, read y/N */,
});

// ── Progress service ──────────────────────────────────────────────────────────
interface ProgressService {
  banner(line: string): Effect.Effect<void>;
  stream(stream: "stdout" | "stderr", line: string): Effect.Effect<void>;
  error(msg: string): Effect.Effect<void>;
}
class Progress extends Context.Tag("Progress")<Progress, ProgressService>() {}

const ProgressLive = Layer.succeed(Progress, {
  banner: (line) => Effect.sync(() => process.stderr.write(`${line}\n`)),
  stream: (_, line) => Effect.sync(() => process.stderr.write(`  ${line}\n`)),
  error: (msg) => Effect.sync(() => process.stderr.write(`error: ${msg}\n`)),
});
```

## `shared/git/worktrees.ts` — pure parsers

No Effects, no services — pure functions that parse git porcelain output. Usable by any future tool.

```ts
// Parse `git worktree list --porcelain` output into Worktree[]
export function parseWorktreeList(output: string): Worktree[]

// Detect trunk from `git symbolic-ref refs/remotes/origin/HEAD`
// Falls back to parsing `git remote show origin`
export function parseTrunkFromSymbolicRef(stdout: string): string | null
export function parseTrunkFromRemoteShow(stdout: string): string | null

// Check if a branch name appears in local or remote branch list output
export function branchExistsInList(listOutput: string, branch: string): boolean
```

## CLI entry point

`main()` parses the subcommand, builds a single `program` Effect with all services provided, then hands off to `NodeRuntime.runMain` — which handles exit codes, uncaught errors, and signal teardown.

```ts
import { Effect, Layer } from "effect";
import { BunRuntime } from "@effect/platform-bun";

async function main() {
  const [, , subcommand, ...rest] = process.argv;
  const program = dispatch(subcommand, rest).pipe(
    Effect.provide(Layer.mergeAll(GitLive, HookLive, PickerLive, ProgressLive))
  );
  BunRuntime.runMain(program);
}

if (import.meta.main) {
  main();
}
```

> **Note:** `@effect/platform-bun` is added to dependencies for `BunRuntime.runMain`. This is the only `@effect/platform-*` package needed.

Exit code mapping via `Effect.mapError` at the dispatch boundary:

| Error tag | Exit code |
|---|---|
| `ConfigError` | 2 |
| `PickerCancelled` | 130 |
| any other failure | 1 (default) |

## Subcommand implementations (inside `wktree.ts`)

Each subcommand is an `Effect.Effect<..., ..., Git | Hook | Picker | Progress>`. Dependencies flow in via `yield* ServiceName` inside `Effect.gen`. There are no explicit parameter bags — Effect's context carries them.

Example shape for `ensure`:

```ts
const ensurePool = (root: string, config: ProjectConfig) =>
  Effect.gen(function* () {
    const git = yield* Git;
    const hook = yield* Hook;
    const progress = yield* Progress;

    const state = yield* buildPoolState(git, root, config);
    let didFetch = false;

    for (const slot of state.slots.filter(s => !s.initialized)) {
      yield* progress.banner(`[wk-pool] initializing feat${slot.index}…`);

      if (!didFetch) {
        yield* git.run(["-C", root, "fetch", "origin"]);
        didFetch = true;
      }

      // create placeholder branch if missing
      // git worktree add
      // generate runner script
      // hook.runInline — on failure: git worktree remove --force, re-throw HookError
      // write init marker
    }
  });
```

## Git commands

Unchanged from the original design — see the original `technical-design.md` git command inventory. Every call goes through the `Git` service; `yield* git.run([...], { cwd })` in `Effect.gen` blocks.

### Trunk + canonical root

```text
git -C <cwd> worktree list --porcelain
git symbolic-ref refs/remotes/origin/HEAD
git remote show origin   # fallback
```

### Branch existence

```text
git -C <root> branch --list --format=%(refname:short) <branch>
git -C <root> branch -r --list --format=%(refname:short) origin/<branch>
```

### Non-pool add

```text
git -C <root> fetch origin
# new branch:
git -C <root> worktree add --no-track -b <branch> <tree_dir> origin/<base-or-trunk>
# existing local:
git -C <root> worktree add <tree_dir> <branch>
# existing remote-only:
git -C <root> worktree add --no-track -b <branch> <tree_dir> origin/<branch>
# if origin/<branch> exists, after add:
git -C <tree_dir> merge --ff-only origin/<branch>
```

### Non-pool remove

```text
git -C <root> worktree remove [--force] <tree_dir>
git -C <root> branch -{d,D} <branch>
```

### Pool state inspection

```text
git -C <slot> status --porcelain=v1
git -C <slot> log -1 --format=%cI%x1f%s
git -C <slot> branch --show-current
```

### Pool materialise slot (`ensure`)

```text
git -C <root> fetch origin                                    # once total
git -C <root> branch --list --format=%(refname:short) wk-pool/feat<N>
git -C <root> branch wk-pool/feat<N> origin/<trunk>           # if missing
git -C <root> worktree add <slot_path> wk-pool/feat<N>
```

### Pool allocate into free slot

New branch:
```text
git -C <slot> checkout -B <branch> origin/<base-or-trunk>
```

Existing local (+ remote):
```text
git -C <slot> checkout <branch>
git -C <slot> merge --ff-only origin/<branch>   # warn on failure; preserve local work
```

Existing local-only:
```text
git -C <slot> checkout <branch>
```

Existing remote-only:
```text
git -C <slot> checkout -b <branch> origin/<branch>
```

### Pool recycle

Safe (default) — preflight BEFORE any mutation:
```text
git -C <root> fetch origin
git -C <slot> status --porcelain=v1                                  # dirty gate
if <old-branch> != wk-pool/feat<N>:
    git -C <root> rev-parse --verify <old-branch>@{upstream}         # must have upstream
    git -C <root> merge-base --is-ancestor <old-branch> <old-branch>@{upstream}
git -C <slot> checkout -B wk-pool/feat<N> origin/<trunk>
if <old-branch> != wk-pool/feat<N>:
    git -C <root> branch -d <old-branch>
```

Forced:
```text
git -C <root> fetch origin
git -C <slot> checkout -f -B wk-pool/feat<N> origin/<trunk>
git -C <slot> reset --hard wk-pool/feat<N>
if <old-branch> != wk-pool/feat<N>:
    git -C <root> branch -D <old-branch>
```

### Picker preview

```text
git -C <slot> log -5 --format=%h %s
git -C <slot> rev-list --count @{upstream}..HEAD   # ahead
git -C <slot> rev-list --count HEAD..@{upstream}   # behind
```

## Control flow per subcommand

Every subcommand resolves canonical root + config from `--cwd`; the binary never uses `process.cwd()`.

### `wktree add --cwd <c> --branch <b> --result-file <p> [--base <b>] [--force]`

```
parse config                              ConfigError → exit 2
resolve canonical root from --cwd
validate branch name (empty, wk-pool/ prefix)
if pooled:
  ensurePool (inline, streaming)          # fetches origin only when slots need init
  git fetch origin                        # always fetch before allocation so remote
                                          # branch existence and checkouts use current refs
  allocateSlot → free-slot checkout OR picker + recycle + checkout
  runner = project command body + pool marker
else:
  git fetch origin
  detect local / remote / new
  git worktree add …
  merge --ff-only origin/<b> if remote exists (warn on failure)
  runner = project command body (if project entry exists)
generateRunnerScript → ~/.config/kitty/sessions/<session>.runner.sh
write AddPlan JSON → --result-file (atomic: write + rename)
exit 0
```

Exit codes: `0` success, `2` config error, `130` picker cancelled, non-zero on other failure.

### `wktree remove --cwd <c> --result-file <p> (--branch <b> | --self <path>) [--force]`

```
parse config
resolve target path
refuse if target == canonical root     CanonicalRootError
if pool slot:
  recycleSlot()                        DirtySlotError / UnmergedBranchError without --force
  RemovePlan.removed = false
else:
  git worktree remove [--force] <path>
  git branch -{d,D} <branch>
  RemovePlan.removed = true
write RemovePlan → --result-file
```

### `wktree list --cwd <c> [--json]`

```
parse config (non-fatal on broken — emit warning, continue)
git worktree list --porcelain
annotate pool slots via branchRef + path pattern
emit human rows or JSON
```

### `wktree path --cwd <c> --branch <b>`

```
parse config
if pooled: find slot whose current branch == <b>; error if absent
else: derive <canonical-root>__<encoded-branch>; print
```

### `wktree root --cwd <c>`

Pure — `git worktree list --porcelain` → first path. Print.

### `wktree ensure --cwd <c>`

```
parse config
if non-pooled: exit 0 immediately
ensurePool (see above)
```

### `wktree recycle --cwd <c> --slot <path> [--force]`

Single-slot recycle; same sequences as §Pool recycle. Internal + exposed for manual use + tests.

### `wktree status --cwd <c>` (debug)

Parse config, build PoolState, emit JSON. Used by tests and manual inspection.

## Unified hook runner generation

`generateRunnerScript` is a pure function — given a hook spec and env, returns a bash script string.

Non-pooled shape:
```bash
#!/usr/bin/env bash
set -euo pipefail
export WK_ROOT='/abs/path/to/root'
export WK_CREATED='/abs/path/to/worktree'

echo 'project: deals-light-ui'
bash '/tmp/wktree-xxxx.hook.sh'
```

Pooled shape (marker appended):
```bash
#!/usr/bin/env bash
set -euo pipefail
export WK_ROOT='/abs/path/to/root'
export WK_CREATED='/abs/path/to/worktree'

echo 'project: deals-light-ui (pool)'
bash '/tmp/wktree-xxxx.hook.sh'
: > "$(git -C "$WK_CREATED" rev-parse --git-path wk-pool-initialized)"
```

Paths are shell-quoted via single-quote wrapping with `'\''` escapes. Snapshot-tested in `wktree.test.ts`.

## Half-init recovery

A slot is initialized iff the marker file at `$(git -C <slot> rev-parse --git-path wk-pool-initialized)` exists (inside the per-worktree git metadata directory — invisible to `git add` / `git clean` / `checkout -B`, cleaned up by `git worktree remove`).

The hook runner's last line (pool context only) creates the marker. Rollback on hook failure (`git worktree remove --force`) is the primary recovery path; the marker absence is the second line of defence for the rare case rollback itself is interrupted.

## Nushell integration

`helpers.nu` is deleted in full. `kitty.nu` loses `wk-post-create-runner` and `wk-run-post-create-runner`. `wk-open-dir` takes a `--runner-path` arg supplied by the binary.

### `mod.nu` after refactor

```nu
use kitty.nu *

def wktree-plan [args: list<string>] {
  let result_file = (mktemp)
  ^wktree ...($args ++ [--result-file $result_file])
  let exit = $env.LAST_EXIT_CODE
  if $exit != 0 {
    rm -f $result_file
    error make { msg: $"wktree failed (exit ($exit))" }
  }
  let plan = (open $result_file | from json)
  rm -f $result_file
  $plan
}

export def "wk root" [] { ^wktree root --cwd $env.PWD | str trim }

export def "wk path" [branch: string] { ^wktree path --cwd $env.PWD --branch $branch | str trim }

export def "wk list" [--json] {
  if $json { ^wktree list --cwd $env.PWD --json } else { ^wktree list --cwd $env.PWD }
}

export def --env "wk add" [branch: string, base?: string, --force] {
  let args = ([add --cwd $env.PWD --branch $branch]
    ++ (if $base  == null { [] } else { [--base  $base] })
    ++ (if $force         { [--force] } else { [] }))
  let plan = (wktree-plan $args)
  wk-open-dir $plan.worktree_path $plan.title $plan.root --runner-path ($plan.runner_script_path | default "")
}

export def --env "wk remove" [branch?: string, --self, --force] {
  let args = ([remove --cwd $env.PWD]
    ++ (if $self  { [--self $env.PWD] } else if $branch != null { [--branch $branch] } else { [] })
    ++ (if $force { [--force] } else { [] }))
  let plan = (wktree-plan $args)
  if ($env.PWD == $plan.worktree_path or ($env.PWD | str starts-with $"($plan.worktree_path)/")) {
    cd ~
  }
  wk-close-dir $plan.worktree_path
}
```

Key invariants:
- `wktree add` / `wktree remove` inherit stdin/stdout/stderr — fzf, prompts, and progress stream through.
- JSON plan is written to `--result-file`, not stdout, keeping the interactive channel clear.
- No `trees.toml` parse, git calls, or branch logic in nushell.
- Cwd changes (`cd ~`, `cd <path>`) stay in nushell — they require `--env` defs.

## TTY discipline

All mutating subcommands:
- Write the machine-readable plan to `--result-file` atomically (write temp + rename).
- Write progress banners and warnings to `stderr`.
- Open `/dev/tty` directly for fzf and confirm prompts.

If `/dev/tty` is unavailable and the picker would need to fire, the binary exits non-zero with a message directing the user to `--force --slot=<path>` (non-interactive path; not v1).

## Testing strategy

One test file: `oven/tests/wktree.test.ts`. No separate unit test files per module.

### Approach

Tests use **real git repos** created in `mkdtemp` within `/tmp`. This gives accurate coverage of git behaviour without mocking porcelain output. The two IO-touching services that are impractical to use in tests (`Hook`, `Picker`) are substituted via Effect Layers.

For pure functions (`parseWorktreeList`, `parseTrunkFromSymbolicRef`, `generateRunnerScript`, `parseConfig`) — test them directly in the same file; they take plain inputs and return plain outputs.

### Layer substitution

```ts
// Scripted hook — writes a sentinel file instead of running yarn
const TestHook = (sentinel: string) =>
  Layer.succeed(Hook, {
    runInline: (_, cwd) =>
      Effect.tryPromise({
        try: () => Bun.write(`${cwd}/${sentinel}`, ""),
        catch: (e) => new HookError({ exitCode: 1, slotPath: cwd }),
      }),
  });

// Scripted picker — returns pre-determined item or null
const TestPicker = (choice: PickerItem | null) =>
  Layer.succeed(Picker, {
    pick: () =>
      choice === null ? Effect.fail(new PickerCancelled()) : Effect.succeed(choice),
    confirm: () => Effect.succeed(true),
  });

// Strict git layer for unit-style assertions (rejects unexpected calls)
const StrictGit = (responses: Map<string, GitResult>) =>
  Layer.succeed(Git, {
    run: (args) => {
      const key = args.join(" ");
      const result = responses.get(key);
      if (!result)
        return Effect.fail(new GitError({ args, stderr: `unexpected git call: ${key}`, exitCode: 1 }));
      return Effect.succeed(result);
    },
  });
```

### Helper

```ts
function runWith<A, E>(
  effect: Effect.Effect<A, E, Git | Hook | Picker | Progress>,
  overrides: { git?: Layer.Layer<Git>; hook?: Layer.Layer<Hook>; picker?: Layer.Layer<Picker> }
): Promise<A> {
  return Effect.runPromise(
    effect.pipe(
      Effect.provide(
        Layer.mergeAll(
          overrides.git    ?? GitLive,
          overrides.hook   ?? HookLive,
          overrides.picker ?? PickerLive,
          ProgressLive,       // always live — stdout is fine in tests
        )
      )
    )
  );
}
```

### Coverage

**Pure function tests** (no services needed):

- `parseConfig`: valid pooled, valid non-pooled, mixed, missing `root`/`command`, bad `pool_size` (0, negative, non-integer), duplicate `root`, legacy `[[post_create]]` rejected with migration hint, `shell` field rejected, unknown fields ignored.
- `parseWorktreeList` / `parseTrunkFromSymbolicRef` / `parseTrunkFromRemoteShow`: porcelain fixture strings — canonical root, detached HEAD, pool slots.
- `generateRunnerScript`: snapshot both shapes (pooled / non-pooled); shell-quoting with spaces and single quotes.

**Integration tests** (real git in `/tmp`):

Each test creates a bare origin + local clone via `Bun.spawn("git", ...)`. Real `wktree` subcommands execute against it, with `TestHook` and `TestPicker` layers substituted.

Non-pool coverage:
- `add` new branch, existing local, existing remote-only, existing local with diverged remote (warning, no error).
- `add` on a non-pooled `[[project]]` entry runs its `command` with correct `WK_ROOT` / `WK_CREATED`.
- `add` on a repo with no matching `[[project]]` → `runnerScriptPath: null` in plan.
- `remove` safe + `--force`; branch + worktree gone; canonical root refused.

Pool coverage:
- `ensure` against empty repo: N slots created with correct placeholders; hook runs with cwd=slot; sentinel file present.
- `ensure` with hook failing on slot 3: slots 1-2 remain, slot 3 rolled back, slots 4-5 untouched; re-run recovers.
- `ensure` with half-init state (worktree present, marker absent): re-runs hook.
- Allocate + remove (recycle) round trip: allocate branch, recycle via remove, allocate same name again succeeds.
- Duplicate across worktrees: branch in canonical root → `add` errors without side effects.
- Duplicate across pool: branch in feat2 → `add` errors without side effects.
- Reserved namespace: `add --branch wk-pool/mine` → errors.
- Dirty gate: tracked modification → recycle without `--force` fails; with `--force` succeeds AND dirt gone.
- Dirty gate: untracked non-gitignored file → recycle without `--force` fails; with `--force` succeeds, file survives.
- Dirty gate: gitignored path (`node_modules/`) → NOT reported, gate not triggered, survives recycle in both modes.
- Safe branch delete: unmerged commits without `--force` → `branch -d` fails; with `--force` → `branch -D` succeeds.
- `--base` handling: new branch from `origin/<base>`; existing branch + `--base` emits warning, ignores base.
- Trunk auto-detect against a repo whose default branch is `develop`.
- Picker flow: pool full → TestPicker returns slot → recycle + checkout succeeds.
- Picker cancel: pool full → TestPicker returns null → exit 130, no side effects.

### Opt-out

`WKTREE_SKIP_INTEGRATION=1` skips the git-in-tmp tests for fast iteration. `bun run verify` always runs them.

## `shared/fzf.ts` extension

Extend the existing helper to add `header` and `preview` options (used by the picker), rather than building a parallel wrapper in `wktree.ts`.

```ts
interface FzfOptions {
  multi?: boolean;
  tmux?: boolean;
  header?: string;
  preview?: string;   // shell command string; %s substituted with the selected line
}
```

The picker's `/dev/tty` discipline is handled at the `fzf` call site by passing `--tty` to the fzf invocation.

## Migration checklist

- Delete `config/nushell/scripts/ct/git/worktree/helpers.nu` in full.
- In `kitty.nu`: delete `wk-post-create-runner`, `wk-run-post-create-runner`; update `wk-open-dir` to take `--runner-path`.
- In `mod.nu`: remove `use helpers.nu *`; rewrite `wk add` / `wk remove` / `wk list` / `wk path` / `wk root` to the shapes above.
- Grep for `wk-canonical-root`, `wk-worktree-path`, `wk-encode-branch`, `wk-default-branch`, `wk-list-data`, `wk-post-create-hooks`, `wk-matching-post-create-hooks`, `wk-post-create-runner` before deletion; migrate any external caller to `wktree` subcommand invocations.
- Update `specs/git-worktrees.md` to reflect the layer split.
- Add `effect` and `@effect/platform-bun` to `oven/package.json`.
