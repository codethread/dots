# Shared Shell Environment Specification

- Document ID: SPEC-009
- **Status:** Implemented
- **Last Updated:** 2026-10-07

## [SPEC-009-S1] Purpose

Provide one stable environment and PATH contract for login shells, human shells, agent CLIs, tmux, machine bootstrap, and development containers. On macOS, a fresh terminal uses the default login shell to construct the host baseline; on Linux, non-login terminals inherit it from the login session. Non-login child shells preserve the environment they inherit; Zsh is the default interactive shell and Nushell remains available.

## [SPEC-009-S2] Ownership

`config/env/base.sh` is the sole authority for portable scalar environment variables and the baseline PATH. It is intentionally sourced only by login profiles, machine bootstrap, or an explicitly clean tmux adapter. `config/env/interactive.sh` separately owns human-facing editor, history, pager, prompt cache, completion, and fuzzy-finder environment. Both are Bash-authored and intentionally source-compatible with zsh and POSIX sh.

Adapters may add shell-native state but must not duplicate the base contract:

| Consumer | Adapter |
| --- | --- |
| Bash login | `/etc/profile` runs first; `home/.bash_profile` sources the base, then `.bashrc`; `config/bash/env` adds interactive state and optional `env.local` only |
| zsh discovery/login | `home/.zshenv` sets only `ZDOTDIR`; after `/etc/zprofile`, `config/zsh/.zprofile` sources the base; `.zshrc` adds interactive state and mise activation |
| Bash/Zsh non-login children | Inherit the caller's environment and PATH; no adapter sources the base again |
| Nushell | `config/nushell/env.nu` preserves inherited state for noninteractive shells; interactive shells import `emit.sh --print0 --interactive`, convert PATH to a list, then add typed/Nushell-only values |
| terminal launch | Kitty uses its default shell launch behavior (login on macOS); Ghostty's `initial-command` runs `/bin/zsh -lic 'exec tmux new-session -A -s main'` in its first terminal only, loading login and interactive environment before creating or attaching the `main` tmux session; later terminals use the default shell |
| tmux | `emit.sh --tmux` runs the base in a clean subprocess, streams the result into the tmux global environment, and sets `default-shell` from the streamed `SHELL` |
| machine bootstrap | `boot/boot.sh` sets bootstrap-specific XDG roots, then sources the base |
| Carapace bridge | The isolated Bash rcfile loads saved completion wrappers and inherits the caller's environment; it does not source the base |

The macOS login environment and launchd may seed the minimum environment needed before a shell exists. Those platform declarations are adapters, not a second shell environment authority.

Ghostty's `initial-command` applies once per app launch, including its login-item launch. Later windows, tabs, and splits open normal shells. Closing the initial terminal does not repeat the command; quit and reopen Ghostty to run it again. A new tmux server inherits that shell's exported environment; the tmux adapter then applies the shared baseline below. Attaching to an existing server preserves its global environment and only refreshes the variables listed in `update-environment`. Ghostty must create the server first for other inherited values to originate there.

## [SPEC-009-S3] PATH Contract

The base constructs a login/bootstrap baseline from user-local tool roots, platform roots, system directories, explicit colon-separated `CT_PATH_EXTRA`, and inherited PATH without duplicates. The declared baseline wins and inherited entries are a trailing fallback. The base does not inspect mise's internal state.

A non-login child does not reconstruct this baseline. Its inherited PATH, including paths selected by `mise exec` or an interactive mise activation, remains in place. Starting a new login shell is therefore an explicit environment rebuild; use a non-login child when a nested command must preserve the current project environment.

Known user/tool roots remain in PATH even before they exist. Installing into one of those roots therefore works in the current shell; stale nonexistent entries are harmless and intentionally tolerated.

`~/.local/bin` remains first, preserving custom agent wrappers and native CLIs. `$PI_CODING_AGENT_DIR/bin` follows for Pi's official managed launcher, then mise shims, then Homebrew (including GNU coreutils), then other tool roots. mise supplies the default Node. Global mise configuration is linked from `config/mise/`, separate from project-scoped bootstrap resources. `JAVA_HOME` defaults to mise's stable `installs/java/temurin-21` symlink; explicit values are preserved, and `mise exec`/tasks supply the selected project JDK. Java binaries are selected through mise shims rather than an extra JDK PATH entry.

## [SPEC-009-S3a] SHELL Contract

On macOS, the base uses `/bin/zsh` when `SHELL` is unset or names Zsh, including inherited Homebrew or other Zsh paths. macOS supplies the only managed Zsh; PATH order must not select a different version. Explicit choices of other shells, such as `/bin/bash` from an agent CLI, are preserved. Elsewhere the default is `zsh` from PATH. The selected shell is resolved to an absolute executable path. If resolution fails, the base warns on stderr, leaves `SHELL` unchanged, and returns non-zero after restoring the caller's shell options. `emit.sh --tmux` passes the caller's `SHELL` into its clean subprocess and uses the resolved value as tmux's `default-shell`.

## [SPEC-009-S3b] Mise Environment

The base selects mise's machine package profile: `personal` for `codethread`, `work` for work accounts, and `dev` otherwise. An existing non-empty `MISE_ENV` is preserved; an explicit CLI `-E` still overrides the selection. Personal machines apply shared packages and syncengine only; work and dev machines also load their profile-specific services.

### [SPEC-009-S3c] Native mise Activation

Mise replaces direnv as the prompt-time project environment. `config/nushell/direnv.nu` and `config/direnv/` were removed:

- Interactive Bash (`config/bash/env`) and Zsh (`config/zsh/.zshrc`) evaluate the native `mise activate` hook; noninteractive shells do not.
- Nushell regenerates `mise.nu` on every **interactive** `env.nu` startup (`mise activate nu | save --force`), before `config.nu` imports it. Noninteractive Nushell never generates or imports the module.
- Mise shims remain the baseline for a process without an already-initialized project environment. Scripts and agents inherit their parent environment when one exists and use `mise exec -- <command>` or `mise run <task>` for project-selected tools.
- Automation that starts from a clean environment must initialize the base **before** invoking mise, rather than sourcing it after `mise exec` or relying on a login child to rebuild a project path:

    ```bash
    . "$DOTFILES/config/env/base.sh"
    exec mise exec -- <command>
    ```

- Projects declare tools and environment in their own `mise.toml` (`[tools]`, `[env]`, `_.file`, `_.path`); Nushell workflows use `mise trust`, `mise install`, and `mise exec`. `.envrc` files are not sourced automatically, and external projects are not rewritten.

## [SPEC-009-S4] Interfaces

```bash
source ~/.config/env/base.sh                 # explicit login/bootstrap baseline
/bin/sh ~/.config/env/emit.sh --print0       # serialize the inherited environment
/bin/sh ~/.config/env/emit.sh --print0 --interactive # plus interactive env
/bin/sh ~/.config/env/emit.sh --tmux         # clean baseline into tmux
```

`--print0` serializes the current inherited environment; it does not source the base. `--interactive` additionally sources `interactive.sh`, which is how interactive Nushell imports human-facing state without rebuilding PATH. NUL delimiters preserve spaces and shell syntax in values.

The tmux adapter evaluates the stable contract in a clean subprocess rather than copying its caller's interactive environment. It explicitly sources the base before emitting the stream, and takes both `SHELL` and `default-shell` from that stream. Transient client state remains tmux's `update-environment` responsibility; each new interactive shell constructs its own interactive additions. The adapter continues after an individual value exceeds tmux's command limit, but emits a warning naming the rejected variable. Shell/Nushell export is unaffected.

The base enables export-all only while loading, then restores the caller's setting. Both machine interfaces share one stream which excludes shell bookkeeping/internal `ct_*` variables. Nushell imports the complete interactive stream, then converts boolean conditions and PATH into native types. New base variables therefore propagate without a manifest.

## [SPEC-009-S5] Local and Secret State

`config/bash/env.local` is an optional, unmanaged machine-local override loaded by `config/bash/env` after interactive setup. It must not be generated from Nushell or used as a portable env snapshot. Transient values such as SSH agent sockets remain inherited from the launching client and are not part of the stable manifest.

## Zsh completion lifecycle

`boot/shell.sh`, called by the bootstrap setup hook, generates the completion cache after packages and dotfile links are installed. `mise bootstrap` runs the hook, so the scan reflects the current system. The helper inherits the environment supplied by its caller; it does not source the base itself.

`config/zsh/completion-path.zsh` is shared by `config/zsh/cache-completions.zsh` and interactive startup. It keeps the running Zsh's built-in function directories and adds Homebrew site completions, not another Zsh installation's versioned functions. Preparation explicitly uses macOS `/bin/zsh`, matching terminal/tmux startup. It audits those paths as the user, builds a fresh dump even if the completion file count is unchanged, and atomically replaces each cache file under `$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION`. Stale dumps for other Zsh versions are removed after publication. Insecure paths fail preparation without replacing the old cache.

Interactive shells use `compinit -C`: completion discovery and security checks happen during explicit preparation, not on every launch. Completion files remain live on disk. Rerun `mise bootstrap` after macOS/package upgrades. Missing caches produce a warning and audited, uncached initialization.

Nushell sources Atuin and Carapace init files generated into `~/.local/cache/dots/shell`, and imports the mise activation module generated at interactive startup ([SPEC-009-S3c]). Interactive Bash and Zsh evaluate the native mise hook. The `mise-llm` helper, `boot/shell.sh`, and Carapace bridge all preserve the environment supplied by their caller rather than sourcing the base.

Starship, fzf, and Atuin init scripts are cached separately by resolved executable path. Startup generates into temporary files and publishes the init script and path stamp only after the generator succeeds. A failed generator returns failure without sourcing partial output or replacing the previous cache, so the next launch retries. Empty init caches are regenerated as well.

## [SPEC-009-S6] Validation

```nu
for file in [config/env/base.sh config/env/emit.sh config/env/interactive.sh config/bash/env home/.bash_profile home/.bashrc] {
    bash -n $file
}
for file in [config/env/base.sh config/env/interactive.sh home/.zshenv config/zsh/.zprofile config/zsh/.zshrc] {
    zsh -n $file
}
nu -c 'nu-check --debug /abs/path/config/nushell/env.nu'
nu --config config/nushell/config.nu --env-config config/nushell/env.nu -c 'print ok'
tmux source-file -n config/tmux/tmux.conf
```
