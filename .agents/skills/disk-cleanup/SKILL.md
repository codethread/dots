---
name: disk-cleanup
description: Reclaim workstation disk space by inspecting development checkouts, generated builds, dependency installs, XDG caches/state, old Rust and Node tooling, and container images. Use when asked to inspect developer disk usage, tidy a nearly full disk, remove regenerable developer data, or review cleanup candidates. A space-usage report alone does not authorize deletion.
---

# Developer workstation cleanup

Reclaim measurable space without losing source, durable application data, or working tools. Discover this machine's layout and active projects; do not reuse a previous machine's versions, paths, sizes, or deletion inventory.

## Establish scope and measure

1. Confirm the user's authorization: inspection only, regenerable cleanup, or explicitly approved source/data removal. Protect the current checkout by default and treat named active projects as exclusions, including their dependencies, builds, nested worktrees and symlink targets. Discover additional active projects; ask before ambiguous project deletion. Resolve ambiguous paths against the actual filesystem rather than guessing.
2. For cleanup execution, load the repository's [Hive skill](../hive/SKILL.md) for tracking. Reuse or create a cleanup bead and a child for uncertain candidates needing user decisions. A read-only space-usage question needs no bookkeeping task. Do not turn uncertain candidates into deletions merely to finish the parent.
3. Record filesystem free space with `df -h` and inventory existing roots with `du` or `dust`. Inspect `~/dev/vendor`, `~/dev/projects`, and the current checkout without assuming every machine has them.
4. Resolve `${XDG_CACHE_HOME:-$HOME/.cache}`, `${XDG_STATE_HOME:-$HOME/.local/state}` and `${XDG_DATA_HOME:-$HOME/.local/share}`. Also inspect existing `~/.local/cache`, `~/.local/state`, `~/.local/share`, `~/.bun/install/cache` and platform-native developer caches when distinct. Discover tool homes/configuration rather than assuming default locations.
5. Check running processes, services, executable symlink targets and tool versions. A project omitted from the user's active list may still host a running service: preserve its dependencies and flag it. Record container daemon/VM state before any lifecycle change.

Measure overlapping directory roots separately: some `du` implementations suppress repeat counting in one invocation. Use filesystem free-space change for the reclaimed total, not summed logical sizes; hardlinks, APFS clones, sparse VM disks and snapshots make those differ.

## Classify before deleting

```text
Explicitly authorized and outside protected scope?
  no  -> inspect/report only
  yes -> Proven disposable or reproducible, with no live dependency?
           yes -> remove bounded paths, then verify
           no  -> retain; record exact approval needed
```

### Development checkouts

- Search inactive repositories for `node_modules`, Rust `target`, virtual environments, compiler/LSP caches and framework outputs such as `.next`, `dist` or `.build`. Prune traversal at protected roots, symlinks, `.git` and managed worktree directories; inspect worktrees separately only when explicitly in scope.
- Names are not proof: repositories can track fixtures called `target` or `node_modules`. For each candidate, identify its owning repository, check `git ls-files -- <relative-path>` and `git check-ignore`, and inspect build/configuration ownership. Remove only understood generated content with no tracked source. Preserve unexplained or locally customized content for review.
- For version-pinned vendor clones (often `name@version`), require a clean checkout including untracked/ignored content, a known origin and recoverable pinned revision. Inspect local branches/tags, stashes and worktree registrations; preserve unique local work. A clean working tree alone does not prove every local ref is published. Use Honeycomb instructions for managed worktree operations, not raw directory deletion.
- Whole unversioned source clones and personal forks are a separate approval decision. Do not broaden permission to remove build outputs into permission to delete source checkouts.

### Caches and installed tooling

Read installed command help before choosing flags; package-manager behavior and storage layouts vary by version.

- **Node/Bun/pnpm:** distinguish download/transpilation caches from installed packages, global tools and shared link farms. Prefer native cache/prune commands where they respect registered project usage. Old store generations and failed temporary installs can be removed once unreferenced; preserve stores that supply live symlink targets. Hardlinked installed files survive unlinking cache entries, but symlink-backed installs may not. Inspect before treating any store as disposable.
- **Rust:** discover `CARGO_HOME` and `RUSTUP_HOME`; use `rustup show`, override/configuration inspection and project `rust-toolchain*` files to identify required toolchains. Remove obsolete, inactive toolchains/components through rustup, not by deleting its internal trees. Offline documentation is an optional removable component; keep required compilers/targets. Downloaded registry sources/crates are caches unless locally edited or linked into active work; leave installed binaries and receipts alone. Rebuilding an inactive project may require reinstalling its pinned toolchain.
- **Other tools:** separate mise downloads/Homebrew bottles, uv/pip caches, Go build caches, Nix download/evaluation caches and Clojure/LSP caches from actual tool installations, environments, package stores and configuration. Do not use tool upgrades, bootstrap, broad uninstall or system garbage collection as a substitute for bounded cache cleanup.
- **Old executable versions:** preserve the current executable and every version referenced by symlinks, configuration or running processes. Remove only verified superseded versions. Smoke-check the retained executable afterward; run checks outside unrelated package-manager-enforced workspaces when needed.

### State is not a cache

Inspect the owning project's README and targeted source when a large state tree is unfamiliar. Delegate bounded read-only lookups through Bee when useful; a failed delegate does not justify guessing.

- Keep databases, task graphs, queues, recovery directories, migration/cutover snapshots, rollback copies, transcripts and editor undo unless explicitly approved for removal. Runtime-looking directories can contain the only durable data.
- Millstrand-like systems illustrate the distinction: content-addressed fetched spool sources can be caches, while per-workspace weaver directories can contain durable SQLite graphs. Confirm the installed/source version's lifecycle; do not generalize from a directory name or an older implementation.
- Old diagnostic logs can be trimmed after confirming their role, age and lack of open writers. Prefer bounded recent tails when useful. Retain complete records for JSONL and preserve permissions; exclude files belonging to protected active systems unless their log cleanup is in scope. Do not delete entire state trees to clear logs.
- For high-risk adjacent data, record database files/hashes before and after bounded cleanup when they are quiescent. Do not stop an active database just to obtain a matching hash; use read-only native evidence or retain it.

### Containers and VM disks

- Discover Docker/Podman availability, contexts/connections and machines. Inspect images/build caches, **all** containers (including stopped ones) and volumes in relevant storage contexts; rootless/rootful stores may differ.
- Prune only unused images/build data proven pullable or rebuildable. Tagged/local-only images may contain unique work. Do not remove stopped containers, volumes, whole VMs or VM disk files without separate approval.
- Starting a stopped daemon/VM can auto-start workloads: obtain authorization for that lifecycle change when needed and restore its original state. Do not start it solely to obtain better numbers if that exceeds scope.
- Removing images may free only guest space. If supported and authorized, use the guest's native trim/reclaim facility to return sparse disk allocation to the host; verify host free space afterward. Do not zero-fill a disk on a nearly full host.

## Execute, verify and hand off

- Use an explicit, bounded candidate inventory: canonical path, size, classification and evidence. Recheck protection, source status and live references immediately before removal. Do not execute a previous session's broad cleanup script or `git clean -fdx` across repository roots.
- Keep a deletion/trim log outside paths being cleaned. Record relevant tracked-source status before/after; verify protected dependencies, retained executables, services and databases. Source edits already present belong to the user, not this cleanup.
- Verify removed clones, stores and obsolete versions are absent. Small freshly recreated caches are expected; verify their current size and purpose instead of repeatedly deleting them to force absence. Check retained JSONL tails parse and preserve original file permissions.
- Re-measure `df` and the major roots. Report actual free-space change, the largest cleanup categories and anything that will need downloading/rebuilding next time. No project test suite is needed solely to delete proven caches; use focused tool/runtime checks instead.
- In the uncertainty child, list exact remaining paths, sizes, why deletion might be safe, what could be lost and the approval needed. Keep it unassigned unless instructed otherwise. Separate candidate approval from a fresh live-reference/local-work audit before any later deletion.
- Close completed execution work with evidence. Keep review work open for user decisions; do not claim the whole task is closed while its review child remains open. Follow repository policy for local tracker updates/publication; cleanup permission is not permission to commit or push.
