# Nix Infrastructure Specification

- Document ID: SPEC-006
- Configuration identification: SPEC-006; migrated from `specs/nix-infra.md`; canonical path `devflow/specs/nix-infra.md`.
- **Status:** Implemented
- **Last Updated:** 2026-10-02

## [SPEC-006-S1] 1. Overview

### [SPEC-006-S1.1] Purpose

Declarative macOS system configuration alongside mise-owned user tooling and workstation setup. A single Nix flake defines nix-darwin system configurations for multiple user identities, including a minimal work bootstrap profile for machines that do not have private workfiles installed yet. The bootstrap script takes a bare machine from zero to fully configured in one invocation; the rebuild command (`nrs`) applies the remaining system layer. Mise applies user packages, repositories, dotfiles, and shell caches without a rebuild.

### [SPEC-006-S1.2] Goals

- One-command bootstrap for new macOS machines
- Declarative, reproducible system state via Nix flakes
- Shared configuration across macOS profiles
- One nixpkgs channel for remaining system concerns; mise for fast-moving user tools
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
flake.nix (system configurations, user bindings, Home Manager state and PATH)
    └─ hosts/darwin/<machine>.nix    System packages, defaults, services
        └─ common.nix               Shared macOS defaults, Nix settings, and sudo policy

config/mise/                       Global runtimes and versioned tools (dotty-linked)
.mise/conf.d/                      Project-scoped mise workstation resources/tasks
mise.<profile>.toml                Machine package, tool, and service overlays
```

### [SPEC-006-S2.2] System Configurations

| Name | Flake Output | Arch | User | Host Module |
| --- | --- | --- | --- | --- |
| dev | `darwinConfigurations.dev` | aarch64-darwin | `ct` | `hosts/darwin/dev.nix` |
| personal | `darwinConfigurations.personal` | aarch64-darwin | `codethread` | `hosts/darwin/personal.nix` |
| work-boot | `darwinConfigurations.work-boot` | aarch64-darwin | `adam.hall` | `hosts/darwin/work.nix` (`boot = true`) |
| work-adamhall-boot | `darwinConfigurations.work-adamhall-boot` | aarch64-darwin | `adamhall` | `hosts/darwin/work.nix` (`boot = true`) |
| work | `darwinConfigurations.work` | aarch64-darwin | `adamhall` | `hosts/darwin/work.nix` |

### [SPEC-006-S2.3] Package Ownership

Nix uses one `nixpkgs` input for the remaining Darwin system packages and services. Mise owns user CLI tools, runtimes, fonts, and host applications:

- `config/mise/config.toml`: global tools, including Java 21, clj-kondo, and mermaid-ascii; `.mise/conf.d/tools.toml` links the same declarations into this project before first bootstrap.
- `.mise/conf.d/packages.toml` plus `mise.<profile>.toml`: Homebrew formulae and casks.
- `config/mise/config.{dev,work}.toml`: profile-specific tools outside this checkout, mirrored from root overlays.
- `.mise/conf.d/llm.toml`: official Claude/Cursor/Codex/Pi installers and explicit updates.
- `packages:apply`: versioned tools, host packages, missing agent CLIs, pinned Todoist build, Playwright CLI, and VS Code extensions.

Homebrew itself installs mise; nix-darwin's Homebrew module remains disabled. Shared host packages include agent-browser, pngpaste, yazi, flock, and the Clojure CLI. Bitwarden CLI is limited to the work and work-boot mise overlays. Shared fonts (Fira Code, Victor Mono, and Symbols Nerd Font) are mise-owned Homebrew casks installed into `~/Library/Fonts`. The common Darwin module no longer declares fonts, kitty/ncurses terminfo packages, or Nix CLI completions. Existing local agent wrappers/installations take precedence over mise shims intentionally.

### [SPEC-006-S2.4] Custom CLI Sources

Mise tasks orchestrate the official Claude, Cursor, Codex, and Pi installers. Pi's managed installer uses Node and locked npm dependencies; Pi installs `pi-nvim` and `@narumitw/pi-goal` from its settings.

`.mise/conf.d/todoist.toml` pins the codethread fork and builds its committed generated parser with mise Go. Nufmt is a pinned Git/Cargo tool. QMK uses PyPI; Vault and cargo-lambda use release binaries, avoiding unsupported/source-only Homebrew tap recipes. mermaid-ascii is the Devflow `show` DAG renderer: a standalone aqua/GitHub release binary, replacing the former checksum-pinned Graph-Easy CPAN archive and macOS Perl launcher.

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
├─ `mise -C "$DOTFILES" -E <mise-profile> run workstation:setup`
│   ├─ repositories/directories → dotty links
│   └─ Nushell init + audited Zsh completion cache
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

### [SPEC-006-S2.7] User Setup Handoff

`workstation:apply` explicitly runs `packages:apply` then `workstation:setup`. Setup runs repositories/directories → dotfiles → shell preparation, without services or system changes. Authentication and origin conflicts fail visibly; dirty repositories are reported and skipped. Existing unpinned repositories are not pulled.

Home Manager now retains only state metadata and baseline PATH. Keeping its activation lets the next system switch unlink the old generated shell and Pi package symlinks. New Nushell init files live at `~/.local/cache/dots/shell`, so user setup can be verified before that switch without replacing Nix-owned files. Direnv loads a pinned mise-provisioned nix-direnv checkout through the repo-owned `config/direnv/lib/nix-direnv.sh`.

For the initial handoff, run `packages:apply` → `make system` → `workstation:setup`. Afterwards, use `workstation:apply` for user-environment changes and rerun `shell:prepare` after a Nix switch or package upgrade. See [mise commands](../../docs/mise.md).

### [SPEC-006-S2.10] Darwin launchd Services

Mise owns the shared syncengine agent, the dev/work cc-notify and Git maintenance agents, and dev's backup-notes agent. Remaining Nix-owned services are tied to a workload or machine role and declared in the host module that wants them.

| Service | Declared in | Applies to | Notes |
| --- | --- | --- | --- |
| `syncengine` | `.mise/conf.d/syncengine.toml` | all macOS | mise-owned RunAtLoad agent; shared by dev/work services, standalone `syncengine:apply` on any profile |
| `git-maintenance-{hourly,daily,weekly}` | `.mise/conf.d/git-maintenance.toml` + profile overlay | dev, work | mise-owned LaunchAgents; filtered repository list, private state config |
| `cc-notify` | `.mise/conf.d/cc-notify.toml` + profile overlay | dev, work | mise-owned LaunchAgent; mise-managed Bun, explicit preparation before apply |
| `backup-notes` | `mise.dev.toml` | dev | mise-owned RunAtLoad agent; auto-commits and syncs the notes vault every 15 min |

Claude settings also live outside Nix: `.mise/conf.d/claude-code.toml` renders `templates/claude-settings.json.tera` with `mise -E dev run claude:apply` (or `work`). See [Claude settings](../../claude/README.md) for the apply workflow.

Syncengine, cc-notify, Git maintenance, and backup-notes have moved out of Nix; see [mise services](./mise-services.md). Homebrew and mise are installed by `boot/boot.sh`, and mise owns host packages; `make system` neither installs nor upgrades Homebrew packages. `make system` does not apply mise services; use `mise -E dev run services:apply` (or `work`) separately, or `mise -E <profile> run syncengine:apply` for syncengine alone. The remaining Nix-owned services retain their existing host declarations and activation hooks.

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

Portable shell environment ownership lives in `config/env/base.sh`; see [SPEC-009](./shell-environment.md). Mise supplies user packages; Nix/Home Manager retains system packages and pre-shell session seeds. The configured login shell is macOS `/bin/zsh`; nix-darwin's Zsh module is disabled so it installs neither another Zsh nor global Zsh startup files. The former shared terminfo packages and Nix CLI completions are no longer declared. Bash, zsh, Nushell, tmux, bootstrap, and containers consume the shared contract rather than maintaining independent PATH/environment lists.

| Variable            | Value                                                                           |
| ------------------- | ------------------------------------------------------------------------------- |
| `DOTFILES`          | `~/dev/dots` by default                                                         |
| `EDITOR`            | `nvim`                                                                          |
| `SHELL`             | macOS `/bin/zsh` for default/inherited Zsh; explicit other shells preserved     |
| `XDG_CONFIG_HOME`   | `~/.config` (macOS: `~/dev/dots/config` during bootstrap)                       |
| `XDG_DATA_HOME`     | `~/.local/share`                                                                |
| `XDG_STATE_HOME`    | `~/.local/state`                                                                |
| `XDG_CACHE_HOME`    | `~/.local/cache`                                                                |
| `CODEX_HOME`        | `~/.config/codex`                                                               |
| `JAVA_HOME`         | mise's `installs/java/temurin-21` symlink by default; preserved explicit values |
| `NPM_CONFIG_PREFIX` | `~/.local`                                                                      |

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

| Target        | Action                                                                         |
| ------------- | ------------------------------------------------------------------------------ |
| `make system` | Rebuild nix system via local `ct/nix.nu` from the current checkout             |
| `make link`   | Symlink dotfiles from the current checkout via `dotty link --no-cache`         |
| `make build`  | Install/check/build `oven/` tools via `mise -C oven run verify` (no Nix shell) |
| `make boot`   | Run `mise run boot`: workstation setup, Oven build, Claude settings, services  |
| `make all`    | `system` → `boot`, serialized even with `make -j`                              |

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

- **Shared-by-default profiles** — User tools and applications are shared through mise's common files. Profile overlays add hardware-specific QMK or work infrastructure tools. The Nix flake binds each host directly to its user and defines the shared Home Manager state version and baseline PATH inline; macOS defaults, Nix settings, and host-specific packages/services remain in Darwin host modules. Mise owns JVM tooling as well as other user tools.

- **Work boot profiles for username variants** — New work macOS machines may use `adam.hall` (dotted) or `adamhall`. All work outputs share `hosts/darwin/work.nix`; its `boot = true` parameter omits full-work packages and adds the bootstrap handoff message. Bootstrap supports both usernames with minimal work boot outputs. The full `work` output is intentionally single-user and only the current full-work username auto-promotes to it when workfiles exist; update `nix/flake.nix` and the rebuild wrapper's full-work username when the provisioned username changes.

- **Explicit mise service preparation** — cc-notify checkout/dependencies/credentials and Git maintenance registration are prepared by `mise -E dev run services:prepare` (or `work`), not Nix activation. Missing SSH access or credentials fails that explicit task before agents start. Shared syncengine preparation checks gitwatch and Homebrew dependencies and creates its log directory. Personal and work-boot profiles use `syncengine:apply` without installing cc-notify or Git maintenance.

- **Neovim-managed Tree-sitter parsers** — `nvim-treesitter` installs the configured language list into Neovim's writable data directory (`stdpath('data')/site`); Lazy runs `:TSUpdate` when the plugin changes. Mise supplies Homebrew Neovim and `tree-sitter-cli`, not grammars or queries. Compilation uses the macOS Command Line Tools C compiler. On first launch, let parser installation finish, then reopen buffers for highlighting; additional languages can be installed with `:TSInstall <language>`.

- **Generated shell init scripts** — `shell:prepare` generates and validates Atuin and Carapace Nushell init under `~/.local/cache/dots/shell`; the direnv hook is repo-owned. This avoids generation costs at shell startup and removes Nix-store executable references.

- **Single bootstrap entrypoint** — `boot/boot.sh` is the current entry point and handles macOS. Older shell-specific bootstrap scripts were removed to keep machine setup paths unambiguous.

- **One shell environment authority** — `config/env/base.sh` owns portable variables and baseline PATH. Nushell is the interactive layer and imports that contract; it no longer duplicates portable toolchain configuration.

- **XDG_CONFIG_HOME points to repo during bootstrap** — `boot.sh` sets `XDG_CONFIG_HOME="${DOTFILES}/config"` so tools find configs before dotty has run. The mise `dotfiles:apply` task links configs into `~/.config/`.

- **Current worktree preferred for rebuild commands** — The canonical clone path remains `~/dev/dots`, but flake-backed Nushell commands and the root `Makefile` prefer the current git worktree when it contains the expected repo structure. This allows testing changes from feature branches and linked worktrees without rewriting the base shell environment.

## [SPEC-006-S6] 6. Testing

### [SPEC-006-S6.1] Automated

- **Pre-commit hook** — Builds the flake on every commit touching `nix/`. Catches syntax errors, missing inputs, and evaluation failures before they reach remote.

### [SPEC-006-S6.2] Manual

- **`nix-smoke [profile]`** — Comprehensive health check verifying: PATH entries present, required binaries on PATH (including `pi`), config symlinks valid (including `~/.pi/agent/settings.json`), flake evaluates without error. Returns structured table of pass/fail results.
- **mise package checks** — `mise -E <profile> bootstrap packages apply --dry-run` previews host package changes and `mise -E <profile> run packages:status` reports installation state. The old Nix `nrs-check` brew validator was removed with Nix-owned Homebrew; `mise install` covers versioned tools only. All four mise overlays are previewed separately; Nix builds use `--no-link` and never switch the live system during validation.
