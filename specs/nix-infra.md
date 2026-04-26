# Nix Infrastructure Specification

**Status:** Implemented
**Last Updated:** 2026-04-04

## 1. Overview

### Purpose

Declarative system configuration and bootstrap infrastructure for all personal machines. A single Nix flake defines 5 system configurations spanning macOS (Darwin) and NixOS across multiple hardware architectures and user identities. The bootstrap script takes a bare machine from zero to fully configured in one invocation; the rebuild command (`nrs`) keeps existing machines in sync with the repo.

### Goals

- One-command bootstrap for new machines (macOS and NixOS)
- Declarative, reproducible system state via Nix flakes
- Shared configuration across platforms with platform-specific extensions
- Dual nixpkgs channel support (unstable + master) for package freshness
- Automated validation via pre-commit hooks and smoke tests
- Long-running services on NixOS via systemd user units

### Non-Goals

- CI/CD pipeline — validation is local (pre-commit hooks, manual smoke tests)
- Multi-user support — all configs target a single user per machine
- NixOS on desktop as daily driver — homelab and VM only; macOS is the primary workstation
- Containerised services — services run directly as systemd user units, not Docker/Podman
- Secrets management beyond WiFi PSK — no vault, no sops, no agenix

## 2. Architecture

### Layer Hierarchy

```
flake.nix (inputs, overlays, system configurations)
    │
    ├─ hosts/<platform>/<machine>/   System-level: hardware, networking, users, services
    │   └─ common.nix / base.nix    Shared platform defaults
    │
    ├─ profiles/<name>.nix           User-level: home-manager imports per role
    │   └─ imports features/*
    │
    ├─ features/                     Reusable home-manager modules
    │   ├─ common.nix               All platforms: packages, activations, dotfile linking
    │   ├─ darwin-common.nix         macOS-specific packages
    │   ├─ nixos-common.nix          NixOS-specific: systemd services, GTK/Qt theming
    │   └─ claude-code.nix           Claude Code settings.json generation
    │
    └─ services/
        └─ repo-service.nix           Generic builder for repo-local systemd services
```

### System Configurations

| Name | Flake Output | Arch | User | Host Module | Profile |
|---|---|---|---|---|---|
| home | `darwinConfigurations.home` | aarch64-darwin | `codethread` | `hosts/darwin/home` | `profiles/personal.nix` |
| work | `darwinConfigurations.work` | aarch64-darwin | `adam.hall` | `hosts/darwin/work` | `profiles/work.nix` |
| work-adamhall | `darwinConfigurations.work-adamhall` | aarch64-darwin | `adamhall` | `hosts/darwin/work-adamhall` | `profiles/work.nix` |
| homelab | `nixosConfigurations.homelab` | x86_64-linux | `codethread` | `hosts/nixos/homelab` | `profiles/homelab.nix` |
| vm | `nixosConfigurations.vm` | aarch64-linux | `codethread` | `hosts/nixos/vm-aarch` | `profiles/vm.nix` |

### Dual Channel Pattern

Two nixpkgs inputs provide version flexibility:

- `pkgs` ← `nixpkgs` (unstable) — default for most packages
- `pkgsMaster` ← `nixpkgs-master` (bleeding edge) — for packages needing latest versions

In `features/common.nix`, `agentPkgSet` resolves to `pkgsMaster` when available, falling back to `pkgs`. Packages like `claude-code`, `nodejs_24`, `typescript`, `typescript-language-server` use `agentPkgSet.*` to track master. `codexCliPackage` is a special case — injected via `specialArgs` from the flake, falling back to `agentPkgSet.codex` if null.

### Custom Overlays

Defined in `flake.nix`, applied to all system configs:

- **todoistOverlay** — `buildGoModule` for `todoist-cli` from `codethread/todoist` fork
- **playwrightCliOverlay** — `buildNpmPackage` for `playwright-cli` from Microsoft source

### Bootstrap Flow

```
boot/boot.sh
├─ Parse flags: --profile, --branch
├─ Detect OS (Darwin via uname / NixOS via /etc/NIXOS)
├─ Resolve profile (default: homelab on NixOS, username-based on macOS)
├─ Clone dots (SSH if ~/.ssh exists, else HTTPS)
├─ Set XDG environment variables
├─ [NixOS] Copy hardware-configuration.nix if placeholder
├─ [NixOS] Generate flake.lock if missing → nixos-rebuild switch
├─ [macOS] Install Lix (nix fork) if missing → Install Homebrew → darwin-rebuild switch
├─ Post-rebuild: nu "boot machine"
│   ├─ [macOS] Check Full Disk Access
│   ├─ Build bun binaries (oven/)
│   └─ Sync nvim plugins (nvim-sync)
└─ [NixOS] Commit hardware-configuration.nix if git identity set
```

`boot/boot.sh` is also responsible for the NixOS hardware file handoff. Keep its path logic in sync with the real host layout under `nix/hosts/nixos/`.

### Rebuild Flow (Existing Machine)

```
make system [PROFILE=<name>]
└─ nrs [profile] [--update]
   ├─ [--update] nfu → nix flake update
   ├─ Resolve profile → flake reference
   ├─ Prefer current git worktree root when it looks like the dotfiles repo
   ├─ Else fall back to `$DOTFILES` / `~/dev/dots`
   ├─ darwin-rebuild switch / nixos-rebuild switch
   └─ [NixOS] Kernel reboot check
```

### Home-Manager Activation DAG

Three ordered activation scripts run during every rebuild:

1. **bootDotfiles** (NixOS only, after `installPackages`) — clones dots if missing
2. **userBootstrap** (after `writeBoundary`) — creates directory structure, clones vendor repos (nu_scripts, gitwatch, Alfred on macOS), sets git hooks path
3. **clone-\<name\>** (per service, after `installPackages`) — each `repo-service.nix` instance generates its own activation hook that clones its repo via SSH with a 5s BatchMode auth test; skips gracefully if SSH auth unavailable
4. **dottyLink** (after `userBootstrap`) — symlinks dotfiles into place via dotty (see [dotty spec](./dotty.md))

### Service Module

`services/repo-service.nix` is a parametrised home-manager module for long-running processes:

- **Activation hook** clones the repo (SSH-gated, graceful fallback)
- **Systemd user service** (`Type = simple`) runs the process directly — no tmux wrapper
- **`Restart = on-failure`** with 5s backoff for automatic crash recovery
- Logs to journald: `journalctl --user -u <name>`
- Control via `systemctl --user status/start/stop/restart <name>`
- Command template supports `{bun}` and `{dir}` substitutions
- Service runner exports an explicit PATH including Nix profile bins and `~/.local/bin` (no shell-dependent `$PATH` inheritance)
- Optional **`devShell`** argument runs the command via `nix develop {dir}#<shell>` so repo-local flakes can pin runtime tooling

- **`extraPackages`** — optional `pkgs: [...]` last-resort escape hatch for tools that cannot be added to the target repo's flake. The standard pattern is to put all runtime deps in the target repo's `flake.nix` devShell instead.

Active services (homelab only): `ai-task-cron`, `ai-note-watcher`, `yt-playlist-watcher` (all from `codethread/notes`, `devShell = "automation"`), `cc-inspect`, `cc-notify` (`devShell = "default"`)

### NixOS Built-In Services

Defined directly in `features/nixos-common.nix` (not via `repo-service.nix`):

- **tmux-main** — systemd oneshot that creates the main tmux session on graphical login
- **backup-notes** — systemd oneshot + timer that auto-commits and pushes the notes vault (`~/dev/projects/notes/vault`) every 15 minutes via git (add → stash → pull --rebase → stash pop → commit → push). Sends `notify-send` on failure when Wayland display is available.

## 3. Data Model

### Profile Resolution

macOS profiles are resolved from username:

| Username | Default Profile |
|---|---|
| `adam.hall` | `work` |
| `adamhall` | `work-adamhall` |
| (other) | `home` |

NixOS defaults to `homelab`. The `_resolve_profile` function handles the special case where profile `work` + username `adamhall` maps to `work-adamhall`.

For bootstrap-only hardware file management, `boot/boot.sh` may need an additional profile → host-directory mapping when the flake output name differs from the on-disk host directory. Current example:

| NixOS profile | Host directory |
|---|---|
| `homelab` | `nix/hosts/nixos/homelab` |
| `vm` | `nix/hosts/nixos/vm-aarch` |

When adding or renaming NixOS hosts, update both `nix/flake.nix` and `boot/boot.sh` together.

### Environment Variables (Set by All Configs)

| Variable | Value |
|---|---|
| `DOTFILES` | `~/dev/dots` by default |
| `EDITOR` | `nvim` |
| `SHELL` | `<pkgs.nushell>/bin/nu` |
| `XDG_CONFIG_HOME` | `~/.config` (macOS: `~/dev/dots/config` during bootstrap) |
| `XDG_DATA_HOME` | `~/.local/share` |
| `XDG_STATE_HOME` | `~/.local/state` |
| `XDG_CACHE_HOME` | `~/.local/cache` |

For interactive shells and Nix-managed environments, `DOTFILES` remains the canonical clone path. Rebuild helpers (`nrs`, `nfu`, `nrb`, related flake queries) additionally detect the current git worktree root and use it when invoked from a valid dotfiles checkout. The root `Makefile` also overrides `DOTFILES` to the current checkout so `make link` / `make system` operate on the active worktree.

### Network Secrets

WiFi PSK stored at `/etc/codethread/nm.env` (NixOS homelab only), referenced via `envsubst` in NetworkManager profile. Not managed by nix — created manually or via `nix-wifi-setup`.

## 4. Interfaces

### CLI Commands (Nushell — `ct/nix.nu`)

| Command | Purpose |
|---|---|
| `nrs [profile] [--update]` | Rebuild and switch system configuration, preferring the current dotfiles worktree when valid |
| `nfu` | Update flake inputs for the current dotfiles worktree when valid |
| `nrs-flake-host [profile]` | Resolve current machine's flake host name |
| `nrs-check [profile]` | Validate homebrew taps/brews/casks (Darwin only) |
| `nix-clean` | Delete all old generations + GC |
| `nix-clean-older [days=14]` | Delete generations older than N days + GC |
| `nix-packages [profile]` | List home-manager packages for a profile from the current flake path |
| `nix-sys-packages [profile]` | List system-level packages for a profile from the current flake path |
| `nix-smoke [profile] [--skip-flake]` | Health check: PATH, binaries (including `pi`), config symlinks (including `~/.pi/agent/settings.json`), flake eval against the current flake path |
| `nix-outputs` | Show all flake outputs from the current flake path |

### CLI Commands (Nushell — `ct/nixos.nu`, NixOS only)

| Command | Purpose |
|---|---|
| `nrb [profile=homelab]` | Set boot target without switching, preferring the current dotfiles worktree when valid |
| `nix-store-info` | Show store size and generation count |
| `nix-wifi-setup [--ssid --env-file --var]` | Interactive WiFi password configuration |
| `nix-wifi-restart` | Restart NetworkManager profiles service |
| `nix-wifi-setup-debug [--env-file]` | Debug NetworkManager startup |

### Makefile Targets

| Target | Action |
|---|---|
| `make system` | Rebuild nix system via local `ct/nix.nu` from the current checkout |
| `make link` | Symlink dotfiles from the current checkout via `dotty link --no-cache` |
| `make build` | Build `oven/` tools from the current checkout via `nix develop` + `bun run verify` |
| `make all` | `link` → `build` → `system` |

### Git Pre-Commit Hook

`.githooks/pre-commit` validates the flake when `nix/` files are staged:

1. Skip if no `nix/` changes staged
2. Skip during rebase/cherry-pick
3. Detect profile via `nrs-flake-host`
4. Run `<rebuild-cmd> build --flake` (build, not switch)
5. Block commit on failure

## 5. Design Decisions

- **Lix over official Nix on macOS** — Lix is a community fork installed via `install.lix.systems/lix`. Used as the Nix implementation on Darwin.

- **Homebrew alongside Nix on macOS** — Homebrew manages GUI casks and Mac App Store apps (via `mas`). Nix handles CLI tools. `nix-darwin` orchestrates both declaratively via `homebrew.casks` and `homebrew.masApps`.

- **Two work profiles for username variants** — Some macOS machines use `adam.hall` (dotted), others use `adamhall`. Both share `work-common.nix` and `profiles/work.nix`; only the host module and `primaryUser` differ.

- **Direct process execution for managed services** — `services/repo-service.nix` runs processes with `Type = simple` directly under systemd. This gives proper PID tracking, `journalctl` log access, and working restart semantics (`Restart = on-failure`). `tmux-main` (the interactive session) remains tmux-backed since it exists for human interaction, not daemon management.

- **SSH-gated service cloning** — Service repos are cloned only if SSH auth to github.com succeeds (5s timeout, BatchMode). This prevents blocking the rebuild on machines without SSH keys or on first bootstrap before keys are deployed.

- **Pre-compiled treesitter parsers via Nix** — `nvim-treesitter` grammars are built by Nix and symlinked into `~/.local/share/nvim/nix-treesitter-parsers`, avoiding runtime compilation.

- **Generated shell init scripts** — `atuin`, `carapace`, and `direnv` init scripts are generated at Nix eval time and written to `~/.local/cache/`. This avoids runtime generation costs in shell startup.

- **Single bootstrap entrypoint** — `boot/boot.sh` is the current entry point and handles both macOS and NixOS. Older shell-specific bootstrap scripts were removed to keep machine setup paths unambiguous.

- **XDG_CONFIG_HOME points to repo during bootstrap** — `boot.sh` sets `XDG_CONFIG_HOME="${DOTFILES}/config"` so tools find configs before dotty has run. After `dottyLink` activation, configs are symlinked to `~/.config/`.

- **Current worktree preferred for rebuild commands** — The canonical clone path remains `~/dev/dots`, but flake-backed Nushell commands and the root `Makefile` prefer the current git worktree when it contains the expected repo structure. This allows testing changes from feature branches and linked worktrees without rewriting the base shell environment.

## 6. Testing

### Automated

- **Pre-commit hook** — Builds the flake on every commit touching `nix/`. Catches syntax errors, missing inputs, and evaluation failures before they reach remote.

### Manual

- **`nix-smoke [profile]`** — Comprehensive health check verifying: PATH entries present, required binaries on PATH (including `pi`), config symlinks valid (including `~/.pi/agent/settings.json`), flake evaluates without error. Returns structured table of pass/fail results.
- **`nrs-check [profile]`** — Darwin-only. Validates all homebrew taps, brews, and casks resolve without error before running a rebuild.
- **`cc-sandbox-smoke`** — End-to-end container rebuild and headless Claude/Codex execution test (expensive, not routine).

## 7. Open Questions

- WiFi secrets (`/etc/codethread/nm.env`) are manually managed — consider `agenix` or `sops-nix` if more secrets are needed
- VM profile (`nixosConfigurations.vm`) appears minimal — unclear if actively used or a testing artifact
