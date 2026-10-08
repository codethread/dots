# Git Worktrees Workflow

- Document ID: SPEC-004
- Configuration identification: SPEC-004; migrated from `specs/git-worktrees.md`; canonical path `devflow/specs/git-worktrees.md`.
- **Status:** Implemented
- **Last Updated:** 2026-10-08

## Scope

[Honeycomb](https://github.com/codethread/hive/tree/main/lib/honeycomb) owns worktree lifecycle behavior, safety checks, JSON contracts, and shell integration. Use `honeycomb -h` and subcommand help for the command reference; implementation docs and tests live in `~/dev/projects/hive/lib/honeycomb`.

This spec covers only the dotfiles wiring and local policy, not a second CLI contract.

## Integration

| Location | Responsibility |
| --- | --- |
| `mise.toml`, `boot/setup.sh` | Provision `~/dev/projects/hive` and run its default mise task, which builds `~/.local/bin/honeycomb`. |
| `config/env/base.sh` | Put `~/.local/bin` on the shared PATH. |
| `config/dotty/dotty.toml`, `config/honeycomb.toml` | Link the local policy to `~/.config/honeycomb.toml`. |
| `config/nushell/env.nu`, `config/nushell/config.nu` | Generate and import `honeycomb shell-init nu` for interactive shells. Noninteractive shells neither generate nor import the module. |
| `config/zsh/.zshrc` | Load `honeycomb shell-init zsh`, cache completions, and provide the `hc` alias. |
| `config/tmux/tmux.conf` | Bind prefix + `g` to Honeycomb's interactive picker with `--open`, scoped to the current pane's directory. |

The generated `wk` function is a picker, not a lifecycle-command wrapper. Humans use `honeycomb` (or Zsh's `hc`) for other commands; agents call `honeycomb` directly without `--interactive`.

## Local policy

`config/honeycomb.toml` is authoritative for nested worktree placement, add/finish defaults, personal-project dependency installation and cleanup, work VPN checks, and project-specific pool/copy/bootstrap settings. Keep those values in the config rather than duplicating them here. Hook variables `WK_ROOT` and `WK_CREATED` are part of Honeycomb's current interface.

Dotfiles can be edited on the canonical branch, so the dots project uses `origin_default` for add rather than requiring a clean canonical checkout. Its finish policy does not automatically push or remove worktrees/branches.

All merges, including `honeycomb finish`, use the per-target `qlock --merge-target` queue described in the shared agent instructions. Bootstrap and dotfile applies should run from a durable checkout because links and launchers embed checkout paths.

## Validation

Read-only checks from the dots checkout:

```nu
nu --config config/nushell/config.nu --env-config config/nushell/env.nu -c 'print ok'
honeycomb config explain --json
```

Engine and picker changes belong in Hive and use its own validation workflow.
