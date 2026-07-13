#!/bin/sh
# Machine adapters for the shared environment contract.

. "${DOTFILES:-$HOME/dev/dots}/config/env/base.sh"

ct_env_stream0() {
  # Bash provides NUL-delimited read support missing from portable sh.
  /usr/bin/env -0 | bash -c '
    while IFS= read -r -d "" entry; do
      key=${entry%%=*}
      case "$key" in
        PWD|OLDPWD|FILE_PWD|CURRENT_FILE|SHLVL|_|ct_*) continue ;;
      esac
      printf "%s\0" "$entry"
    done
  '
}

case "${1:-}" in
  --print0)
    if [ "${2:-}" = --interactive ]; then
      . "$DOTFILES/config/env/interactive.sh"
    elif [ -n "${2:-}" ]; then
      printf 'usage: %s --print0 [--interactive]\n' "$0" >&2
      exit 2
    fi
    ct_env_stream0
    ;;
  --tmux)
    /usr/bin/env -i \
      HOME="$HOME" \
      USER="$USER" \
      DOTFILES="$DOTFILES" \
      PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      /bin/sh "$DOTFILES/config/env/emit.sh" --print0 | bash -c '
      while IFS= read -r -d "" entry; do
        key=${entry%%=*}
        value=${entry#*=}
        if (( ${#value} > 12000 )); then
          printf "warning: tmux skipped oversized environment variable: %s\n" "$key" >&2
          continue
        fi
        if ! tmux set-environment -g "$key" "$value"; then
          printf "warning: tmux could not import environment variable: %s\n" "$key" >&2
        fi
      done
    '
    tmux set-option -g default-shell "$SHELL"
    ;;
  *)
    printf 'usage: %s {--print0 [--interactive]|--tmux}\n' "$0" >&2
    exit 2
    ;;
esac
