# Kitty Documentation Index

All instructions here are listed relative to the `~/dev/vendor/kitty` directory

This is an organized index of the kitty terminal documentation, focusing on mappable actions and kittens for quick reference.

## Core Documentation Structure

### Configuration & Mapping

- **`docs/conf.rst`** - Main kitty configuration file documentation
- **`docs/mapping.rst`** - Comprehensive keyboard mapping guide
- **`docs/actions.rst`** - All mappable actions (references generated content)

### Key Functionality

- **`docs/remote-control.rst`** - Control kitty from scripts via `kitten @`
- **`docs/launch.rst`** - The `launch` action for creating windows/tabs/overlays
- **`docs/layouts.rst`** - Window layout management

### Getting Started

- **`docs/index.rst`** - Main entry point and feature overview
- **`docs/quickstart.rst`** - Installation and basic setup
- **`docs/overview.rst`** - Design philosophy and core features

## Mappable Actions & Controls

### Key Mapping System

From `docs/mapping.rst`:

- Basic syntax: `map ctrl+a new_window_with_cwd`
- Multi-key mappings: `map key1>key2>key3 action`
- Modal mappings: `map --new-mode <mode> <key>`
- Conditional mappings: `map --when-focus-on title:keyboard.protocol kitty_mod+t`
- Combining actions: `map key combine : action1 : action2`

### Action Categories

- **Window Management**: `new_window`, `close_window`, `neighboring_window`, `move_window`
- **Tab Management**: `new_tab`, `close_tab`, `next_tab`, `previous_tab`
- **Layout Control**: `next_layout`, `layout_action`
- **Text Selection**: `copy_to_clipboard`, `paste_from_clipboard`
- **Remote Control**: `remote_control`, `remote_control_script`
- **Scrollback**: `show_scrollback`, `scroll_page_up`, `scroll_page_down`

### Special Actions

- **`launch`**: Create new windows/tabs with extensive options
- **`combine`**: Execute multiple actions in sequence
- **`send_text`**: Send arbitrary text to terminal
- **`send_key`**: Send key presses to terminal
- **`discard_event`**: Ignore key events completely

## Kittens Index

### File & Content Manipulation

#### **`hints`** (`docs/kittens/hints.rst`)

- **Purpose**: Select and act on text snippets visible on screen
- **Key Mappings**:
  - `open_url` - Select and open URLs
  - `insert_selected_path` - Insert paths into terminal
  - `goto_file_line` - Open files at specific lines
- **Customization**: Support for custom Python scripts
- **Example**: `map ctrl+g kitten hints --type=linenum --linenum-action=tab nvim +{line} {path}`

#### **`icat`** (`docs/kittens/icat.rst`)

- **Purpose**: Display images in terminal
- **Usage**: `kitten icat image.jpeg`
- **Features**: Supports all ImageMagick formats, works over SSH
- **Integration**: Can be used by other programs with `--place`, `--detect-support` options

#### **`diff`** (`docs/kittens/diff.rst`)

- **Purpose**: Side-by-side diff tool with syntax highlighting
- **Usage**: `kitten diff file1 file2`
- **Features**: Image diffs, recursive directory diffing, Git integration
- **Controls**: Vim-like navigation (J/K, PgUp/PgDn, N/P for changes)

### System Integration

#### **`ssh`** (`docs/kittens/ssh.rst`)

- **Purpose**: Enhanced SSH with automatic shell integration
- **Features**: Auto-setup remote environment, file copying, connection reuse
- **Config**: `~/.config/kitty/ssh.conf` for per-host settings
- **Usage**: `kitten ssh hostname` or `s hostname` (with alias)

#### **`transfer`** (`docs/kittens/transfer.rst`)

- **Purpose**: File transfer over TTY (works through SSH, serial, etc.)
- **Usage**:
  - Download: `kitten transfer some-file /local/path`
  - Upload: `kitten transfer --direction=upload /local/path remote-file`
- **Features**: Directory trees, rsync protocol support, permission preservation

#### **`clipboard`** (`docs/kittens/clipboard.rst`)

- **Purpose**: System clipboard access from shell
- **Usage**:
  - Copy: `echo text | kitten clipboard`
  - Paste: `kitten clipboard --get-clipboard`
- **Features**: Arbitrary data types (images, etc.), MIME type control

### User Interface

#### **`themes`** (`docs/kittens/themes.rst`)

- **Purpose**: Change color themes interactively
- **Usage**: `kitten themes` (interactive) or `kitten themes "Theme Name"`
- **Features**: 300+ themes, live preview, recent themes, auto dark/light mode
- **Files**: Creates `current-theme.conf` and auto theme files

#### **`unicode_input`** (`docs/kittens/unicode_input.rst`)

- **Purpose**: Input Unicode characters by name or hex code
- **Mapping**: `input_unicode_character` (default shortcut)
- **Modes**: Code mode (hex), Name mode (search), favorites, recent
- **Controls**: F1-F4 or Ctrl+1-4 to switch modes

#### **`panel`** (`docs/kittens/panel.rst`)

- **Purpose**: Draw desktop panels/wallpapers with terminal programs
- **Usage**: `kitten panel <program>` or `kitten panel --edge=background <program>`
- **Features**: Desktop backgrounds, dock panels, quick access terminals
- **Platform**: Wayland (most compositors), macOS, X11 (limited)

#### **`notify`** (`docs/kittens/notify.rst`)

- **Purpose**: System notifications from shell
- **Usage**: `kitten notify "Title" Message body`
- **Features**: Icons, buttons, completion waiting
- **Example**: `kitten notify --wait-for-completion --button OK "Alert" "Task done"`

### Development & Utility

#### **`broadcast`** (referenced in `docs/remote-control.rst`)

- **Purpose**: Send keystrokes to all kitty windows
- **Usage**: `kitten +kitten broadcast`
- **Use Case**: Type commands to multiple terminals simultaneously

#### Custom Kittens (`docs/kittens/custom.rst`)

- **Purpose**: Create your own kittens in Python
- **Structure**: Command-line part + kitty internal part
- **Examples**: Many built-in features are implemented as kittens

## Writing Custom Control Scripts

### Remote Control Scripts

From `docs/remote-control.rst` and `docs/mapping.rst`, you can create powerful scripts that control kitty using the `kitten @` API:

#### Basic Script Structure

```bash
#!/bin/bash
# Example: ~/.config/kitty/scripts/my-kitty-script.sh

# Get information about current kitty state
kitten @ ls

# Open a new window with a specific title
kitten @ launch --title "Build Output" --keep-focus make

# Send text to a specific window
kitten @ send-text --match 'title:^Build' "echo 'Build started'"

# Set colors dynamically
kitten @ set-colors background=red

# Focus a specific window
kitten @ focus-window --match 'title:^Output'
```

#### Advanced Script with Error Handling

```bash
#!/bin/bash
# ~/.config/kitty/scripts/smart-split.sh

set -e

# Check if we're in kitty
if [ -z "$KITTY_WINDOW_ID" ]; then
    echo "This script must be run inside kitty"
    exit 1
fi

# Get current window info
current_window=$(kitten @ ls | jq -r '.[] | .tabs[] | .windows[] | select(.is_focused == true)')

# Create a new window with current directory
current_cwd=$(echo "$current_window" | jq -r '.cwd')
kitten @ launch --location=vsplit --cwd="$current_cwd" "$@"

# Optional: adjust window sizes
kitten @ resize-window --increment=-10
```

#### Mapping Scripts to Keybindings

Add these to your `kitty.conf`:

```conf
# Map a simple script
map f1 remote_control_script ~/.config/kitty/scripts/workspace-setup.py

# Map script with arguments (use shell wrapper)
map f2 remote_control_script ~/.config/kitty/scripts/smart-split.sh vim

# Map inline commands for simple operations
map f3 remote_control set-spacing margin=30

# Map script that ignores errors (prefix with !)
map f4 remote_control !focus-window --match NONEXISTENT

# Complex multi-step operation
map ctrl+shift+d combine : remote_control launch --type=tab --tab-title Debug : remote_control launch --location=vsplit gdb
```

#### Script Best Practices

1. **Make scripts executable**: `chmod +x ~/.config/kitty/scripts/my-script.sh`
2. **Use absolute paths**: Store in `~/.config/kitty/scripts/` for organization
3. **Error handling**: Check `$KITTY_WINDOW_ID` to ensure running in kitty
4. **JSON parsing**: Use `jq` for parsing `kitten @ ls` output
5. **Environment**: Scripts inherit kitty's environment variables

#### Available Remote Control Commands

Key commands for scripts (see `kitten @ --help`):

- `launch` - Create windows/tabs/overlays
- `send-text` - Send text to windows
- `focus-window/focus-tab` - Change focus
- `close-window/close-tab` - Close windows/tabs
- `set-colors` - Change colors dynamically
- `set-spacing` - Adjust window spacing
- `ls` - List all windows/tabs (returns JSON)
- `get-text` - Get text from windows
- `scroll-window` - Control scrolling
- `resize-window` - Resize windows

## Quick Reference Patterns

### Common Mapping Examples

```conf
# Basic window/tab management
map kitty_mod+t new_tab_with_cwd
map kitty_mod+w close_tab
map kitty_mod+enter new_window_with_cwd

# Hints kitten variations
map ctrl+shift+e kitten hints --type word --program @
map ctrl+shift+p kitten hints --type path --program @
map ctrl+g kitten hints --type linenum --linenum-action=tab nvim +{line} {path}

# Remote control shortcuts
map f1 remote_control set-spacing margin=30
map f2 remote_control_script /path/to/script

# Launch variations
map f1 launch --type=tab vim
map f2 launch --stdin-source=@screen_scrollback less
```

### Essential Kittens for Daily Use

1. **`hints`** - Essential for URL/path selection
2. **`themes`** - Quick theme switching
3. **`ssh`** - Better SSH experience
4. **`clipboard`** - Shell clipboard access
5. **`icat`** - Image viewing
6. **`unicode_input`** - Special character input

This index provides quick access to kitty's most important mappable actions and kitten functionality for efficient terminal workflow setup.
