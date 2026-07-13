# Shared Shell Environment Specification

Document ID: SPEC-009
**Status:** Implemented
**Last Updated:** 2026-07-13

## [SPEC-009-S1] Purpose

Provide one stable environment and PATH contract for human shells, agent CLIs,
tmux, machine bootstrap, and development containers. Nushell remains the primary
interactive shell, but does not own portable process environment configuration.

## [SPEC-009-S2] Ownership

`config/env/base.sh` is the sole authority for portable scalar environment
variables and baseline PATH ordering. `config/env/interactive.sh` separately owns
human-facing editor, history, pager, prompt cache, completion, and fuzzy-finder
environment. Both are Bash-authored and intentionally source-compatible with zsh
and POSIX sh.

Adapters may add shell-native state but must not duplicate the base contract:

| Consumer | Adapter |
|---|---|
| Bash | `config/bash/env` sources the base, adds interactive state only for interactive shells, then optional `env.local` |
| zsh | `config/zsh/.zshenv` sources the base; `.zshrc` adds interactive state |
| Nushell | `config/nushell/env.nu` imports the base plus interactive state only when `$nu.is-interactive`, converts PATH to a list, then adds typed/Nushell-only values |
| terminal launch | `config/env/terminal-startup.sh` sources the base, then execs login Nushell |
| tmux | `emit.sh --tmux` seeds the tmux global environment and default shell |
| machine bootstrap | `boot/boot.sh` sets bootstrap-specific XDG roots, then sources the base |

Nix/Home Manager and launchd may seed the minimum environment needed before a
shell exists. Those platform declarations are adapters, not a second shell
environment authority.

## [SPEC-009-S3] PATH Contract

The base builds PATH from user-local tool roots, Nix profiles, platform roots,
system directories, explicit colon-separated `CT_PATH_EXTRA`, and inherited PATH
without duplicates. Normally the declared base wins and inherited entries are a
trailing fallback. Inside `nix develop` (`IN_NIX_SHELL`) or direnv
(`DIRENV_DIR`), inherited project paths win so pinned toolchains survive a nested
shell startup.

Known user/tool roots remain in PATH even before they exist. Installing into one
of those roots therefore works in the current shell; stale nonexistent entries
are harmless and intentionally tolerated.

`~/.local/bin` remains first. Volta remains available for interactive Node work.
On macOS, Homebrew Node is the stable fallback when a replaced HOME makes Volta
unavailable.

## [SPEC-009-S4] Interfaces

```bash
source ~/.config/env/base.sh                 # Bash/zsh/process environment
/bin/sh ~/.config/env/emit.sh --print0       # NUL-delimited KEY=VALUE contract
/bin/sh ~/.config/env/emit.sh --print0 --interactive # plus interactive env
/bin/sh ~/.config/env/emit.sh --tmux         # seed current tmux server
```

The tmux adapter evaluates the stable contract in a clean subprocess rather than
copying its caller's interactive environment. Transient client state remains
tmux's `update-environment` responsibility; each new interactive shell constructs
its own interactive additions. The adapter continues after an individual value
exceeds tmux's command limit, but emits a warning naming the rejected variable.
Shell/Nushell export is unaffected.

`--print0` is machine-facing: NUL delimiters preserve spaces and shell syntax in
values. The base enables export-all only while loading, then restores the caller's
setting. Both machine interfaces share one stream which excludes only shell
bookkeeping/internal `ct_*` variables. Nushell imports the complete stream, then
converts boolean conditions and PATH into native types. New base variables
therefore propagate without a manifest.

## [SPEC-009-S5] Local and Secret State

`config/bash/env.local` is an optional, unmanaged machine-local override loaded
after the base. It must not be generated from Nushell or used as a portable env
snapshot. Transient values such as SSH agent sockets remain inherited from the
launching client and are not part of the stable manifest.

## [SPEC-009-S6] Validation

```bash
bash -n config/env/base.sh config/env/emit.sh config/env/terminal-startup.sh
zsh -n config/env/base.sh config/env/interactive.sh config/zsh/.zshenv
nu -c 'nu-check --debug /abs/path/config/nushell/env.nu'
nu --config config/nushell/config.nu --env-config config/nushell/env.nu -c 'print ok'
tmux source-file -n config/tmux/tmux.conf
```
