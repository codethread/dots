# Nix Infrastructure Specification

- Document ID: SPEC-006
- Configuration identification: SPEC-006; migrated from `specs/nix-infra.md`; canonical path `devflow/specs/nix-infra.md`.
- **Status:** Implemented
- **Last Updated:** 2026-10-01

## [SPEC-006-S1] 1. Overview

### [SPEC-006-S1.1] Purpose

Declarative system configuration and bootstrap infrastructure for personal macOS machines. A single Nix flake defines nix-darwin system configurations for multiple user identities, including a minimal work bootstrap profile for machines that do not have private workfiles installed yet. The bootstrap script takes a bare machine from zero to fully configured in one invocation; the rebuild command (`nrs`) keeps existing machines in sync with the repo.

### [SPEC-006-S1.2] Goals

- One-command bootstrap for new macOS machines
- Declarative, reproducible system state via Nix flakes
- Shared configuration across macOS profiles
- Dual nixpkgs channel support (unstable + master) for package freshness
- Automated validation via pre-commit hooks and smoke tests
- Long-running services on macOS via launchd

### [SPEC-006-S1.3] Non-Goals

- CI/CD pipeline — validation is local (pre-commit hooks, manual smoke tests)
- Multi-user support — all configs target a single user per machine
- Containerised services — services run directly as launchd agents, not Docker/Podman
- Secrets management — no vault, no sops, no agenix

## [SPEC-006-S2] 2. Architecture

### [SPEC-006-S2.1] Layer Hierarchy

```
flake.nix (inputs, overlays, system configurations)
    │
    ├─ hosts/darwin/<machine>.nix    System-level: users, packages, services
    │   ├─ common.nix               Shared defaults (users, macOS defaults, services)
    │   └─ dev-tools.nix            Heavy dev-only Nix extras (JVM) — dev + work only
    │
    ├─ profiles/<name>.nix           User-level: home-manager imports per role
    │   └─ imports features/*
    │
    └─ features/                     Reusable home-manager modules
        ├─ home-base.nix            Home Manager state version and baseline user PATH
        ├─ common.nix               Shared packages, activations, dotfile linking
        └─ pi.nix                    Pi package provisioning
```

### [SPEC-006-S2.2] System Configurations

| Name | Flake Output | Arch | User | Host Module | Profile |
| --- | --- | --- | --- | --- | --- |
| dev | `darwinConfigurations.dev` | aarch64-darwin | `ct` | `hosts/darwin/dev.nix` | `profiles/dev.nix` |
| personal | `darwinConfigurations.personal` | aarch64-darwin | `codethread` | `hosts/darwin/personal.nix` | `profiles/personal.nix` |
| work-boot | `darwinConfigurations.work-boot` | aarch64-darwin | `adam.hall` | `hosts/darwin/work-boot.nix` | `profiles/work-boot.nix` |
| work-adamhall-boot | `darwinConfigurations.work-adamhall-boot` | aarch64-darwin | `adamhall` | `hosts/darwin/work-boot.nix` | `profiles/work-boot.nix` |
| work | `darwinConfigurations.work` | aarch64-darwin | `adamhall` | `hosts/darwin/work-adamhall.nix` | `profiles/work.nix` |

### [SPEC-006-S2.3] Dual Channel Pattern

Two nixpkgs inputs provide version flexibility:

- `pkgs` ← `nixpkgs` (unstable) — default for most packages
- `pkgsMaster` ← `nixpkgs-master` (bleeding edge) — for packages needing latest versions

In `features/common.nix`, `agentPkgSet` resolves to `pkgsMaster` when available, falling back to `pkgs`. TypeScript tooling and agent packages available through Nix use this channel. Nix no longer declares Homebrew packages: the nix-darwin Homebrew module is disabled, and mise owns host packages plus the user-prefix npm tools.

### [SPEC-006-S2.4] Custom Overlays

Defined in `flake.nix`, applied to all system configs:

- **todoistOverlay** — `buildGoModule` for `todoist-cli` from `codethread/todoist` fork

Fast-moving agent CLIs are provided by the upstream `llm-agents` input rather than custom overlays. Homebrew's native Node and Codex packages, Playwright CLI under `~/.local`, and VS Code extensions are declared by mise (`.mise/conf.d/packages.toml` plus the profile overlays).

### [SPEC-006-S2.5] Bootstrap Flow

```
boot/boot.sh
├─ Parse flags: --profile, --branch
├─ Require macOS
├─ Resolve Nix profile (username-based); map work-adamhall-boot to the mise work-boot profile
├─ Clone dots (SSH if ~/.ssh exists, else HTTPS)
├─ Set XDG environment variables
├─ Install Lix (nix fork) if missing → Install Homebrew if missing
├─ `brew install mise`
├─ `mise -C "$DOTFILES" -E <mise-profile> run packages:apply` → darwin-rebuild switch
└─ Post-rebuild: nu "boot machine"
    ├─ Check Full Disk Access
    ├─ Build bun binaries (oven/)
    └─ Sync nvim plugins (nvim-sync)
```

### [SPEC-006-S2.6] Rebuild Flow (Existing Machine)

```
make system [<profile>]
└─ nrs [profile] [--update]
   ├─ [--update] nfu → nix flake update
   ├─ Resolve profile → flake reference
   ├─ Prefer current git worktree root when it looks like the dotfiles repo
   ├─ Else fall back to `$DOTFILES` / `~/dev/dots`
   └─ darwin-rebuild switch
```

### [SPEC-006-S2.7] Home-Manager Activation DAG

Activation includes these ordered steps:

1. **userBootstrap** (after `writeBoundary`) — creates directory structure, clones vendor repos (nu_scripts, gitwatch, Alfred and images on macOS), sets git hooks path
2. **dottyLink** (after `userBootstrap`) — symlinks dotfiles into place via dotty (see [dotty spec](./dotty.md))
3. **zshCompletions** (after `dottyLink`, `linkGeneration`, and `installPackages`) — audits installed completion paths and generates a versioned, compiled Zsh completion dump. Nix activation does not install or upgrade Homebrew packages, so this reflects whatever mise has already applied.

### [SPEC-006-S2.10] Darwin launchd Services

Deliberately **not** shared via `hosts/darwin/common.nix` — each is tied to a repo, a workload, or a machine's role. Declared in the host module that wants it.

| Service | Declared in | Applies to | Notes |
| --- | --- | --- | --- |
| `syncengine` | `hosts/darwin/common.nix` | all macOS | The one exception; keeps `~/.local/bin/syncengine` running everywhere |
| `git-maintenance-{hourly,daily,weekly}` | `.mise/conf.d/git-maintenance.toml` + profile overlay | dev, work | mise-owned LaunchAgents; filtered repository list, private state config |
| `cc-notify` | `.mise/conf.d/cc-notify.toml` + profile overlay | dev, work | mise-owned LaunchAgent; mise-managed Bun, explicit preparation before apply |
| `backup-notes` | `hosts/darwin/dev.nix` | dev | Auto-commits the notes vault every 15 min |
| `high-cpu-watch` | `hosts/darwin/dev.nix` | dev | Alerts via `cc-notify` after 10 min above 95% CPU |

Claude settings also live outside Nix: `.mise/conf.d/claude-code.toml` renders `templates/claude-settings.json.tera` with `mise -E dev run claude:apply` (or `work`). See [Claude settings](../../claude/README.md) for the apply workflow.

cc-notify and Git maintenance have moved out of Nix; see [mise services](./mise-services.md). Homebrew and mise are installed by `boot/boot.sh`, and mise owns host packages; `make system` neither installs nor upgrades Homebrew packages. `make system` does not apply mise services; use `mise -E dev run services:apply` (or `work`) separately. The remaining Nix-owned services retain their existing host declarations and activation hooks.

## [SPEC-006-S3] 3. Data Model

### [SPEC-006-S3.1] Profile Resolution

macOS profiles are resolved from username and, for work users, whether the private workfiles checkout exists at `$HOME/pb/adam.hall/workfiles`. Only the current full-work username auto-promotes to `work`; the other work username remains on its boot profile until `nix/flake.nix` and the wrapper's full-work username are updated and committed.

| Username     | Workfiles present | Current full-work username | Default Profile      |
| ------------ | ----------------: | -------------------------: | -------------------- |
| `adam.hall`  |               yes |                         no | `work-boot`          |
| `adam.hall`  |                no |                         no | `work-boot`          |
| `adamhall`   |               yes |                        yes | `work`               |
| `adamhall`   |                no |                        yes | `work-adamhall-boot` |
| `codethread` |               n/a |                        n/a | `personal`           |
| (other)      |               n/a |                        n/a | `dev`                |

The `_resolve_profile` function handles the special case where explicit profile `work-boot` + username `adamhall` maps to `work-adamhall-boot`. For mise, `work-adamhall-boot` maps back to the `work-boot` environment, so both work bootstrap usernames use `mise -E work-boot`.

### [SPEC-006-S3.2] Environment Variables (Set by All Configs)

Portable shell environment ownership lives in `config/env/base.sh`; see [SPEC-009](./shell-environment.md). Nix/Home Manager supplies packages, login shell registration, and pre-shell session seeds. Bash, zsh, Nushell, tmux, bootstrap, and containers consume the shared contract rather than maintaining independent PATH/environment lists.

| Variable            | Value                                                     |
| ------------------- | --------------------------------------------------------- |
| `DOTFILES`          | `~/dev/dots` by default                                   |
| `EDITOR`            | `nvim`                                                    |
| `SHELL`             | `<pkgs.nushell>/bin/nu`                                   |
| `XDG_CONFIG_HOME`   | `~/.config` (macOS: `~/dev/dots/config` during bootstrap) |
| `XDG_DATA_HOME`     | `~/.local/share`                                          |
| `XDG_STATE_HOME`    | `~/.local/state`                                          |
| `XDG_CACHE_HOME`    | `~/.local/cache`                                          |
| `CODEX_HOME`        | `~/.config/codex`                                         |
| `VOLTA_HOME`        | `~/.volta`                                                |
| `NPM_CONFIG_PREFIX` | `~/.local`                                                |

For interactive shells and Nix-managed environments, `DOTFILES` remains the canonical clone path. Rebuild helpers (`nrs`, `nfu`, related flake queries) additionally detect the current git worktree root and use it when invoked from a valid dotfiles checkout. The root `Makefile` also overrides `DOTFILES` to the current checkout so `make link` / `make system` operate on the active worktree.

## [SPEC-006-S4] 4. Interfaces

### [SPEC-006-S4.1] CLI Commands (Nushell — `ct/nix.nu`)

| Command | Purpose |
| --- | --- |
| `nrs [profile] [--update]` | Rebuild and switch system configuration, preferring the current dotfiles worktree when valid |
| `nfu` | Update flake inputs for the current dotfiles worktree when valid |
| `nrs-flake-host [profile]` | Resolve current machine's flake host name |
| `nix-clean` | Delete all old generations + GC |
| `nix-clean-older [days=14]` | Delete generations older than N days + GC |
| `nix-packages [profile]` | List home-manager packages for a profile from the current flake path |
| `nix-sys-packages [profile]` | List system-level packages for a profile from the current flake path |
| `nix-smoke [profile] [--skip-flake]` | Health check: PATH, binaries (including `pi`), config symlinks (including `~/.pi/agent/settings.json`), flake eval against the current flake path |
| `nix-outputs` | Show all flake outputs from the current flake path |

`nrs-check` was removed with Nix-owned Homebrew. Validate package changes with `mise -E <profile> bootstrap packages apply --dry-run` and `mise -E <profile> run packages:status`.

### [SPEC-006-S4.3] Makefile Targets

| Target        | Action                                                                             |
| ------------- | ---------------------------------------------------------------------------------- |
| `make system` | Rebuild nix system via local `ct/nix.nu` from the current checkout                 |
| `make link`   | Symlink dotfiles from the current checkout via `dotty link --no-cache`             |
| `make build`  | Build `oven/` tools from the current checkout via `nix develop` + `bun run verify` |
| `make all`    | `link` → `build` → `system`                                                        |

### [SPEC-006-S4.4] Git Pre-Commit Hook

`.githooks/pre-commit` validates the flake when `nix/` files are staged:

1. Skip if no `nix/` changes staged
2. Skip during rebase/cherry-pick
3. Detect profile via `nrs-flake-host`
4. Run `nix build <flake>#darwinConfigurations.<host>.system --no-link` (build, not switch)
5. Block commit on failure

## [SPEC-006-S5] 5. Design Decisions

- **Lix over official Nix on macOS** — Lix is a community fork installed via `install.lix.systems/lix`. Used as the Nix implementation on Darwin.

- **Homebrew packages owned by mise on macOS** — Homebrew is installed by `boot/boot.sh` to install mise; mise's built-in Homebrew package managers then use the shared prefix directly; nix-darwin's Homebrew module is disabled so its Bundle cleanup cannot remove mise-managed packages. mise declares formulae, casks, `@playwright/cli` (user prefix `~/.local`), and VS Code extensions in `.mise/conf.d/packages.toml` plus profile overlays. Applying packages neither prunes unlisted packages nor upgrades existing formulae; formula upgrades are explicit via `mise bootstrap packages upgrade --manager brew`.

- **Shared-by-default profiles** — `dev`, `personal`, `work-boot`, and `work` all import `features/common.nix` unmodified. A package is only allowed to diverge when it is genuinely large (JVM toolchain, container runtime) or tied to specific hardware (`qmk`). Optimising a handful of megabytes out of a laptop is not worth two environments that silently drift; the same reasoning applies to the macOS host layer: `hosts/darwin/common.nix` holds shared Nix concerns, `.mise/conf.d/packages.toml` holds shared host packages, and the Nix dev-tools module and mise profile overlays hold the heavy extras. Long-running services are the exception — they are per-machine by nature and are declared in the host module, never in `common.nix`.

- **Work boot profiles for username variants** — New work macOS machines may use `adam.hall` (dotted) or `adamhall`. Bootstrap supports both with minimal `work-boot` outputs. The full `work` output is intentionally single-user and only the current full-work username auto-promotes to it when workfiles exist; update `nix/flake.nix` and the rebuild wrapper's full-work username when the provisioned username changes.

- **Explicit mise service preparation** — cc-notify checkout/dependencies/credentials and Git maintenance registration are prepared by `mise -E dev run services:prepare` (or `work`), not Nix activation. Missing SSH access or credentials fails that explicit task before agents start. Services are not installed on personal or work-boot profiles.

- **Neovim-managed Tree-sitter parsers** — `nvim-treesitter` installs the configured language list into Neovim's writable data directory (`stdpath('data')/site`); Lazy runs `:TSUpdate` when the plugin changes. Nix supplies Neovim and the `tree-sitter` CLI, not grammars or queries. Compilation uses the macOS Command Line Tools C compiler. On first launch, let parser installation finish, then reopen buffers for highlighting; additional languages can be installed with `:TSInstall <language>`.

- **Generated shell init scripts** — `atuin`, `carapace`, and `direnv` init scripts are generated at Nix eval time and written to `~/.local/cache/`. This avoids runtime generation costs in shell startup.

- **Single bootstrap entrypoint** — `boot/boot.sh` is the current entry point and handles macOS. Older shell-specific bootstrap scripts were removed to keep machine setup paths unambiguous.

- **One shell environment authority** — `config/env/base.sh` owns portable variables and baseline PATH. Nushell is the interactive layer and imports that contract; it no longer duplicates portable toolchain configuration.

- **XDG_CONFIG_HOME points to repo during bootstrap** — `boot.sh` sets `XDG_CONFIG_HOME="${DOTFILES}/config"` so tools find configs before dotty has run. After `dottyLink` activation, configs are symlinked to `~/.config/`.

- **Current worktree preferred for rebuild commands** — The canonical clone path remains `~/dev/dots`, but flake-backed Nushell commands and the root `Makefile` prefer the current git worktree when it contains the expected repo structure. This allows testing changes from feature branches and linked worktrees without rewriting the base shell environment.

## [SPEC-006-S6] 6. Testing

### [SPEC-006-S6.1] Automated

- **Pre-commit hook** — Builds the flake on every commit touching `nix/`. Catches syntax errors, missing inputs, and evaluation failures before they reach remote.

### [SPEC-006-S6.2] Manual

- **`nix-smoke [profile]`** — Comprehensive health check verifying: PATH entries present, required binaries on PATH (including `pi`), config symlinks valid (including `~/.pi/agent/settings.json`), flake evaluates without error. Returns structured table of pass/fail results.
- **mise package checks** — `mise -E <profile> bootstrap packages apply --dry-run` previews host package changes and `mise -E <profile> run packages:status` reports installation state. The old Nix `nrs-check` brew validator was removed with Nix-owned Homebrew; `mise install` covers versioned tools only.
