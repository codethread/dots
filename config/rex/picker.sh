#!/usr/bin/env bash
# fzf runs inside a Rex floating terminal; arguments are passed without eval.
set -euo pipefail
input=$1
trap 'rm -f "$input" "$input.recent"' EXIT
source "${XDG_CONFIG_HOME:-$HOME/.config}/env/base.sh"
client=$2
session=$3
block=$4
action=$5
prompt=$6
options=(--with-nth=2..)
if [[ ${7:-} == worktrees ]]; then
  LC_ALL=C sort -t $'\t' -k3,3 -o "$input" "$input"
  LC_ALL=C sort -t $'\t' -k2,2nr -k3,3 "$input" > "$input.recent"
  export REX_PICKER_INPUT="$input"
  options=(
    --with-nth=3.. --no-sort
    --header='Tab: toggle A-Z / recent commit'
    --bind='tab:transform:
      case "$FZF_PROMPT" in
        *A-Z*) echo "change-prompt(Worktree recent> )+reload(cat \"$REX_PICKER_INPUT.recent\")" ;;
        *) echo "change-prompt(Worktree A-Z> )+reload(cat \"$REX_PICKER_INPUT\")" ;;
      esac'
  )
fi
set +e
selected=$(fzf --no-multi --delimiter=$'\t' "${options[@]}" --prompt="$prompt" < "$input")
status=$?
set -e
case $status in
  0) rex -C "$client" do -s "$session" -b "$block" "$action" "value=${selected%%$'\t'*}" ;;
  1|130) exit 0 ;;
  *) exit "$status" ;;
esac
