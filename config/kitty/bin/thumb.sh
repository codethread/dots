#!/usr/bin/env bash

OPTIONAL_ORIGIN=$1

if ! thumbs --regexp "[^:]+:\d+:\d+:" -u -t /tmp/thumbs.txt; then
  # no selection was made
  if [ -n "$OPTIONAL_ORIGIN" ]; then
    kitten @ focus-window --match "id:$OPTIONAL_ORIGIN"
  fi
  exit 0
fi

if command -v pbcopy >/dev/null 2>&1; then
  pbcopy </tmp/thumbs.txt &
elif command -v wl-copy >/dev/null 2>&1; then
  wl-copy </tmp/thumbs.txt &
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard </tmp/thumbs.txt &
fi

~/.config/kitty/bin/open-in-vim.sh "$(</tmp/thumbs.txt)"
