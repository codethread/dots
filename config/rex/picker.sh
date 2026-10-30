#!/usr/bin/env bash
# fzf runs inside a Rex floating terminal; arguments are passed without eval.
set -euo pipefail
source ~/.config/env/base.sh
input=$1
client=$2
action=$3
prompt=$4
trap 'rm -f "$input"' EXIT
set +e
selected=$(fzf --no-multi --delimiter=$'\t' --with-nth=2.. --prompt="$prompt" < "$input")
status=$?
set -e
case $status in
  0) rex -C "$client" do "$action" "value=${selected%%$'\t'*}" ;;
  1|130) exit 0 ;;
  *) exit "$status" ;;
esac
