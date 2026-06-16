# Specifications

Persistent domain specifications. Organized by system area, not feature chronology.

**Rule:** specs describe intent, code describes reality. Always check the codebase before assuming a spec is fully implemented.

## Agentic

| Spec | Code | Purpose |
|---|---|---|
| [agentic-config.md](./agentic-config.md) | `nix/flake.nix`, `nix/features/common.nix`, `nix/features/claude-code.nix`, `claude/`, `pi/`, `config/codex/`, `config/nushell/scripts/ct/interactive/{claude,pi}.nu`, `home/.local/bin/cl`, `oven/bin/cc-hook--*.ts`, `oven/shared/claude-hooks.ts`, `home/.local/bin/cc-hook--*` | Claude Code, Codex, and Pi global configuration: package provisioning, settings, hooks, agents, skills, plugins, wrappers (Note: much of the reusable Pi configuration has moved to the `agents` project repository) |
| [cc-sandbox.md](./cc-sandbox.md) | `home/.local/bin/cc-sandbox`, `home/.local/share/cc-sandbox/`, `oven/bin/cc-bridge.ts`, `config/nushell/scripts/ct/interactive/claude.nu` | Podman container isolation for headless Claude Code and Codex sessions |

## Infrastructure

| Spec | Code | Purpose |
|---|---|---|
| [nix-infra.md](./nix-infra.md) | `nix/`, `boot/`, `config/nushell/scripts/ct/nix.nu`, `config/nushell/scripts/ct/nixos.nu`, `.githooks/pre-commit` | Declarative system configuration and bootstrap for macOS and NixOS machines |
| [dotty.md](./dotty.md) | `config/nushell/scripts/ct/dotty/`, `config/dotty/dotty.toml`, `config/nvim/lua/codethread/dotty.lua`, `Makefile`, `nix/features/common.nix` | General-purpose dotfile symlink manager: TOML-driven file and directory linking with caching and conflict resolution |
| [theming.md](./theming.md) | `home/.local/bin/theme`, `config/kitty/kitty.conf`, `config/kitty/themes/`, `config/nushell/config.nu`, `config/nushell/scripts/ct/{themes,ls-colors}.nu`, `config/nvim/lua/codethread/theme.lua`, `config/nvim/lua/plugins/ui.lua` | Shared light/dark and theme-family control across macOS, Kitty, Nushell, and Neovim; Nix/NixOS and other apps still future work |
| [kitty-notifications.md](./kitty-notifications.md) | `config/kitty/kitty.conf`, `config/kitty/notifications.py` | Kitty notification filtering for agent CLIs |
| [git-worktrees.md](./git-worktrees.md) | `config/ct-worktrees/trees.toml`, `config/nushell/config.nu`, `config/nushell/env.nu`, `/Users/adamhall/dev/projects/wktree` | Personal worktree workflow integration; implementation contract lives in the external `wktree` repo |
| [worktree-concurrency.md](./worktree-concurrency.md) | `home/.local/bin/dots-test-sandbox`, `config/nushell/scripts/ct/test/`, `Makefile`, `config/{dotty,nvim,tmux}/` | Planned isolation contract and test harness for concurrent dotfiles worktree development |
