#!/usr/bin/env bash

ORIG="$1"
# Select a window interactively
ID=$(kitten @ select-window --exclude-active)

# if ID is empty exit 0
if [ -z "$ID" ]; then
  exit 0
fi

kitten @ focus-window --match "id:$ID"

# Use launch to pipe the selected window's content to thumbs
# pass original nvim window to move focus
kitten @ launch --type=overlay --stdin-source=@screen thumb.sh "$ORIG"
