## Kitty Configuration

This directory contains configuration for the Kitty terminal emulator.

**Context:** When working in this directory, use `/teach-kitty` to load comprehensive Kitty documentation if not already shared.

**Structure:**

- `kitty.conf` - Main terminal-emulator configuration
- `keys.macos.conf` / `keys.linux.conf` - Terminal-level keyboard bindings
- `bin/menu.sh` - Small kitty-only action menu for opacity/debug/key inspection
- `themes/` - Color schemes

## Config Style

- tmux owns multiplexing/session behavior; kitty keybindings should stay terminal-focused unless explicitly requested
- use vim fold markers for grouping config sections:

  ```
  #: section_name {{{

  content here

  #: }}}
  ```
