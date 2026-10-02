# Mise cheat sheet

Mise handles **tool versions**, **host packages**, **tasks**, and **managed configuration**. Global tool defaults live in `config/mise/config.toml` (dotty links it into `~/.config/mise`); the project reads the same file through `.mise/conf.d/tools.toml`. Profile-only tools are mirrored in `config/mise/config.{dev,work}.toml`.

## For this dotfiles repo

Normal use: run `make` from the dots checkout. It switches the remaining Nix system layer, then runs `mise run boot`: packages and workstation setup → Oven verification/build → Claude settings → services. `make boot` (or `mise run`) runs just the mise side, using the shell's `MISE_ENV` profile. Dev/work apply all services; personal/work-boot apply syncengine only. Run from a durable checkout with the existing repository access and service credentials configured.

The individual commands below are for targeted changes and diagnostics. Replace `dev` with `work` on your work machine.

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

# Syncengine alone (also available on personal/work-boot)
mise -E personal run syncengine:apply
mise -E personal run syncengine:status

# Preview host packages (host packages only; no npm or VS Code extras)
mise -E dev bootstrap packages apply --dry-run

# Install tools, host packages and agent CLIs, then Todoist, Playwright CLI and VS Code extensions
mise -E dev run packages:apply

# Show host package installation state
mise -E dev run packages:status
```

**Avoid bare `mise bootstrap` here**: use the dedicated tasks so service dependencies are prepared first. Package work belongs to `packages:apply`, not the service tasks. Syncengine requires `packages:apply` and `repositories:apply` first (gitwatch link, Git, fswatch, coreutils). Switch the updated Nix configuration and wait for the old syncengine watchers to exit before applying its mise replacement. The full dev/work services workflow includes syncengine; dev also includes backup-notes (runs at load and every 15 minutes). Switch the updated Nix configuration to retire `com.codethread.backup-notes` before applying its mise replacement. `syncengine:apply` scopes application to syncengine without cc-notify credentials or Git-maintenance registration.

Java 21 (Temurin), clj-kondo, and the pinned Graph-Easy CLI live in the global tool defaults. Graph-Easy renders Devflow task DAGs; its HTTP install uses the original checksum-pinned CPAN archive and macOS Perl, with no global Perl environment changes. `JAVA_HOME` defaults to mise's `temurin-21` install symlink; `mise exec` and tasks set it to the selected project JDK. Volta is removed; mise owns Node, including the Node 24 runner in `pdx-pandora`.

Mise owns the shared Fira Code, Victor Mono, and Symbols Nerd Font casks, installed into `~/Library/Fonts`. Nix no longer declares shared fonts, kitty/ncurses terminfo packages, or Nix Zsh completions. The shared mise host list also includes agent-browser, pngpaste, yazi, flock, and Clojure. Bitwarden CLI is declared only in the work and work-boot overlays. Homebrew's Clojure formula brings its own OpenJDK dependency, but the shell's default JDK remains mise's Java 21 through `JAVA_HOME`.

Host packages live in `.mise/conf.d/packages.toml` plus the active profile overlay: `mise.dev.toml`, `mise.work.toml`, `mise.personal.toml`, or `mise.work-boot.toml` (both work bootstrap usernames use `work-boot`). `packages:apply` installs versioned tools and those Homebrew formulae and casks, runs `llm:install` for missing agent CLIs, builds the pinned Todoist fork, then installs `@playwright/cli` with the Homebrew npm into `~/.local`, then the profile's VS Code extensions. `packages:status` reports host packages only. Applying packages never prunes unlisted packages or upgrades existing formulae; run `mise -E dev bootstrap packages upgrade --manager brew` to upgrade formulae explicitly.

Millstrand is built locally from source and is not managed by mise.

## Update LLM tools

```nu
# Install missing CLIs without upgrading existing installations
mise -E dev run llm:install

# Preview task dispatch without running any installer/updater
mise -E dev run --dry-run llm:update

# Update all four CLIs and Pi's npm extensions
mise -E dev run llm:update
```

These tasks cover **Claude, Cursor Agent, Codex, Pi, and Pi's npm extensions**, using official installers and vendor update policies. `packages:apply` includes `llm:install`. Settings and the pies wrapper are preserved; runtimes, services, shared repositories, and other plugin marketplaces are outside this task's scope.

Definitions live in `.mise/conf.d/llm.toml`, implemented by `home/.local/bin/mise-llm`. Updates run sequentially and stop on failure; resolve the error and rerun.

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

`boot/boot.sh` uses the same order on a new machine. `workstation:apply` runs packages then `workstation:setup` (repositories → Hive update/install → agents update/install → dotfiles → shell caches). It does not apply Claude settings, services, or macOS system defaults. Run from a durable checkout.

Repository apply requires GitHub SSH access for Hive, `agents`, Alfred, and images. Authentication and origin conflicts fail visibly; dirty checkouts are reported and skipped, and unpinned existing repos are not pulled by `repositories:apply` itself. The separate Hive and agents tasks below pull and install their tooling, and fail on dirty checkouts. The Todoist fork and nix-direnv are pinned. Dotty refuses conflicting files rather than forcing replacement. `repositories:apply` also applies declared directories (including `/tmp/claude`) and the gitwatch link.

Nushell init files now live under `~/.local/cache/dots/shell`, separate from the old Home Manager symlinks. Direnv loads the pinned vendor checkout through `config/direnv/lib/nix-direnv.sh`. Zsh startup and completion preparation both use macOS `/bin/zsh`, not a Zsh found on PATH. Homebrew and Nix package completions remain available alongside its built-ins. Rerun `shell:prepare` after macOS/package upgrades or a Nix switch. The next `make system` removes the extra Nix Zsh and its global startup files; preparation already works before that switch. Old generated init/plugin links are removed by the next Home Manager activation; no manual deletion is needed.

## Update supporting repositories

```nu
# Run from anywhere; use -E work on a work machine
mise -C ~/dev/dots -E dev run hive:update
mise -C ~/dev/dots -E dev run agents:update

# Preview Git operations without fetching or installing
mise -C ~/dev/dots -E dev bootstrap repos update ~/dev/projects/hive ~/dev/projects/agents --dry-run
```

Both tasks are included in `workstation:setup` and `workstation:apply` on every profile. They clone missing checkouts, fast-forward existing ones, then install from the committed dependency lockfile:

- `hive:update` runs `bun install --frozen-lockfile` and Honeycomb's build, generating `~/.local/bin/honeycomb`.
- `agents:update` runs `pnpm install --frozen-lockfile` and `pnpm run link:pi`, linking `~/.local/bin/pi` and `~/.local/bin/pies`. Pi's repo-owned settings already reference the local agents package, so no `pi install` or settings rewrite is needed. Plugin marketplace registration is unchanged, and this task does not restart a running Pies daemon.

Definitions live in `.mise/conf.d/hive.toml` and `.mise/conf.d/agents.toml`. Run `packages:apply` first on a new machine for Git, Bun, Node, pnpm, `br` (used by Hive's install hook), and the real Pi CLI. GitHub SSH access is required.

Updates follow each checkout's **current branch**, not a forced `main` checkout. Keep these repos on an attached branch: mise warns and skips updating a detached HEAD. Dirty checkouts, origin conflicts, or divergent history stop the task before installation; commit or stash your changes and resolve conflicts before rerunning. There is no forced reset, automatic push, or background sync—run the tasks on each machine after pushing changes upstream.

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

No shell activation is needed. The shared environment puts `~/.local/bin` first (including native CLIs and the custom Pi wrapper), then `$PI_CODING_AGENT_DIR/bin`, then mise shims, with Homebrew before Nix profiles. `mise exec` preserves project-selected tool paths in child shells. Agent CLIs are vendor-owned rather than mise versioned tools; use `llm:update`, not `mise upgrade`, for them.

Apply packages before switching the reduced Nix configuration. `make link` exposes global tool defaults; open a fresh shell afterwards. Pi's official managed installer uses Node and locked npm dependencies; its extensions install from npm names in `pi/agent/settings.json`. QMK uses PyPI because mise cannot evaluate its Homebrew tap; firmware setup remains an explicit `qmk setup` operation. Nufmt builds its previously pinned Git revision through Cargo. Work uses release binaries for Vault and cargo-lambda, avoiding source-only tap builds.
