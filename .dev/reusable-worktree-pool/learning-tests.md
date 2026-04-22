# Learning tests — reusable worktree pool

Ran against throwaway repo in `/tmp/wk-lt` with bare origin + main clone + one slot.

## LT1 — placeholder-branch worktree

```bash
git branch wk-pool/feat1 origin/main
git worktree add ../repo__feat1 wk-pool/feat1
```

Works. Slot reports `branch refs/heads/wk-pool/feat1` in `git worktree list --porcelain`.

## LT2 — same branch in two worktrees

```bash
git worktree add ../repo__feat2 wk-pool/feat1
# fatal: 'wk-pool/feat1' is already used by worktree at '…/repo__feat1'
```

Implication: when allocating a feature branch that already exists locally, if it's already in a slot, we must error (matches duplicate rule). To reuse the same branch in a different slot, we'd first `git worktree remove` the source — out of scope.

## LT3 — checkout -B over placeholder

```bash
cd ../repo__feat1   # on wk-pool/feat1
git checkout -B my-feature origin/main
# Switched to a new branch 'my-feature'
```

Slot HEAD now on `my-feature`. Placeholder branch `wk-pool/feat1` persists at its previous commit — NOT automatically fast-forwarded to origin.

## LT4 — recycle sequence

From slot on `my-feature` with work committed, trunk advanced since:

```bash
git -C repo fetch -q origin
git -C repo__feat1 checkout -B wk-pool/feat1 origin/main
git -C repo__feat1 branch -D my-feature
```

Result:
- slot HEAD is on `wk-pool/feat1` at latest `origin/main`
- `my-feature` branch deleted
- tracked files from `my-feature` (e.g. `work.txt`) are gone from working tree

## LT5 — porcelain detection

`git worktree list --porcelain` returns blocks with `branch refs/heads/<name>`. Slot detection rule: `branch_ref` starts with `refs/heads/wk-pool/`.

## LT6 — dirty detection

```bash
git -C <slot> status --porcelain
```

Any non-empty line = dirty (tracked modifications OR untracked). For the dirty-gate in recycle we should probably only block on tracked changes (`git status --porcelain=v1 | grep -v '^??'`) — node_modules is untracked (gitignored) and that's fine.

## LT7 — node_modules survives checkout -B

**Core assumption of the feature.** Verified:

1. Slot on `wk-pool/feat1`, create `node_modules/pkg/package.json` (untracked, gitignored).
2. `git checkout -B my-feature origin/main` — `node_modules/` intact.
3. Simulate user work, then recycle: `git checkout -B wk-pool/feat1 origin/main` + `git branch -D my-feature` — `node_modules/` still intact.

Git never touches untracked/ignored files during `checkout -B`. Hot-cache premise holds.

## LT8 — picker metadata

Cheap sources per slot:
- branch: `git -C <slot> branch --show-current`
- last commit: `git -C <slot> log -1 --format='%cI %s'`
- dirty: `git -C <slot> status --porcelain`
- dir mtime: `stat` on slot path
- reflog (optional): `git -C <slot> reflog --format='%gD %gs' HEAD`

## LT10 — checkout -B with dirty tracked files

```bash
cd <slot>; echo X > <tracked-file>   # modify
git checkout -B wk-pool/feat1 origin/main   # SUCCEEDS, carries modification
```

Foot-gun. Recycle MUST check dirty (tracked) before `checkout -B`. With `--force`, git throws the change away cleanly.

## Derived rules for implementation

1. Recycle sequence (in this order):
   - `git -C <repo> fetch origin`
   - If slot is dirty (tracked) → abort unless `--force`
   - `git -C <slot> checkout -B wk-pool/featN origin/<trunk>`
   - `git -C <repo> branch -D <old-feature>` (if old was not a placeholder)
2. Allocation sequence:
   - Find slot on a `wk-pool/featN` placeholder
   - `git -C <slot> checkout -B <user-branch> origin/<trunk>` (new) or `git -C <slot> checkout <user-branch>` (existing)
   - Run hook with `WK_ROOT` + `WK_CREATED`
3. Detection: worktree is a pool slot iff its branch starts with `wk-pool/feat`. Slot index from the numeric suffix.
