# Rex trial

Session and window controls ported from `config/tmux/tmux.conf`. Project defaults, hostname/environment profiles and discovery roots come from `~/.config/tmux/sessions.toml`. Rex keeps its own mutable path list in `${XDG_CACHE_HOME:-~/.local/cache}/rex-slots`: lines 1–9 are slots 1–9, line 10 is slot 0, and later lines are appended projects. Assignments capture the focused terminal's current directory. Sessions are reused by directory basename, with dots replaced by underscores, just like `tmux-session`.

The prefix is **Ctrl+A**. Escape cancels an unfinished sequence.

| After prefix          | Action                                               |
| --------------------- | ---------------------------------------------------- |
| Ctrl+A                | Send Ctrl+A to terminal                              |
| r / Ctrl+R            | Reload config                                        |
| f                     | Discover projects with fzf and open/select a session |
| p / s                 | Pick from active Rex sessions                        |
| 0–9                   | Open/select project slot                             |
| N                     | New Rex session                                      |
| Tab                   | Previous session in Rex's ordering                   |
| Shift+Backspace       | Close session                                        |
| h, then 0–9           | Assign current directory to slot                     |
| h, then a / e / l / r | Append / edit / pick / reseed slots                  |
| n                     | New tab in current directory                         |
| R                     | Rename tab                                           |
| '                     | fzf tab picker                                       |
| Shift+Tab             | Previous tab in Rex's ordering                       |
| Backspace             | Close tab                                            |
| o                     | Close all other tabs                                 |

Without the prefix, **Ctrl+Alt+Z/X** selects the previous/next tab; **Ctrl+Alt+Left/Right** reorders the current tab.

Tab and Shift+Tab use ordered navigation because Rex does not expose tmux's last-used session/window history. Pane controls, worktree picking, work launchers, agent switching and the status line are outside this initial trial.

The config uses dots' shared `config/env/base.sh` environment for subprocesses, including the GUI server's Homebrew/mise PATH. It needs `fx`, `fd`, `fzf`, Zsh, and the configured editor (default `nvim`). Pickers run in floating terminals; Escape or Ctrl+C cancels them. Editing uses `NVIM_APPNAME=minimal-nvim`.

Link from the dots checkout:

```sh
DOTFILES="$PWD" nu -n -I "$PWD/config/nushell/scripts" -c \
  'use ct/dotty; dotty link --no-cache ($env.DOTFILES | path join "config/dotty/dotty.toml")'
rex config check
rex config reload
```

`rex keymap` checks the effective bindings against the connected client. Lua modules and the picker script are linked by dotty with `init.lua`.
