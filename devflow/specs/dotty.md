# Dotty Specification

Document ID: SPEC-003
Configuration identification: SPEC-003; migrated from `specs/dotty.md`; canonical path `devflow/specs/dotty.md`.
**Status:** Implemented
**Last Updated:** 2026-04-04

## [SPEC-003-S1] 1. Overview

### [SPEC-003-S1.1] Purpose

General-purpose dotfile symlink manager written in Nushell. Takes a TOML configuration declaring source-to-target directory mappings and creates symlinks for every file within each mapping. Supports incremental caching for fast re-runs, git-ignore-aware file enumeration, and force-gated conflict resolution.

### [SPEC-003-S1.2] Goals

- Declarative symlink management via a single TOML config
- Incremental linking via per-project caches (only process changes)
- Git-ignore-aware file enumeration (never link ignored files)
- Safe conflict resolution: detect duplicate targets across projects, require `--force` before overwriting real files
- Editor integration: auto-link on save, project detection, formatted output for UI
- Zero external dependencies beyond Nushell, git, and coreutils

### [SPEC-003-S1.3] Non-Goals

- Managing application-specific config generation (that's each tool's concern; e.g. `claude-code.nix` generates `settings.json`)
- Package installation or system configuration (that's Nix)
- Text template rendering or variable substitution in linked files
- Structured formats other than TOML (the merge architecture may add formats later)

## [SPEC-003-S2] 2. Architecture

### [SPEC-003-S2.1] Component Layout

```
config/dotty/
    dotty.toml              Configuration (project mappings, global excludes)
    test-dotty.toml         Test configuration

config/nushell/scripts/ct/dotty/
    mod.nu                  Main module: link, prune, teardown, chmod, format, is-cwd, test
    config.nu               TOML loader, validator, path expander
    cache.nu                Per-project cache (load/store/delete)
    helpers.nu              Conflict detection, path overlap validation
    list-files.nu           File enumeration with git-ignore filtering
    template.nu             Three-way TOML merge and template cache
```

### [SPEC-003-S2.2] Linking Algorithm (`dotty link`)

```
1. Load config    ──→ config.nu: parse TOML, validate, expand paths, filter to existing origins
2. Discover files ──→ For each project (parallel):
   │                    ├─ File mode:      list-files.nu enumerates files, diff against cache
   │                    └─ Directory mode:  check if "." entry exists in cache
   │
3. Detect conflicts ──→ helpers.nu:
   │                    ├─ Duplicate targets across projects → hard error
   │                    ├─ Existing real files at target paths → prompt or auto-remove
   │                    └─ Path overlaps (directory vs file project targets) → hard error
   │
4. Execute (parallel per-project):
   │  ├─ Delete removed files (files in cache but no longer in project)
   │  ├─ Create parent directories
   │  ├─ Create symlinks (ln -sf)
   │  └─ Update cache
   │
5. Return change report (new links created, files removed)
```

### [SPEC-003-S2.3] File Enumeration Strategies

Two strategies in `list-files.nu`, selected by cache state:

| Strategy | Trigger | Method | Rationale |
|---|---|---|---|
| Fresh | Cache empty (first run) | `git ls-files` | Respects gitignore natively, fast on large repos |
| Incremental | Cache populated | `glob **/*` then `git check-ignore --stdin` | Catches untracked files that should be linked |

Both strategies apply project + global exclude patterns after enumeration.

### [SPEC-003-S2.4] Conflict Detection

Two conflict classes are actively enforced by `helpers.nu`:

1. **Duplicate targets** — multiple projects map files to the same target path. Hard error, no override.
2. **Existing real files** — a non-symlink file already exists at a target path. Hard error unless `--force` is passed.

Existing symlinks at target paths are not conflicts — they're silently overwritten.

## [SPEC-003-S3] 3. Data Model

### [SPEC-003-S3.1] Configuration Schema (`dotty.toml`)

```toml
[global]
excludes = ["glob_pattern", ...]          # Optional. Applied to all file-mode projects.

[[project]]
name = "string"                           # Required. Unique across all projects.
origin = "~/path/to/source"               # Required. Supports `~` and `${ENV}` expansion. Must exist at load time (projects with missing origins silently skipped).
target = "~/path/to/destination"          # Required. Supports `~` and `${ENV}` expansion. Expanded without following symlinks.
excludes = ["glob_pattern", ...]          # Optional. Combined with global excludes.
```

Templates merge repository-owned values into machine-local structured files:

```toml
[[template]]
name = "codex"
origin = "${DOTFILES}/templates/codex-config.toml"
target = "~/.config/codex/config.toml"
array_identity = { "skills.config" = "path" }
```

A template cache stores the previous parsed source and synchronized target under
`~/.local/data/dotty-templates/<name>.toml`. The previous source defines the
VCS-owned subset. Target edits to owned paths sync back into the source; direct
source edits sync forward into the target. Target-only paths and record-array
identities remain machine-local. Scalar arrays synchronize as ordered values;
record arrays require an explicit dotted-path identity. Dotty collects divergent
edits and reports all conflicting paths without changing source, target, or cache.

### [SPEC-003-S3.2] Current Projects

| Name | Origin | Target | Project-Specific Excludes |
|---|---|---|---|
| home | `${DOTFILES}/home` | `~` | — |
| config | `${DOTFILES}/config` | `~/.config` | — |
| claude | `${DOTFILES}/claude` | `~/.claude` | `**/settings.json`, `**/settings.local.json` |
| pi | `${DOTFILES}/pi` | `~/.pi/agent` | — |
| work | `~/work/me/workfiles/home` | `~` | — |
| deals | `~/work/me/workfiles/work/app/deals-light-ui/_git` | `~/work/app/deals-light-ui/.git` | — |

Global excludes: `**/_?*/**` (underscore-prefixed), `**/.gitignore`, `**/README.md`

### [SPEC-003-S3.3] Cache Format

- **Location:** `~/.local/data/dotty-cache-<project-name>.nuon`
- **Format:** NUON (Nushell Object Notation) — a sorted list of relative file paths
- **Special entry:** `"."` indicates a directory-mode project

### [SPEC-003-S3.4] Config Resolution

`config.nu` resolves the config path via: `$env.XDG_CONFIG_HOME` (if set) or `~/.config`, then appends `dotty/dotty.toml`. An explicit path argument overrides this (used by Makefile for worktree support).

## [SPEC-003-S4] 4. Interfaces

### [SPEC-003-S4.1] CLI Commands

| Command | Purpose |
|---|---|
| `dotty link [--no-cache] [--force] [config_path]` | Create/update symlinks, then bidirectionally synchronize owned TOML template paths. `--no-cache` applies to symlink discovery; template caches are always used for merge safety. |
| `dotty format` | Format link output for editor integration (pipe: `dotty link \| dotty format`) |
| `dotty is-cwd [dir] [--exit]` | Check if directory is a dotty project. `--exit` returns exit code instead of bool. |
| `dotty prune [target]` | Remove broken symlinks under target (default: `~/.config/**/*`) |
| `dotty teardown` | Remove all dotty-managed symlinks and caches |

### [SPEC-003-S4.2] Integration Points

| System | Command | When | Notes |
|---|---|---|---|
| **Makefile** (`make link`) | `DOTFILES=$(ROOT) dotty link --no-cache <repo>/config/dotty/dotty.toml` | Manual rebuild | Exports `DOTFILES` as the current checkout root for worktree support |
| **Nix activation** (`dottyLink`) | `dotty link --no-cache` | Every `*-rebuild switch` | Runs after `userBootstrap` phase. Exports `DOTFILES`, `XDG_*` vars. Explicit `PATH` with git, coreutils, findutils, gnugrep, gnused, nushell, bash. Skips gracefully if `$DOTFILES` directory missing. |
| **Neovim** | `dotty link`, `dotty format`, `dotty is-cwd` | Editor events | Auto-links on `BufWritePost`/`BufFilePost`/`VimLeavePre`. Detects dotfiles project via `is-cwd` on git root. |

### [SPEC-003-S4.3] Worktree / Feature-Branch Support

The Makefile `link` target enables testing dotty from any checkout:

1. `dotty.toml` uses `${DOTFILES}` for repo-local project origins
2. The Makefile exports `DOTFILES=$(ROOT)` before invoking Nushell
3. `dotty link --no-cache` receives the checkout's tracked `config/dotty/dotty.toml` directly

The Nix activation hook exports `DOTFILES` as `$HOME/dev/dots` (the canonical clone path).

## [SPEC-003-S5] 5. Design Decisions

- **Nushell, not a compiled binary** — dotty is a Nushell module, not a standalone tool. This eliminates build steps, enables REPL debugging, and leverages Nushell's structured data (tables, records) for the linking pipeline. Tradeoff: requires Nushell runtime on PATH.

- **TOML over ad hoc conventions** — configuration is explicit rather than convention-based (e.g. "everything in `config/` maps to `~/.config`"). This supports non-obvious mappings like `claude/ → ~/.claude` and `pi/ → ~/.pi/agent`.

- **Per-project caches** — each project gets its own cache file rather than a single global cache. This allows independent invalidation and makes directory-mode transitions clean (file entries are replaced by a single `"."` entry).

- **`--no-cache` as default for automation** — all non-interactive invocations (Makefile and Nix activation) use `--no-cache`. Only the Neovim integration uses cached mode for speed. This ensures automation is always correct at the cost of re-scanning.

- **git-ignore awareness** — dotty uses git's own ignore machinery (`git ls-files`, `git check-ignore`) rather than reimplementing glob exclusion. Files that git ignores are never linked, preventing accidental exposure of build artifacts or secrets.

- **Force-gated conflict resolution** — when a real file exists at a target path, dotty fails loudly unless `--force` is passed.

## [SPEC-003-S6] 6. Testing

### [SPEC-003-S6.1] Automated

- **Test config** — `config/dotty/test-dotty.toml` provides a sandboxed project (`${DOTFILES}/config/dotty` → `~/dotty-test`) for validation without touching real dotfiles.

### [SPEC-003-S6.2] Manual

- **`nix-smoke`** — verifies config symlinks are valid (checks that expected symlinks in `~/.config` point to real files).
- **`dotty prune`** — finds and removes broken symlinks (useful after file deletions).

## [SPEC-003-S7] 7. Open Questions

- The `deals` project links a `_git` directory as individual files to `.git` — fragile if git internals change structure
- `work` and `home` projects both target `~` — relies on non-overlapping file trees with no enforcement beyond duplicate-target detection
