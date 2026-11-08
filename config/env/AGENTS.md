# Environment contract

Keep `base.sh` and `interactive.sh` sourceable by POSIX sh, Bash, and Zsh. Human-facing additions belong only in `interactive.sh`. Preserve caller overrides with `${NAME:-default}` except for repository-owned invariants.
