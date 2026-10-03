# Mise Infrastructure Specification

- Document ID: SPEC-006
- Configuration identification: SPEC-006; canonical path `devflow/specs/mise-infra.md`; replaces the retired `specs/nix-infra.md`.
- **Status:** Implemented
- **Last Updated:** 2026-10-03

## [SPEC-006-S1] 1. Overview

### [SPEC-006-S1.1] Purpose

Mise owns this repository's macOS workstation layer: bootstrap, host packages, the minimal privileged system configuration, user setup, shell activation, and launchd services. nix-darwin and Home Manager were retired; the `nix/` tree, `ct/nix.nu` helpers, `make system`, and the pre-commit flake build were removed with them.

### [SPEC-006-S1.2] Goals

- One-command bootstrap for new Apple Silicon machines without Nix
- Homebrew and mise installed before any clone or Nix dependency
- One profile resolver shared by bootstrap, shells, and tasks
- Minimal privileged state through generic mise managed files
- Native mise shell activation as the prompt-time project environment
- A documented, failure-tolerant Nix uninstallation path

### [SPEC-006-S1.3] Non-Goals

- CI/CD pipeline — validation is local (pre-commit formatting and smoke checks)
- Linux workstations — `boot.sh` supports Apple Silicon macOS only
- Secrets management — no vault, sops, or agenix
- Removing leftover Nix syntax/filetype support from editors

## [SPEC-006-S2] 2. Architecture

### [SPEC-006-S2.1] Ownership

| Layer | Owner | Declarations |
| --- | --- | --- |
| Bootstrap | `boot/boot.sh` | Homebrew install, mise install, clone, profile selection, `mise run boot`, `nu boot machine` |
| Host packages | mise | `.mise/conf.d/packages.toml` plus `mise.<profile>.toml` overlays |
| System layer | mise | `.mise/conf.d/macos-system.toml`: login shell and `/etc/pam.d/sudo_local` |
| User setup | mise | `.mise/conf.d/workstation.toml`, `.mise/conf.d/macos-defaults.toml`, `.mise/conf.d/claude-code.toml` |
| Services | mise | `.mise/conf.d/{syncengine,cc-notify,git-maintenance}.toml` plus overlays; see [mise-services](./mise-services.md) |
| Shell activation | mise + repo config | `config/bash/env`, `config/zsh/.zshrc`, `config/nushell/env.nu`, `config/nushell/config.nu` |
| Environment base | repo | `config/env/base.sh`; see [shell-environment](./shell-environment.md) |

Shared host packages include agent-browser, pngpaste, yazi, flock, Clojure, and `pam-reattach`; `nixfmt` and `direnv` were removed. Homebrew Bash is explicit because scripts such as `qlock` require Bash 5+ features (macOS ships 3.2); `/bin/zsh` remains the login shell. Bitwarden CLI is limited to the work and work-boot overlays.

### [SPEC-006-S2.2] Bootstrap Flow

```
boot/boot.sh [-p <dev|personal|work|work-boot>] [-b <branch>]
├─ Require Apple Silicon macOS
├─ Install Homebrew with the official installer
│   (also prepares Apple Command Line Tools, including Git)
├─ brew install mise
├─ Clone codethread/dots (SSH when ~/.ssh exists, else HTTPS)
├─ Set bootstrap XDG roots and source config/env/base.sh
├─ Select profile: explicit -p, else preserved MISE_ENV, else identity
├─ mise trust + mise -E <profile> run boot
│   ├─ packages:apply          versioned tools, Homebrew, agent CLIs, npm, VS Code
│   ├─ system:apply            login shell + sudo_local
│   ├─ repositories:apply      managed files/dirs, repos, dotty links
│   ├─ hive:update, agents:update
│   ├─ dotfiles:apply, shell:prepare, macos:apply
│   ├─ oven verify             build/check CLI tools
│   ├─ claude:apply            render settings
│   └─ services:apply          or syncengine:apply on personal/work-boot
└─ nu boot machine             Full Disk Access check, Oven binaries, nvim plugins
```

`work-boot` prints the follow-up step: install workfiles, then `mise -E work run boot`. The script is rerunnable after a failure.

### [SPEC-006-S2.3] Existing Machine

```
make / make all / make boot
└─ mise -C <checkout> run boot   (same task path as above)
```

There is no `make system`; `nrs`, `nfu`, `nrs-check`, `nix-smoke`, and `nix-clean*` were removed with nix-darwin. `make link` and `make build` remain unchanged.

### [SPEC-006-S2.4] System Layer (`macos-system.toml`)

- `bootstrap.user.login_shell = "/bin/zsh"` keeps the macOS-managed Zsh as the login shell.
- `system:apply` requires Darwin, checks for `/etc/pam.d/sudo_local.template` (macOS 14+) and `/opt/homebrew/lib/pam/pam_reattach.so` (from `packages:apply`), and refuses to run while `/etc/pam.d/sudo_local` is a symlink. It then runs `mise bootstrap user apply --yes` and a scoped `mise bootstrap files apply --yes`.
- `/etc/pam.d/sudo_local` is managed as `root:wheel`, mode `0644`, with an optional `pam_reattach` line followed by a sufficient `pam_tid` line, enabling Touch ID inside tmux/screen while retaining the password fallback.
- The file uses mise's generic managed-file support (atomic write); there is no PAM-specific API and no remote privileged script. Deliberately no `replace = true`: an old nix-darwin symlink fails visibly and must be retired first, per [Retiring Nix](../../docs/mise.md#retiring-nix).
- `system:status` reports `mise bootstrap user status` and the scoped managed-file status.
- `workstation:setup` runs `system:apply` before `repositories:apply`, so the privileged layer is in place before user setup continues.

### [SPEC-006-S2.5] Shell Activation and Project Environments

Native mise activation replaces direnv:

- Interactive Bash and Zsh evaluate `mise activate <shell>` in their rc files via `config/bash/env` and `config/zsh/.zshrc`.
- Nushell regenerates the activation module on every **interactive** `env.nu` startup (`mise activate nu | save --force`), before `config.nu` imports it. Noninteractive Nushell never generates or imports it and relies on shims.
- Mise shims remain the noninteractive baseline; scripts use `mise exec` or `mise run` for project-selected tools.
- Project environments are declared in a project's own `mise.toml` through `[tools]` and `[env]`, including `_.file` and `_.path`. Nushell workflows use `mise trust`, `mise install` (versioned tools only), and `mise exec -- <command>`.
- `.envrc` files are not sourced automatically. This repository does not rewrite external projects; they convert to `mise.toml` deliberately when needed.
- Editor Nix syntax support may remain for reading old files; no Nix runtime or daemon is required.

## [SPEC-006-S3] 3. Data Model

### [SPEC-006-S3.1] Profile Resolution

`config/env/base.sh` is the single resolver. An explicit CLI `-E` overrides it; an existing non-empty `MISE_ENV` is preserved; `boot.sh -p` sets it explicitly.

| Username | Condition | Profile |
| --- | --- | --- |
| `codethread` | — | `personal` |
| `adamhall` | `$HOME/pb/adam.hall/workfiles` exists | `work` |
| other work accounts (`adam.hall`, or `adamhall` without workfiles) | — | `work-boot` |
| everyone else | — | `dev` |

Only the current full-work username (`adamhall`) auto-promotes to `work` once workfiles exist; `adam.hall` remains on `work-boot` even with workfiles. Both work bootstrap usernames use the `work-boot` mise environment, and the former Nix-only `work-adamhall-boot` output no longer exists. `work-boot` machines can move to the full work overlay with `mise -E work run boot` once workfiles are installed.

### [SPEC-006-S3.2] Environment Variables

`config/env/base.sh` owns the portable contract (see [SPEC-009](./shell-environment.md)). Bootstrap additionally sets `XDG_CONFIG_HOME` to the repo's `config/` until dotty links `~/.config`, and `DOTFILES` to the checkout path. `JAVA_HOME` points at mise's `temurin-21` install symlink unless explicitly set.

## [SPEC-006-S4] 4. Interfaces

| Command | Purpose |
| --- | --- |
| `boot/boot.sh [-p profile] [-b branch]` | New-machine bootstrap; rerunnable |
| `make`, `make all`, `make boot` | Existing-machine `mise run boot` |
| `make link` | `dotty link --force --no-cache` from the current checkout |
| `make build` | `mise -C oven run verify` |
| `mise -E <profile> run packages:apply` / `packages:status` | Host packages and tools |
| `mise -E <profile> run system:apply` / `system:status` | Login shell and sudo Touch ID file |
| `mise -E <profile> run workstation:apply` / `workstation:setup` | User environment without services |
| `mise -E dev run services:apply` / `-E work` | Full service set on dev/work |
| `mise -E <profile> run syncengine:apply` | Syncengine only (all macOS profiles) |

## [SPEC-006-S5] 5. Design Decisions

- **No Nix runtime** — Nix, nix-darwin, Lix, Home Manager, nix-direnv, and the `nix/` tree no longer participate in the contract. Nix filetype syntax in editors may persist; runtime ownership does not.

- **Homebrew and mise before clone** — `boot.sh` uses the official Homebrew installer (which also prepares Command Line Tools/Git) and `brew install mise` before touching the checkout, so bootstrap has no Nix or preinstalled-Git dependency. Apple Silicon only.

- **Generic managed files for privileged state** — login shell and `sudo_local` use `bootstrap.user` and `bootstrap.files` rather than a PAM-specific API or a downloaded privileged script. Atomic write, explicit ownership and mode, and a visible refusal when a foreign symlink owns the path.

- **Retirement over replacement** — no `replace = true` on `sudo_local`; an existing nix-darwin symlink must be retired first (see [Retiring Nix](../../docs/mise.md#retiring-nix)). The Nix store is removed with its installer, never `rm -rf /nix`, and only after `system:apply` and sudo/Touch ID verification succeed.

- **Identity-based profiles, one resolver** — shell, bootstrap, and tasks share `config/env/base.sh`; no separate Nix profile mapping remains.

- **Durable checkout** — service and agent tasks generate absolute paths, so apply from the canonical checkout rather than a disposable worktree.

## [SPEC-006-S6] 6. Testing

Automated/local validation:

- `bash -n boot/boot.sh config/env/base.sh config/env/emit.sh`
- `zsh -n config/env/base.sh config/env/interactive.sh config/zsh/.zshenv`
- `nu -c 'nu-check --debug /abs/path/config/nushell/env.nu'` and a real config load
- `mise -E <profile> tasks validate --errors-only` for dev/work/personal/work-boot
- `mise -E dev bootstrap packages apply --dry-run` and `mise -E dev run packages:status`
- `mise -E dev run system:status` after `system:apply`

Live verification and remaining manual paths:

- The dev Mac mini completed Nix retirement on 2026-10-03: mise-managed password sudo worked in a normal terminal and tmux; the Nix volume and old jobs were removed; boot, 135 tests, typecheck and build passed. Touch ID lacked suitable hardware and remains untested, as do the other machines. Follow the [Apple Silicon migration guide](../../docs/nix-to-mise.md), including copying the installer and full receipt outside the Nix volume before uninstalling.
- A fresh-machine bootstrap can be smoke-checked with `boot.sh --help` and shell parsing; a full run is destructive by nature and remains manual.
