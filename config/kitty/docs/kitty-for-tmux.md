# Kitty for tmux Users: Architecture and API Mapping

This document maps tmux concepts to kitty equivalents and explains how to programmatically control kitty, similar to how you might use tmux's API.

## Architecture Comparison

### tmux → kitty Terminology

| tmux Concept | kitty Equivalent | Description                                                      |
| ------------ | ---------------- | ---------------------------------------------------------------- |
| **Session**  | **OS Window**    | Top-level container. Each kitty OS window is like a tmux session |
| **Window**   | **Tab**          | Secondary level container within a session/OS window             |
| **Pane**     | **Window**       | Individual terminal instances within a tab                       |
| N/A          | **Layout**       | How windows (panes) are arranged within a tab                    |

### Hierarchical Structure

**tmux:**

```
Session
├── Window (tab-like)
│   ├── Pane
│   ├── Pane
│   └── Pane
└── Window
    └── Pane
```

**kitty:**

```
OS Window (session-like)
├── Tab (window-like)
│   ├── Window (pane-like)
│   ├── Window (pane-like)
│   └── Window (pane-like)
└── Tab
    └── Window
```

## Programmatic Control: Remote Control API

### Prerequisites

1. Enable remote control in `kitty.conf`:

   ```conf
   allow_remote_control yes
   listen_on unix:/tmp/kitty
   ```

2. Or start kitty with listening enabled:
   ```bash
   kitty --listen-on=unix:/tmp/kitty
   ```

### Core Commands

#### Listing Information (like `tmux list-sessions`, `tmux list-windows`)

```bash
# List all OS windows, tabs, and windows with full details
kitten @ ls

# List only specific window
kitten @ ls --match id:1

# List with all environment variables
kitten @ ls --all-env-vars
```

The JSON output includes:

- **OS Window level**: `id`, `is_active`, `is_focused`, `platform_window_id`, `tabs[]`
- **Tab level**: `id`, `title`, `is_active`, `layout`, `windows[]`, `enabled_layouts`
- **Window level**: `id`, `title`, `pid`, `cwd`, `cmdline`, `env`, `foreground_processes`, `user_vars`

#### Creating New Instances

```bash
# Create new OS window (like tmux new-session)
kitten @ launch --type=os-window

# Create new tab (like tmux new-window)
kitten @ launch --type=tab --title="My Tab"

# Create new window in current tab (like tmux split-window)
kitten @ launch --type=window --location=after

# Split vertically/horizontally
kitten @ launch --type=window --location=vsplit
kitten @ launch --type=window --location=hsplit
```

#### Focus/Switching

```bash
# Focus specific tab
kitten @ focus-tab --match id:2

# Focus specific window
kitten @ focus-window --match id:5

# Focus by title/name
kitten @ focus-window --match title:"My Window"
```

#### Getting Process Information

The `kitten @ ls` command provides rich process information similar to tmux:

- **Process ID**: `pid` field
- **Command line**: `cmdline` array
- **Working directory**: `cwd` field
- **Environment variables**: `env` object
- **Foreground processes**: `foreground_processes` array with nested `pid`, `cmdline`, `cwd`

Example window JSON:

```json
{
	"id": 1,
	"title": "~/dev/project",
	"pid": 12345,
	"cwd": "/Users/user/dev/project",
	"cmdline": ["nu", "--login", "--interactive"],
	"env": {
		"KITTY_WINDOW_ID": "1",
		"PWD": "/Users/user/dev/project"
	},
	"foreground_processes": [
		{
			"pid": 12346,
			"cmdline": ["nvim", "file.txt"],
			"cwd": "/Users/user/dev/project"
		}
	]
}
```

### Advanced Querying with Match Specifications

kitty's match system is more powerful than tmux's target syntax:

```bash
# Match by working directory
kitten @ ls --match cwd:/home/user/project

# Match by process ID
kitten @ ls --match pid:12345

# Match by environment variable
kitten @ ls --match env:VIRTUAL_ENV=/path/to/venv

# Match by command line
kitten @ ls --match cmdline:.*nvim.*

# Match by state
kitten @ ls --match state:focused
```

### Text Manipulation

```bash
# Send text to window (like tmux send-keys)
kitten @ send-text --match id:1 "echo hello\n"

# Get text from window (like tmux capture-pane)
kitten @ get-text --match id:1

# Get scrollback
kitten @ get-text --match id:1 --extent=all
```

### Layouts

Unlike tmux which has basic layouts, kitty has rich layout systems:

```bash
# Available layouts: fat, grid, horizontal, splits, stack, tall, vertical
kitten @ goto-layout tall
kitten @ goto-layout splits

# Get current layout
kitten @ ls --match id:1 | jq '.[] | .tabs[] | .layout'
```

### Window Management

```bash
# Close window (like tmux kill-pane)
kitten @ close-window --match id:1

# Close tab (like tmux kill-window)
kitten @ close-tab --match id:1

# Resize window
kitten @ resize-window --match id:1 --increment 5

# Move windows between tabs
kitten @ detach-window --match id:1 new-tab
```

## Key Differences from tmux

### 1. **No Detached Sessions**

- kitty OS windows are always attached to a GUI process
- No equivalent to `tmux attach/detach`
- Use multiple OS windows instead of detached sessions
- There seem to be limitations on the api control between OS windows

### 2. **Richer Process Information**

- kitty tracks foreground processes in real-time
- Environment variables are captured at window creation
- More detailed command line and working directory tracking

### 3. **Layout System**

- More sophisticated layouts than tmux
- Layout-specific options (bias, mirroring, etc.)
- Dynamic layout switching

### 4. **Window Identification**

- kitty uses numeric IDs for all objects
- Environment variable `KITTY_WINDOW_ID` available in each window
- More granular matching system

## Example Scripts

### List All Sessions (OS Windows) with Basic Info

```bash
#!/bin/bash
kitten @ ls | jq '.[] | {
  id: .id,
  focused: .is_focused,
  tabs: .tabs | length,
  active_tab: (.tabs[] | select(.is_active) | .title)
}'
```

### Find Windows Running Specific Command

```bash
#!/bin/bash
# Find all windows running nvim
kitten @ ls | jq '.[] | .tabs[] | .windows[] | select(.foreground_processes[]?.cmdline[]? | contains("nvim")) | {
  os_window: .env.WINDOWID,
  window_id: .id,
  title: .title,
  cwd: .cwd
}'
```

### Switch to Window by Project Directory

```bash
#!/bin/bash
project_dir="$1"
window_id=$(kitten @ ls | jq -r ".[] | .tabs[] | .windows[] | select(.cwd | startswith(\"$project_dir\")) | .id" | head -1)
if [ -n "$window_id" ]; then
    kitten @ focus-window --match id:"$window_id"
fi
```

## Integration Tips

1. **Environment Setup**: Set `KITTY_LISTEN_ON` environment variable to avoid `--to` parameter
2. **JSON Processing**: Use `jq` for processing the rich JSON output
3. **Scripting**: kitty's match system allows complex automation scenarios
4. **Shell Integration**: Enable shell integration for better working directory tracking

This gives you the foundation to replicate most tmux workflows using kitty's more integrated approach to terminal management.
