# Tmux configuration

- Tmux owns sessions, panes, and multiplexing; keep terminal-emulator rendering and terminal-level bindings in Kitty.
- Validate on a dedicated named socket so parsing and smoke checks cannot alter the user's running server or sessions.
- Preserve environment import through `config/env/emit.sh --tmux`; tmux should receive the stable login baseline rather than source an interactive shell configuration.
- Run and clean up the isolated checks in [the verification guide](../../docs/verification.md#tmux-and-tui-configuration), including cleanup after a failed parse.
