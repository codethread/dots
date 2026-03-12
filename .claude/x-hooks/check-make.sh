#!/usr/bin/env bash

# Run `make` and ask the agent to fix errors if appropriate
# This hook runs once per Stop event to avoid endless loops

# Read input from stdin
command -v jq >/dev/null 2>&1 || exit 0
command -v make >/dev/null 2>&1 || exit 0
input=$(cat)

# Parse the JSON input to check if this is already from a stop hook
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')

# If we're already in a stop hook, exit silently to prevent loops
if [ "$stop_hook_active" = "true" ]; then
    exit 0
fi

# run make (link + build only; system requires sudo which can't run non-interactively)
make link build >&2 || exit 2
