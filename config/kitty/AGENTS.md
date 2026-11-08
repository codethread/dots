# Kitty configuration

- Kitty owns terminal rendering and terminal-level input; tmux owns sessions, panes, and multiplexing behavior.
- Preserve the existing fold markers when adding grouped configuration: `#: name {{{` opens a section and `#: }}}` closes it.
- Keep `bin/menu.sh` limited to Kitty-specific actions; cross-application orchestration belongs with its runtime owner.
- Use the Kitty checks in [the verification guide](../../docs/verification.md#themes-and-desktop-integration); report syntax as untested when no parser is available rather than reloading the live terminal.
