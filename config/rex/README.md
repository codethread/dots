# Rex trial

Session and window controls ported from `config/tmux/tmux.conf`. Numbered slots and discovery roots are hardcoded in `config/rex/projects.lua` as `~/...` paths. Slots no longer read or write a cache file or load tmux's TOML profiles; edit the Lua table and reload Rex to change them. Paths expand against the Lua runtime's home directory when used. Sessions are reused by directory basename, with dots replaced by underscores.

The prefix is **Ctrl+A**. Escape cancels an unfinished sequence.

| After prefix    | Action                                               |
| --------------- | ---------------------------------------------------- |
| Ctrl+A          | Send Ctrl+A to terminal                              |
| r / Ctrl+R      | Reload config                                        |
| f               | Discover projects with fzf and open/select a session |
| p / s           | Pick from active Rex sessions                        |
| 0–9             | Open/select project slot                             |
| N               | New Rex session                                      |
| Tab             | Previous session in Rex's ordering                   |
| Shift+Backspace | Close session                                        |
| h, then l       | Pick a configured slot                               |
| n               | New tab in current directory                         |
| R               | Rename tab                                           |
| '               | fzf tab picker                                       |
| Shift+Tab       | Previous tab in Rex's ordering                       |
| Backspace       | Close tab                                            |
| o               | Close all other tabs                                 |
| \| / -          | Split right / below in current directory             |
| Space           | Split a single pane (60/40), otherwise toggle zoom   |
| H / J / K / L   | Resize pane left / down / up / right                 |
| x               | Close pane                                           |

Without the prefix, **Ctrl+Alt+Z/X** selects the previous/next tab; **Ctrl+Alt+Left/Right** reorders the current tab.

**Ctrl+H/J/K/L** moves between Neovim windows, then Rex panes at the edge. **Alt+H/J/K/L** resizes them. In other programs these keys go directly to Rex. Resizing Rex panes moves the divider by 3% (Alt) or 2% (prefix + Shift), rather than tmux's cell counts.

Neovim installs smart-splits v3 and the Rex/tmux backends through Lazy. Rex loads the supplied `smart-splits-rex` module from `${XDG_DATA_HOME:-~/.local/share}/nvim/lazy/smart-splits-backend-rex`; install the Neovim dependencies before loading this config. Restart existing Neovim instances after upgrading. Backend priority is tmux first, then Rex, so Neovim inside tmux uses its inner multiplexer.

The Neovim Rex adapter selects the pane's owning client before resizing, so resize commands also work with multiple Rex apps connected.

While a Neovim pane is zoomed with **Ctrl+A Space**, navigation stays within Neovim's windows. Restore the Rex layout with **Ctrl+A Space** to move into neighboring Rex panes again.

Tab and Shift+Tab use ordered navigation because Rex does not expose tmux's last-used session/window history. Tall/fat layouts, pane swapping, worktree picking, work launchers, agent switching and the status line are outside this trial.

The config uses dots' shared `config/env/base.sh` environment for subprocesses, including the GUI server's Homebrew/mise PATH. It needs `fd`, `fzf`, and Zsh. Pickers run in floating terminals; Escape or Ctrl+C cancels them.

Link from the dots checkout:

```sh
DOTFILES="$PWD" nu -n -I "$PWD/config/nushell/scripts" -c \
  'use ct/dotty; dotty link --no-cache ($env.DOTFILES | path join "config/dotty/dotty.toml")'
rex config check
rex config reload
```

`rex keymap` checks the effective bindings against the connected client. Lua modules and the picker script are linked by dotty with `init.lua`.
