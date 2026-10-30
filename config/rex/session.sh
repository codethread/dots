#!/usr/bin/env bash
# Run project/slot operations on the same host as the session's terminals.
set -euo pipefail
source ~/.config/env/base.sh
operation=$1
block=$2
value=${3:-}
script=~/.config/rex/session.lua

run() {
  rex do "$script" "action=$1" "block=$block" "value=${2:-}"
}

case $operation in
  edit)
    run ensure >/dev/null
    exec env NVIM_APPNAME=minimal-nvim "${EDITOR:-nvim}" ~/.local/cache/rex-slots
    ;;
  projects|slots|tabs)
    rows=$(run "$operation" | fx '.values.join("\n")')
    set +e
    selected=$(printf '%s\n' "$rows" | fzf --no-multi --delimiter=$'\t' --with-nth=2.. --prompt="$operation: ")
    status=$?
    set -e
    case $status in
      0) ;;
      1|130) exit 0 ;;
      *) exit "$status" ;;
    esac
    if [[ $operation == tabs ]]; then
      run focus_tab "${selected%%$'\t'*}"
    else
      run open "${selected%%$'\t'*}"
    fi
    ;;
  *) run "$operation" "$value" ;;
esac
