# Mise cheat sheet

Mise handles **tool versions**, **host packages**, **tasks**, and **managed configuration**. Global tool defaults live in `config/mise/config.toml` (dotty links it into `~/.config/mise`); the project reads the same file through `.mise/conf.d/tools.toml`. Profile-only tools are mirrored in `config/mise/config.{dev,work}.toml`.

## For this dotfiles repo

Normal use: run `make` from the dots checkout. `make` (and `make all`, `make boot`) runs `mise run boot`: packages and system apply → workstation setup → Oven verification/build → Claude settings → services, using the shell's `MISE_ENV` profile. The old Nix switch is gone: there is no `make system`, `nrs`, or `nfu`. Dev/work apply all services; personal/work-boot apply syncengine only. Run from a durable checkout with the existing repository access and service credentials configured.

The individual commands below are for targeted changes and diagnostics. Replace `dev` with `work` on your work machine.

```nu
# Discover available tasks
mise -E dev tasks

# Preview Claude settings changes
mise -E dev dot diff ~/.claude/settings.json

# Apply/check Claude settings
mise -E dev run claude:apply
mise -E dev run claude:status

# Preview/apply user macOS defaults (Dock, Finder, keyboard, Screenshots, Spaces)
mise -E dev bootstrap macos defaults apply --dry-run
mise -E dev run macos:apply
mise -E dev run macos:status

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

**Avoid bare `mise bootstrap` here**: use the dedicated tasks so service dependencies are prepared first. Package work belongs to `packages:apply`, not the service tasks. Syncengine requires `packages:apply` and `repositories:apply` first (gitwatch link, Git, fswatch, coreutils). [Retire the old nix-darwin agents](#retiring-nix) and wait for the old syncengine watchers to exit before applying their mise replacements. The full dev/work services workflow includes syncengine; dev also includes backup-notes (runs at load and every 15 minutes). Retire `com.codethread.backup-notes` before applying its mise replacement. `syncengine:apply` scopes application to syncengine without cc-notify credentials or Git-maintenance registration.

Java 21 (Temurin), clj-kondo, and mermaid-ascii live in the global tool defaults. mermaid-ascii renders Devflow task DAGs from its aqua/GitHub release binary, with no Perl or CPAN dependency. `JAVA_HOME` defaults to mise's `temurin-21` install symlink; `mise exec` and tasks set it to the selected project JDK. Volta is removed; mise owns Node, including the Node 24 runner in `pdx-pandora`.

Mise owns the shared Fira Code, Victor Mono, and Symbols Nerd Font casks, installed into `~/Library/Fonts`, along with agent-browser, pngpaste, yazi, flock, Clojure, and `pam-reattach` (see [macOS system layer](#macos-system-layer)); `nixfmt` and `direnv` were removed with Nix. Homebrew Bash remains an explicit dependency because `qlock` requires Bash 5+ features; its `/usr/bin/env bash` shebang resolves that Bash from the login PATH, while the login shell remains macOS Zsh. Agents should invoke `qlock` normally rather than hardcoding a Bash path. Bitwarden CLI is declared only in the work and work-boot overlays. Homebrew's Clojure formula brings its own OpenJDK dependency, but the shell's default JDK remains mise's Java 21 through `JAVA_HOME`.

Host packages live in `.mise/conf.d/packages.toml` plus the active profile overlay: `mise.dev.toml`, `mise.work.toml`, `mise.personal.toml`, or `mise.work-boot.toml` (both work bootstrap usernames use `work-boot`). `packages:apply` installs versioned tools and those Homebrew formulae and casks, runs `llm:install` for missing agent CLIs, builds the pinned Todoist fork, then installs `@playwright/cli` with the Homebrew npm into `~/.local`, then the profile's VS Code extensions. `packages:status` reports host packages only. Applying packages never prunes unlisted packages or upgrades existing formulae; run `mise -E dev bootstrap packages upgrade --manager brew` to upgrade formulae explicitly.

Millstrand is built locally from source and is not managed by mise.

## New machine bootstrap

`boot/boot.sh` is the supported entry point for a new Apple Silicon macOS machine:

```nu
./boot/boot.sh                       # profile from shell identity
./boot/boot.sh -p dev                # explicit mise profile
./boot/boot.sh -p work -b main       # explicit profile and branch
```

It installs Homebrew with the official installer (which also prepares Apple's Command Line Tools, including Git) and installs `mise` with `brew` **before** cloning, so bootstrap has no Nix or preinstalled-Git dependency. It then clones `codethread/dots` (SSH when `~/.ssh` exists, otherwise HTTPS), sets the bootstrap XDG roots, sources `config/env/base.sh` to select the machine profile, and runs `mise run boot`. Finally it runs `nu boot machine`, which checks Full Disk Access, builds the Oven binaries, and syncs Neovim plugins. A `work-boot` machine prints the next step: install workfiles, then `mise -E work run boot`. The script is rerunnable after a failure.

The profile is the explicit `-p` value when given, otherwise the shared shell identity in `config/env/base.sh`: `personal` for `codethread`, `work` for `adamhall` once `~/pb/adam.hall/workfiles` exists, `work-boot` for other work accounts, and `dev` otherwise. `make` and `make boot` are the equivalent existing-machine path, and `make all` is an alias for `make boot`.

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

## User setup and system layer

User setup lives in `.mise/conf.d/workstation.toml`; mise applies the macOS system layer, clones repositories, links dotfiles, generates shell init/completion caches, and applies user defaults. Machines still running nix-darwin must complete [Retiring Nix](#retiring-nix) before `system:apply` can replace the old sudo file.

```nu
# Existing machine: install replacements, retire nix-darwin, then prepare
mise -E dev run packages:apply
# Then complete the Nix retirement steps in this document
mise -E dev run workstation:setup

# Later user-environment changes (no services)
mise -E dev run workstation:apply

# Individual phases / read-only previews
mise -E dev bootstrap repos apply --dry-run --skip-dirty
mise -E dev run repositories:apply
mise -E dev run dotfiles:apply
mise -E dev run shell:prepare
mise -E dev bootstrap macos defaults apply --dry-run
mise -E dev run macos:apply
mise -E dev run macos:status
```

`boot/boot.sh` installs Homebrew and mise before cloning, then uses the same order on a new machine. `workstation:apply` runs packages then `workstation:setup` (`system:apply` → repositories → Hive update/install → agents update/install → dotfiles → shell caches → macOS user defaults). It does not apply Claude settings or services. User Dock/Finder/keyboard defaults are mise-owned (`.mise/conf.d/macos-defaults.toml`); applying them relaunches Dock, Finder, and SystemUIServer. Run from a durable checkout.

Repository apply requires GitHub SSH access for Hive, `agents`, Alfred, and images. Authentication and origin conflicts fail visibly; dirty checkouts are reported and skipped, and unpinned existing repos are not pulled by `repositories:apply` itself. The separate Hive and agents tasks below pull and install their tooling, and fail on dirty checkouts. The Todoist fork is pinned. Dotty refuses conflicting files rather than forcing replacement. `repositories:apply` also applies declared files/directories (including `/tmp/claude` and dev's root-owned SSH configuration) and the gitwatch link. Managed-file application can request sudo on every profile; `claude:apply` uses the same file phase.

Nushell init files live under `~/.local/cache/dots/shell`. Open a fresh login shell for a fresh environment: `/etc/zprofile` runs before Zsh's `config/zsh/.zprofile`, and Bash's `home/.bash_profile` sources the base before `.bashrc`. On macOS, Kitty and Ghostty use the default login shell directly; no terminal startup wrapper or custom shell/command is configured. Interactive Bash and Zsh activate mise natively, and Nushell regenerates and imports the activation module on every interactive startup ([details](#shell-activation-and-project-environments)). Zsh startup and completion preparation both use macOS `/bin/zsh`, not a Zsh found on PATH. Homebrew completions remain available alongside its built-ins. Rerun `shell:prepare` after macOS/package upgrades.

### macOS system layer

`.mise/conf.d/macos-system.toml` owns the small privileged layer that nix-darwin used to provide:

- `bootstrap.user.login_shell = "/bin/zsh"` keeps the macOS-managed Zsh as the login shell.
- `/etc/pam.d/sudo_local` is managed as `root:wheel`, mode `0644`, containing an optional `/opt/homebrew/lib/pam/pam_reattach.so` line followed by `auth sufficient pam_tid.so`. This enables Touch ID in tmux/screen while retaining the password fallback; the stock `/etc/pam.d/sudo` already includes `sudo_local`, so neither it nor `/etc/pam.d/sudo_local.template` is modified.
- `system:apply` requires macOS 14+ (`/etc/pam.d/sudo_local.template` exists) and `packages:apply` for `pam-reattach`. It refuses to run while `/etc/pam.d/sudo_local` is a symlink, because that file has another owner; complete [Retiring Nix](#retiring-nix) first.
- Managed-file writes are atomic and deliberate: no `replace = true`, no PAM-specific API, and no downloaded privileged script. `system:status` reports the login shell and scoped file status.

```nu
mise -E dev run system:apply
mise -E dev run system:status
```

On 2026-10-03 the dev Mac mini completed the live handoff: `sudo_local` is now a regular mise-managed file, password sudo worked in normal terminals and tmux, and the Nix store was removed. Touch ID remains untested because suitable hardware was unavailable. Other machines must perform their own checks.

### Dev SSH server

`mise.dev.toml` manages `/etc/ssh/sshd_config.d/090-dots.conf` as `root:wheel`, mode `0644`. It preserves public-key-only authentication, disables password/keyboard-interactive and root login, and allows only `ct`. This applies only to the dev profile; outgoing SSH and GitHub access are unaffected.

**Remote Login is manual:** use **System Settings → General → Sharing → Remote Login**. Neither mise nor the system layer enables or disables it; removing the old Nix declaration leaves the existing macOS setting unchanged. Apply and validate the restrictions before enabling Remote Login.

For an existing dev machine, apply the replacement **before** retiring nix-darwin, which owns the old file:

```nu
# Scope to the dev overlay so the old sudo_local symlink is not touched.
with-env { MISE_OVERRIDE_CONFIG_FILENAMES: ($env.PWD | path join "mise.dev.toml") } {
    mise -E dev bootstrap files apply --dry-run
    mise -E dev bootstrap files apply
}

# Validate the SSH server configuration and inspect its effective restrictions
sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T | lines | where { |line| $line =~ '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|allowusers) ' }

# Then complete Retiring Nix; the old restrictions are removed with it and the
# Remote Login toggle is unchanged.
```

The normal dev workstation setup reapplies the managed file. No Remote Login toggle or daemon restart task is installed.

## Retiring Nix

Follow the [existing Apple Silicon Mac migration guide](nix-to-mise.md) for personal/work machines. It is the operator checklist; do not use the new-machine bootstrap to retire an existing Nix installation.

The order is **Home Manager handoff if needed → replacement packages → back up the installer and full receipt outside `/nix` → uninstall nix-darwin → apply/test mise sudo → retire old jobs → uninstall the store from the saved copy → fresh-shell boot and verification**. Keep a separate recovery root shell open throughout.

**Always copy the installed uninstaller and its receipt off the Nix volume before running it.** The dev Mac's Lix 3.95.0 executable was named `nix-installer`, but its self-relocation guard only recognized `/nix/lix-installer`. It force-unmounted its own backing executable and hung. Recovery succeeded using a copy outside the volume. Other machines should use their full original receipt, not the dev machine's partial-recovery receipt. Never `rm -rf /nix` or reuse another machine's PID or disk identifier.

Live verification on 2026-10-03: the dev Mac mini's Nix volume, daemon, mount service and repair hook are gone; mise sudo/password authentication and the final boot succeeded (135 tests, typecheck and build). The final boot ran without its intended test lock because a pasted line split the `qlock` invocation; the guide keeps that command together and selects Homebrew Bash explicitly. Touch ID and migration on personal/work hardware are not claimed as tested.

External projects with `.envrc`/flake files need their own mise migration. Editor Nix syntax support may remain. Unlisted Homebrew packages and the old vendor `nix-direnv` checkout are not pruned automatically; check other consumers before removing them.

### Retiring Home Manager on existing machines

**Before retirement:** if the machine has not had its old Home Manager-managed configuration handed over, use a historical checkout of revision `5d48d30795ae553dcee821474444af6cdea982b3`. Its Home Manager module is deliberately minimal but still activates, allowing the switch to unlink the previous managed files. Removing the module without that activation does not clean them up.

From that historical checkout, run `mise -E <profile> run packages:apply` → `make system <profile>` → `mise -E <profile> run workstation:setup`. Use `personal` for `codethread`, `work` for the full `adamhall` setup, or `work-boot` for work bootstrap accounts (`make system work-boot` maps `adamhall` to the historical `work-adamhall-boot` Nix host). Keep the recovery root shell open and use Homebrew Bash first on PATH for the historical build lock. Do not run the old default `make` target, which also applies services.

Return to the current migration checkout for the [retirement guide](nix-to-mise.md); do not delete the historical checkout while live dotfile links still reference it. The current checkout has **no `make system` command**. If ownership or the historical switch fails, stop for inspection rather than using forced linking. Fresh machines do not need this handoff.

**After store removal:** these default links may remain. Inspect their targets and unlink only links into `home-manager-files` in the Nix store; leave real files, directories, and fonts alone:

- `~/.cache/.keep`
- `~/.local/state/.keep`
- `~/Applications/Home Manager Apps`
- `~/Library/Fonts/.home-manager-fonts-version`

The old `~/.local/state/home-manager/gcroots/current-home` symlink can also be removed. Do not delete generic Nix profiles by hand: they are independent of Home Manager and belong to the installer flow. Fresh machines need no HM handoff or cleanup. Also inspect `~/.config/direnv/lib/nix-direnv.sh` and `~/.config/nushell/direnv.nu`; unlink only links pointing at the removed dots files, not real files or links owned by something else.

### References

- Apple's sudo extension note: <https://support.apple.com/en-us/109030>, plus the local `/etc/pam.d/sudo_local.template`
- [pam_reattach](https://github.com/fabianishere/pam_reattach) and its [Homebrew formula](https://formulae.brew.sh/formula/pam-reattach)
- [nix-darwin uninstalling](https://github.com/nix-darwin/nix-darwin#uninstalling)
- [Lix installer uninstall](https://git.lix.systems/lix-project/lix-installer#uninstalling)

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

## Shell activation and project environments

Mise replaces direnv. `nix-direnv`, `config/direnv/`, and the Nushell direnv hook were removed.

- The host environment is constructed by `config/env/base.sh` in a login profile, bootstrap, or the explicit clean tmux adapter. Non-login Bash, Zsh, and Nushell preserve their inherited `PATH` rather than rebuilding it; a new login shell is the explicit baseline rebuild.
- Interactive Bash (`config/bash/env`) and Zsh (`config/zsh/.zshrc`) evaluate the native mise hook (`mise activate bash|zsh`).
- Nushell imports `emit.sh --print0 --interactive` only for interactive startup, converts `PATH` to a native list, and regenerates activation before `config.nu` imports it. Noninteractive Nushell neither imports the stream nor generates the module.
- A process without an initialized project environment starts from mise shims. Scripts and agents inherit their parent environment when one exists and should use `mise exec -- <command>` or `mise run <task>` for project-selected tools. Clean automation must source `config/env/base.sh` before invoking `mise exec`.
- `mise-llm`, `mise-shell-prepare`, and the Carapace bridge inherit their caller's environment; none sources the base.
- Project environments live in each project's own `mise.toml`:

    ```toml
    [tools]
    node = "24"

    [env]
    NODE_ENV = "development"
    _.file = ".env" # Only if this project has a .env file
    _.path = ["./bin"]
    ```

- From Nushell, `mise trust` accepts a new project config, `mise install` installs `[tools]` versions, and `mise exec -- <command>` runs inside the project environment.
- `.envrc` files are not sourced automatically. This repository does not rewrite external projects; convert them to `mise.toml` deliberately if they need project-scoped tools or environment.

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

Interactive Bash and Zsh activate mise through their shell hooks; interactive Nushell imports the human-facing environment stream and regenerates the activation module at startup. Non-login children preserve the inherited project PATH, while an explicit login shell rebuilds the host baseline. The login baseline includes mise shims, and scripts use `mise exec`/`mise run` for project-selected tools. The shared environment puts `~/.local/bin` first (including native CLIs and the custom Pi wrapper), then `$PI_CODING_AGENT_DIR/bin`, then mise shims, with Homebrew next. `mise exec` preserves project-selected tool paths in non-login child shells. Agent CLIs are vendor-owned rather than mise versioned tools; use `llm:update`, not `mise upgrade`, for them.

Apply packages before `system:apply`; `packages:apply` provides `pam-reattach` and the tools the rest of setup expects. `make link` exposes global tool defaults; open a fresh shell afterwards. Pi's official managed installer uses Node and locked npm dependencies; its extensions install from npm names in `pi/agent/settings.json`. QMK uses PyPI because mise cannot evaluate its Homebrew tap; firmware setup remains an explicit `qmk setup` operation. Nufmt builds its previously pinned Git revision through Cargo. Work uses release binaries for Vault and cargo-lambda, avoiding source-only tap builds.
