#!/usr/bin/env bash
# fzf runs inside a Rex floating terminal; arguments are passed without eval.
set -euo pipefail
input=$1
trap 'rm -f "$input"' EXIT
source "${XDG_CONFIG_HOME:-$HOME/.config}/env/base.sh"
client=$2
session=$3
block=$4
action=$5
prompt=$6
set +e
selected=$(fzf --no-multi --delimiter=$'\t' --with-nth=2.. --prompt="$prompt" < "$input")
status=$?
set -e
case $status in
  0) rex -C "$client" do -s "$session" -b "$block" "$action" "value=${selected%%$'\t'*}" ;;
  1|130) exit 0 ;;
  *) exit "$status" ;;
esac
