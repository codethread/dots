# Dotty Specification

**Status:** Implemented
**Last Updated:** 2026-04-04

## 1. Overview

### Purpose

General-purpose dotfile symlink manager written in Nushell. Takes a TOML configuration declaring source-to-target directory mappings and creates symlinks for every file within each mapping. Supports two linking modes (file-level and directory-level), incremental caching for fast re-runs, git-ignore-aware file enumeration, and interactive conflict resolution.

### Goals

- Declarative symlink management via a single TOML config
- Incremental linking via per-project caches (only process changes)
- Two linking modes: per-file symlinks (default) and whole-directory symlinks
- Git-ignore-aware file enumeration (never link ignored files)
- Safe conflict resolution: detect duplicate targets across projects, prompt before overwriting real files
- Editor integration: auto-link on save, project detection, formatted output for UI
- Zero external dependencies beyond Nushell, git, and coreutils

### Non-Goals

- Managing application-specific config generation (that's each tool's concern; e.g. `claude-code.nix` generates `settings.json`)
- Package installation or system configuration (that's Nix)
- Template rendering or variable substitution in linked files (files are symlinked as-is)
- Cross-machine config variation (handled at the Nix profile layer, not dotty)

## 2. Architecture

### Component Layout

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
```

### Linking Algorithm (`dotty link`)

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

### File Enumeration Strategies

Two strategies in `list-files.nu`, selected by cache state:

| Strategy | Trigger | Method | Rationale |
|---|---|---|---|
| Fresh | Cache empty (first run) | `git ls-files` | Respects gitignore natively, fast on large repos |
| Incremental | Cache populated | `glob **/*` then `git check-ignore --stdin` | Catches untracked files that should be linked |

Both strategies apply project + global exclude patterns after enumeration.

### Linking Modes

| Aspect | File mode (default) | Directory mode (`link_directory = true`) |
|---|---|---|
| Symlink granularity | One symlink per file | One symlink for entire directory |
| Cache entry | Relative file paths | Special `"."` marker |
| Excludes | Supported (global + project) | Ignored (warning printed) |
| Conflict on existing target | Per-file check | Removes existing target directory entirely |
| Teardown | Removes individual symlinks + empty parent dirs | Removes directory symlink only |

### Conflict Detection

Two conflict classes are actively enforced by `helpers.nu`:

1. **Duplicate targets** — multiple projects map files to the same target path. Hard error, no override.
2. **Existing real files** — a non-symlink file already exists at a target path. Interactive: prompts user. Non-interactive (hooks/CI): auto-removes.

A third class — **path overlaps** (parent/child target conflicts between `link_directory` and file-mode projects) — is implemented in `helpers.nu` (`detect-path-overlaps`) but the call is currently commented out in `mod.nu`.

Existing symlinks at target paths are not conflicts — they're silently overwritten.

## 3. Data Model

### Configuration Schema (`dotty.toml`)

```toml
[global]
excludes = ["glob_pattern", ...]          # Optional. Applied to all file-mode projects.

[[project]]
name = "string"                           # Required. Unique across all projects.
origin = "~/path/to/source"               # Required. Must exist at load time (projects with missing origins silently skipped).
target = "~/path/to/destination"          # Required. Expanded without following symlinks.
excludes = ["glob_pattern", ...]          # Optional. Combined with global excludes. Ignored when link_directory=true.
link_directory = false                    # Optional. Default: false.
```

### Current Projects

| Name | Origin | Target | Mode | Project-Specific Excludes |
|---|---|---|---|---|
| home | `~/PersonalConfigs/home` | `~` | file | — |
| config | `~/PersonalConfigs/config` | `~/.config` | file | — |
| claude | `~/PersonalConfigs/claude` | `~/.claude` | file | `**/settings.json`, `**/settings.local.json` |
| pi | `~/PersonalConfigs/pi` | `~/.pi/agent` | file | — |
| work | `~/workfiles/home` | `~` | file | — |
| deals | `~/workfiles/work/app/deals-light-ui/_git` | `~/work/app/deals-light-ui/.git` | file | — |

Global excludes: `**/_?*/**` (underscore-prefixed), `**/.gitignore`, `**/README.md`

### Cache Format

- **Location:** `~/.local/data/dotty-cache-<project-name>.nuon`
- **Format:** NUON (Nushell Object Notation) — a sorted list of relative file paths
- **Special entry:** `"."` indicates a directory-mode project

### Config Resolution

`config.nu` resolves the config path via: `$env.XDG_CONFIG_HOME` (if set) or `~/.config`, then appends `dotty/dotty.toml`. An explicit path argument overrides this (used by Makefile for worktree support).

## 4. Interfaces

### CLI Commands

| Command | Purpose |
|---|---|
| `dotty link [--no-cache] [config_path]` | Create/update symlinks. `--no-cache` forces full re-sync. Optional config path overrides default. |
| `dotty format` | Format link output for editor integration (pipe: `dotty link \| dotty format`) |
| `dotty is-cwd [dir] [--exit]` | Check if directory is a dotty project. `--exit` returns exit code instead of bool. |
| `dotty test ...files` | Test whether specific files are managed by a dotty project |
| `dotty prune [target]` | Remove broken symlinks under target (default: `~/.config/**/*`) |
| `dotty teardown` | Remove all dotty-managed symlinks and caches |
| `dotty chmod` | Make all files in `~/.local/bin` executable |

### Integration Points

| System | Command | When | Notes |
|---|---|---|---|
| **Makefile** (`make link`) | `dotty link --no-cache` | Manual rebuild | Creates temp TOML with `sed` path substitution (`~/PersonalConfigs` → current checkout root) for worktree support |
| **Nix activation** (`dottyLink`) | `dotty link --no-cache` | Every `*-rebuild switch` | Runs after `userBootstrap` phase. Exports `DOTFILES`, `XDG_*` vars. Explicit `PATH` with git, coreutils, findutils, gnugrep, gnused, nushell, bash. Skips gracefully if `$DOTFILES` directory missing. |
| **Neovim** | `dotty link`, `dotty format`, `dotty chmod`, `dotty is-cwd`, `dotty test` | Editor events | Auto-links on `BufWritePost`/`BufFilePost`/`VimLeavePre`. Detects dotfiles project via `is-cwd` on git root. Runs `chmod` after every link. |
| **cc-sandbox** | `dotty link --no-cache` | Container image build | Step 3 of PersonalConfigs integration: after `git init`, before `bun run build` |
| **boot.zsh** (legacy) | `dotty setup` | macOS bootstrap | Legacy script; current bootstrap uses Nix activation instead |

### Worktree / Feature-Branch Support

The Makefile `link` target enables testing dotty from any checkout:

1. `sed` rewrites `~/PersonalConfigs` in `dotty.toml` to the current repo root (`$(ROOT)`)
2. Writes to a temp file (avoids modifying tracked config)
3. Passes temp config as explicit argument to `dotty link --no-cache`
4. Cleans up temp file after execution

The Nix activation hook always uses `$HOME/PersonalConfigs` (the canonical clone path).

## 5. Design Decisions

- **Nushell, not a compiled binary** — dotty is a Nushell module, not a standalone tool. This eliminates build steps, enables REPL debugging, and leverages Nushell's structured data (tables, records) for the linking pipeline. Tradeoff: requires Nushell runtime on PATH.

- **TOML over ad hoc conventions** — configuration is explicit rather than convention-based (e.g. "everything in `config/` maps to `~/.config`"). This supports non-obvious mappings like `claude/ → ~/.claude` and `pi/ → ~/.pi/agent`.

- **Per-project caches** — each project gets its own cache file rather than a single global cache. This allows independent invalidation and makes directory-mode transitions clean (file entries are replaced by a single `"."` entry).

- **`--no-cache` as default for automation** — all non-interactive invocations (Makefile, Nix activation, cc-sandbox) use `--no-cache`. Only the Neovim integration uses cached mode for speed. This ensures automation is always correct at the cost of re-scanning.

- **git-ignore awareness** — dotty uses git's own ignore machinery (`git ls-files`, `git check-ignore`) rather than reimplementing glob exclusion. Files that git ignores are never linked, preventing accidental exposure of build artifacts or secrets.

- **Interactive conflict resolution** — when a real file exists at a target path, dotty prompts in interactive mode and auto-removes in non-interactive mode (hooks, Nix activation). This balances safety for manual runs with reliability for automation.

- **`chmod` as separate command** — making `~/.local/bin/*` executable is decoupled from linking because file permissions don't survive symlink creation (`ln -sf` creates a new symlink regardless). Neovim calls `chmod` after every `link`; other callers don't need it (Nix sets permissions via activation scripts).

## 6. Testing

### Automated

- **Test config** — `config/dotty/test-dotty.toml` provides a sandboxed project (`~/PersonalConfigs/config/dotty` → `~/dotty-test`) for validation without touching real dotfiles.

### Manual

- **`nix-smoke`** — verifies config symlinks are valid (checks that expected symlinks in `~/.config` point to real files).
- **Neovim `:DottyTest`** — tests whether the current buffer is managed by dotty.
- **`dotty prune`** — finds and removes broken symlinks (useful after file deletions).

## 7. Open Questions

- `boot.zsh` calls `dotty setup` which doesn't match any current command — confirms this script is stale
- The `deals` project links a `_git` directory as individual files to `.git` — fragile if git internals change structure
- `work` and `home` projects both target `~` — relies on non-overlapping file trees with no enforcement beyond duplicate-target detection
- `detect-path-overlaps` call is commented out in `mod.nu` — the function exists in `helpers.nu` but is not invoked during linking
