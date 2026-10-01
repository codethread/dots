#!/usr/bin/env bash
# Regression checks for the agent launcher ordering in the shared PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home=/tmp/dots-shell-env-path

for mode in default custom-agent mise-project; do
  env_args=()
  agent="$home/.pi/agent"
  prefix=""
  case "$mode" in
    custom-agent)
      agent="$home/custom pi"
      env_args+=("PI_CODING_AGENT_DIR=$agent")
      ;;
    mise-project)
      env_args+=(__MISE_DIFF=project-selected)
      prefix=/project/bin:/usr/bin:/bin:
      ;;
  esac
  output=$(env -i HOME="$home" USER=ct SHELL=/bin/bash DOTFILES="$ROOT" \
    PATH=/project/bin:/usr/bin:/bin "${env_args[@]}" /bin/bash -c '
      source "$DOTFILES/config/env/base.sh"
      first=$PATH
      source "$DOTFILES/config/env/base.sh"
      [[ $PATH == "$first" ]] || exit 1
      printf "%s" "$PATH"
    ')
  expected="$prefix$home/.local/bin:$agent/bin:$home/.local/share/mise/shims:"
  if [[ $output != "$expected"* ]]; then
    printf 'FAIL: %s PATH: expected prefix "%s", got "%s"\n' \
      "$mode" "$expected" "$output" >&2
    exit 1
  fi
done

printf 'shell environment PATH checks passed (3 cases, including repeat load)\n'
