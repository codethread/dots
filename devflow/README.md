# Devflow Workspace

This workspace contains durable planning artifacts for this repository. Root specs in `devflow/specs/` are canonical current contracts; RFCs in `devflow/rfcs/` capture decisions; active feature work belongs under `devflow/feat/<feat-name>/`; completed or abandoned feature folders move to `devflow/archive/`.

Persistent domain specifications. Organized by system area, not feature chronology.

**Rule:** specs describe intent, code describes reality. Always check the codebase before assuming a spec is fully implemented.

## Agentic

| Spec | Code | Purpose |
| --- | --- | --- |
| [SPEC-001 agentic-config](./specs/agentic-config.md) | `config/mise/`, `mise.toml`, `templates/claude-settings.json.tera`, `claude/`, `pi/`, `config/codex/`, `config/nushell/scripts/ct/interactive/{claude,pi}.nu`, `home/.local/bin/cl`, `oven/bin/cc-hook--*.ts`, `oven/shared/claude-hooks.ts`, `home/.local/bin/cc-hook--*` | Claude Code, Codex, and Pi global configuration: package provisioning, settings, hooks, agents, skills, plugins, wrappers (Note: much of the reusable Pi configuration has moved to the `agents` project repository) |

## Infrastructure

| Spec | Code | Purpose |
| --- | --- | --- |
| [Mise services](./specs/mise-services.md) | `mise.toml`, `.mise/dev-services.toml`, `.mise/conf.d/services.dev.toml`, `mise.{dev,work}.toml`, `boot/workfiles.sh`, `home/.local/bin/git-maintenance` | Shared/dev macOS LaunchAgents and the workfiles-owned work-service handoff |
| [SPEC-006 mise-infra](./specs/mise-infra.md) | `boot/{boot,setup,shell}.sh`, `Makefile`, `mise.toml`, `mise.<profile>.toml`, `.mise/conf.d/`, `.miserc.toml`, `config/env/base.sh`, `config/{bash,zsh,nushell}/` | Mise-owned macOS bootstrap and minimal system layer: Homebrew/mise install, identity profile resolution, login shell and Touch ID sudo, native shell activation |
| [SPEC-009 shell-environment](./specs/shell-environment.md) | `config/env/`, `config/{bash,zsh,nushell}/`, `config/tmux/tmux.conf`, `boot/{boot,setup,shell}.sh` | Shared Bash-authored environment and PATH contract with shell adapters |
| [SPEC-003 dotty](./specs/dotty.md) | `config/nushell/scripts/ct/dotty/`, `config/dotty/dotty.toml`, `config/nvim/lua/codethread/dotty.lua`, `Makefile`, `mise.toml` | General-purpose dotfile symlink manager: TOML-driven file and directory linking with caching and conflict resolution |
| [SPEC-007 theming](./specs/theming.md) | `oven/bin/theme.ts`, `config/kitty/kitty.conf`, `config/kitty/themes/`, `config/nushell/config.nu`, `config/nushell/scripts/ct/{themes,ls-colors}.nu`, `config/nvim/lua/codethread/theme.lua`, `config/nvim/lua/plugins/ui.lua` | Shared light/dark and theme-family control across macOS, Kitty, Nushell, and Neovim; other apps still future work |
| [SPEC-005 kitty-notifications](./specs/kitty-notifications.md) | `config/kitty/kitty.conf`, `config/kitty/notifications.py` | Kitty notification filtering for agent CLIs |
| [SPEC-004 git-worktrees](./specs/git-worktrees.md) | `config/ct-worktrees/trees.toml`, `config/nushell/config.nu`, `config/nushell/env.nu`, `/Users/adamhall/dev/projects/wktree` | Personal worktree workflow integration; implementation contract lives in the external `wktree` repo |
| [SPEC-008 worktree-concurrency](./specs/worktree-concurrency.md) | `home/.local/bin/dots-test-sandbox`, `config/nushell/scripts/ct/test/`, `Makefile`, `config/{dotty,nvim,tmux}/` | Planned isolation contract and test harness for concurrent dotfiles worktree development |
