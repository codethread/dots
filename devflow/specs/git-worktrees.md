# Git Worktrees Workflow

- Document ID: SPEC-004
- Configuration identification: SPEC-004; migrated from `specs/git-worktrees.md`; canonical path `devflow/specs/git-worktrees.md`.
- **Status:** Implemented
- **Last Updated:** 2026-11-08

## Scope

[wktree](https://github.com/codethread/wktree) owns worktree lifecycle behavior, safety checks, JSON contracts, and shell integration. Use `wktree -h` and subcommand help for the command reference; implementation docs and tests live in its upstream repository.

This spec covers only the dotfiles wiring and local policy, not a second CLI contract. Root `mise.toml` provisions the `codethread/wktree/wktree` Homebrew package; dots does not clone or build the engine.

## Integration

| Location | Responsibility |
| --- | --- |
| `config/wktree.toml`, `config/dotty/dotty.toml` | Dotty's `config` project links the global policy to `~/.config/wktree.toml`. |
| `config/nushell/env.nu`, `config/nushell/config.nu` | Generate and import `wktree shell-init nu` as `wktree.nu` for interactive shells. Noninteractive shells neither generate nor import the module. |
| `config/zsh/.zshrc` | Evaluate `wktree shell-init zsh` to provide the `wk` picker. |
| `config/tmux/tmux.conf` | Bind prefix + `g` to wktree's interactive picker with `--open`, scoped to the current pane's directory. |
| `mise.toml` | Install the `codethread/wktree/wktree` Homebrew package. |

The generated `wk` function is a picker, not a lifecycle-command wrapper. Humans and agents use `wktree` for lifecycle commands; agents call it directly without `--interactive`.

## Local policy

`config/wktree.toml` is authoritative for nested worktree placement, add/finish defaults, personal-project dependency installation and cleanup, work VPN checks, and project-specific pool/copy/bootstrap settings. Keep those values in the config rather than duplicating them here. Hook variables `WK_ROOT` and `WK_CREATED` are part of wktree's command interface.

Dotfiles can be edited on the canonical branch, so the dots project uses `origin_default` for add rather than requiring a clean canonical checkout. Its finish policy does not automatically push or remove worktrees/branches.

All merges, including `wktree finish`, use the per-target `qlock --merge-target` queue described in the shared agent instructions. Bootstrap and dotfile applies should run from a durable checkout because links and launchers embed checkout paths.

## Validation

Read-only checks from the dots checkout:

```nu
nu --config config/nushell/config.nu --env-config config/nushell/env.nu -c 'print ok'
wktree config explain --json
```

Engine and picker changes belong in wktree and use its own validation workflow.
