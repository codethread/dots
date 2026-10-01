# Mise cheat sheet

Mise handles **tool versions**, **host packages**, **tasks**, and **managed configuration**. Global tool defaults live in `config/mise/config.toml` (dotty links it into `~/.config/mise`); the project reads the same file through `.mise/conf.d/tools.toml`. Profile-only tools are mirrored in `config/mise/config.{dev,work}.toml`.

## For this dotfiles repo

Run from the dots checkout. Replace `dev` with `work` on your work machine.

```nu
# Discover available tasks
mise -E dev tasks

# Preview Claude settings changes
mise -E dev dot diff ~/.claude/settings.json

# Apply/check Claude settings
mise -E dev run claude:apply
mise -E dev run claude:status

# Prepare dependencies, then apply services
mise -E dev run services:apply

# Check services
mise -E dev run services:status

# Preview host packages (host packages only; no npm or VS Code extras)
mise -E dev bootstrap packages apply --dry-run

# Install tools and host packages, then Todoist, Playwright CLI and VS Code extensions
mise -E dev run packages:apply

# Show host package installation state
mise -E dev run packages:status
```

**Avoid bare `mise bootstrap` here**: use the dedicated tasks so service dependencies are prepared first. Package work belongs to `packages:apply`, not the service tasks.

Host packages live in `.mise/conf.d/packages.toml` plus the active profile overlay: `mise.dev.toml`, `mise.work.toml`, `mise.personal.toml`, or `mise.work-boot.toml` (both work bootstrap usernames use `work-boot`). `packages:apply` installs versioned tools and those Homebrew formulae and casks, builds the pinned Todoist fork, then installs `@playwright/cli` with the Homebrew npm into `~/.local`, then the profile's VS Code extensions. `packages:status` reports host packages only. Applying packages never prunes unlisted packages or upgrades existing formulae; run `mise -E dev bootstrap packages upgrade --manager brew` to upgrade formulae explicitly.

## User setup and Nix handoff

User setup lives in `.mise/conf.d/workstation.toml`; Nix no longer clones repositories, links dotfiles, or generates shell init/completion caches.

```nu
# Existing machine: install replacements, drop old Nix ownership, then prepare
mise -E dev run packages:apply
make system
mise -E dev run workstation:setup

# Later user-environment changes (no Nix switch, no services)
mise -E dev run workstation:apply

# Individual phases / read-only previews
mise -E dev bootstrap repos apply --dry-run --skip-dirty
mise -E dev run repositories:apply
mise -E dev run dotfiles:apply
mise -E dev run shell:prepare
```

`boot/boot.sh` uses the same order on a new machine. `workstation:apply` runs packages then `workstation:setup` (repositories → dotfiles → shell caches). It does not apply Claude settings, services, or macOS system defaults. Run from a durable checkout.

Repository apply requires GitHub SSH access for `agents`, Alfred, and images. Authentication and origin conflicts fail visibly; dirty checkouts are reported and skipped, and unpinned existing repos are not pulled. The Todoist fork and nix-direnv are pinned. Dotty refuses conflicting files rather than forcing replacement. `repositories:apply` also applies declared directories (including `/tmp/claude`) and the gitwatch link.

Nushell init files now live under `~/.local/cache/dots/shell`, separate from the old Home Manager symlinks. Direnv loads the pinned vendor checkout through `config/direnv/lib/nix-direnv.sh`. Zsh completions are audited and compiled with the current Zsh; rerun `shell:prepare` after package upgrades or a Nix switch. Old generated init/plugin links are removed by the next Home Manager activation; no manual deletion is needed.

## General commands

```nu
# Show loaded configuration files
mise config

# Show configured tools and their versions
mise ls

# Install versioned tools declared in [tools] (not host packages)
mise install

# Run a command with mise-managed tools
mise exec -- bun --version

# Diagnose mise setup
mise doctor
```

To add tools:

```nu
# Add Node to the current project's mise.toml and install it
mise use node@24

# Set a user-wide default instead
mise use --global node@24
```

Useful distinction: **`use` changes configuration; `install` installs versioned tools only; `run` executes a task; `exec` executes an arbitrary command. Host packages are applied by `packages:apply`, not `mise install`.**

No shell activation is needed. The shared environment adds mise shims after `~/.local/bin`, preserving user-owned overrides (including the custom Pi wrapper), with Homebrew before Nix profiles. `mise exec` preserves project-selected tool paths in child shells. Existing native Claude/Cursor installs under `~/.local/bin` remain deliberate overrides; `mise which claude` shows the managed executable.

Apply packages before switching the reduced Nix configuration. `make link` exposes global tool defaults; open a fresh shell afterwards. Pi uses the npm/Node distribution, and its extensions install from npm names in `pi/agent/settings.json`. QMK uses PyPI because mise cannot evaluate its Homebrew tap; firmware setup remains an explicit `qmk setup` operation. Nufmt builds its previously pinned Git revision through Cargo. Work uses release binaries for Vault and cargo-lambda, avoiding source-only tap builds.
