#!/usr/bin/env bash
#:module: Small kitty terminal action menu
set -euo pipefail

# Define menu items as "description|command" pairs.
# Keep this terminal-focused; tmux owns multiplexing/session actions.
menu_items=(
    "Opacity solid        | kitten @ action set_background_opacity 1"
    "Opacity transparent  | kitten @ action set_background_opacity 0.85"
    "Reload kitty config  | kitten @ action load_config_file"
    "Show kitty env vars  | kitten @ action show_kitty_env_vars"
    "Debug kitty config   | kitten @ action debug_config"
    "Show key mappings    | kitty kitten show-key"
    "Show kitty mappings  | kitty kitten show-key -m kitty"
)

# Extract descriptions and commands for fzf display
menu_display=()
for item in "${menu_items[@]}"; do
    description="${item%%|*}"  # Everything before first |
    description="${description## }"  # Trim leading spaces
    description="${description%% }"  # Trim trailing spaces
    
    command="${item#*|}"  # Everything after first |
    command="${command## }"  # Trim leading spaces
    command="${command%% }"  # Trim trailing spaces
    
    # Format: description in normal color, command in dim gray
    # Use printf to generate ANSI codes
    dim_start=$(printf '\033[2m')
    reset=$(printf '\033[0m')
    menu_display+=("$description → ${dim_start}${command}${reset}")
done

# Use fzf to select, with ANSI colors enabled and extract just the description part
selected_line=$(printf '%s\n' "${menu_display[@]}" \
  | fzf --prompt="Select action: " --margin=2 --height=60% --ansi --color="hl:bright-blue,hl+:bright-blue")

# Extract the description part (everything before the arrow)
selected_description="${selected_line%% →*}"

# Find the matching command and execute it
if [[ -n "$selected_description" ]]; then
    for item in "${menu_items[@]}"; do
        description="${item%%|*}"  # Everything before first |
        description="${description## }"  # Trim leading spaces
        description="${description%% }"  # Trim trailing spaces
        if [[ "$description" == "$selected_description" ]]; then
            command_to_run="${item#*|}"  # Everything after first |
            command_to_run="${command_to_run## }"  # Trim leading spaces
            command_to_run="${command_to_run%% }"  # Trim trailing spaces
            echo "Running: $command_to_run"
            eval "$command_to_run"
            break
        fi
    done
fi
