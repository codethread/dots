# Environment contract

- `base.sh` is stable login state inherited by terminals, shells, agents, tmux, and services; `interactive.sh` contains only human-facing interactive state.
- Keep both sourceable by Bash, Zsh, and POSIX sh as declared in their headers. Avoid shell-specific syntax in sourced paths.
- Preserve explicit caller overrides with `${NAME:-default}` unless the variable is a repository-owned invariant.
- `emit.sh --tmux` rebuilds a clean baseline before importing it into tmux; do not make it depend on an interactive shell startup file.
- Validate changed files with every available declared shell using [the verification guide](../../docs/verification.md#shell-environment-and-helpers).
