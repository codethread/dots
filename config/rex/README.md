# Rex trial

Session and window controls ported from `config/tmux/tmux.conf`. Default slots and discovery roots live in `config/rex/projects.lua` as `~/...` paths. Each session host keeps its mutable slots and saved projects in `${XDG_STATE_HOME:-~/.local/state}/rex/projects.json`, seeded on first use from those Lua defaults. It does not load tmux's TOML profiles. Sessions are reused by directory basename, with dots replaced by underscores. Basenames must be distinct across projects; duplicate Rex session labels or a known session belonging to a different directory fail visibly.

The prefix is **Ctrl+A**. Escape cancels an unfinished sequence.

| After prefix      | Action                                               |
| ----------------- | ---------------------------------------------------- |
| Ctrl+A            | Send Ctrl+A to terminal                              |
| r / Ctrl+R        | Reload config                                        |
| f                 | Discover projects with fzf and open/select a session |
| g                 | fzf Git worktrees in the current terminal's repo     |
| p / s             | Pick from active Rex sessions                        |
| 0–9               | Open/select project slot                             |
| N                 | New Rex session                                      |
| Tab               | Previous session in Rex's ordering                   |
| Shift+Backspace   | Close session                                        |
| h, then 0–9       | Assign current session project to that slot          |
| h, then a         | Append current session project if missing            |
| h, then l         | fzf numbered slots and appended projects             |
| h, then e         | Edit saved state in a host-side editor popup         |
| h, then r         | Reset slots/list to Lua defaults                     |
| n                 | New tab in current directory                         |
| R                 | Rename tab                                           |
| '                 | fzf tab picker                                       |
| Shift+Tab         | Previous tab in Rex's ordering                       |
| Backspace         | Close tab                                            |
| o                 | Close all other tabs                                 |
| \| / -            | Split right / below in current directory             |
| Space             | Split a single pane (60/40), otherwise toggle zoom   |
| H / J / K / L     | Resize pane left / down / up / right                 |
| x                 | Close pane                                           |
| { / }             | Swap pane backward / forward in layout order         |
| m                 | Swap current pane into first position                |
| j                 | Pick a pane in this session to swap with             |
| b / B             | Move pane to a new tab / pick an existing tab        |
| = / Enter         | Force tall layout / toggle tall and fat layouts      |
| +                 | Balance split sizes                                  |
| [ / O / S         | Open scrollback in read-only Neovim                  |
| ?                 | Rex command palette                                  |
| /                 | Find in terminal scrollback                          |
| PageUp / PageDown | Jump to previous / next shell prompt                 |

Without the prefix, **Ctrl+Alt+Z/X** selects the previous/next tab; **Ctrl+Alt+Left/Right** reorders the current tab.

**Ctrl+H/J/K/L** moves between Neovim windows, then Rex panes at the edge. **Alt+H/J/K/L** resizes them. In other programs these keys go directly to Rex. Resizing Rex panes moves the divider by 3% (Alt) or 2% (prefix + Shift), rather than tmux's cell counts.

Neovim installs smart-splits v3 and the Rex/tmux backends through Lazy. Rex loads the supplied `smart-splits-rex` module from `${XDG_DATA_HOME:-~/.local/share}/nvim/lazy/smart-splits-backend-rex`; install the Neovim dependencies before loading this config. Restart existing Neovim instances after upgrading. Backend priority is tmux first, then Rex, so Neovim inside tmux uses its inner multiplexer.

The Neovim Rex adapter selects the pane's owning client before resizing, so resize commands also work with multiple Rex apps connected.

While a Neovim pane is zoomed with **Ctrl+A Space**, navigation stays within Neovim's windows. Restore the Rex layout with **Ctrl+A Space** to move into neighboring Rex panes again.

Tall/fat layouts preserve the running panes and use the same main-pane size thresholds as `tmux-layout-aware`, estimated from the terminal's current size. Tall puts the first pane on the left with the others stacked on the right; fat puts it above a row of the others. Floating layers are rearranged separately.

Rex's native **b** action selects the new tab; tmux's binding left it in the background. **B** is an added binding for Rex's native move-to-tab picker. Pane swaps stay within the current layer, while **j** can swap across tabs in the current session.

Rex exposes no tmux-style copy-mode action. **[**, **O**, and **S** open captured scrollback in Neovim at the bottom. Use `/` to search, `y` to copy, `:w! ~/filename` to save, and `q` to close the history tab. Clipboard and saved files belong to the machine running Neovim.

Tab and Shift+Tab use ordered navigation because Rex does not expose tmux's last-used session/window history. Work launchers, agent switching, fingers hints and the tmux status line remain tmux-specific.

## Project sessionizer

**Ctrl+A p/s** uses Rex's native session switcher. **Ctrl+A f** discovers projects on demand and opens fzf in a floating terminal. **Ctrl+A g** lists Git worktrees for the current terminal's directory on its session host, showing aligned branch, directory-basename and last-commit-age columns. The age comes from each worktree's HEAD commit, not uncommitted file edits. **Tab** toggles between branch-name order (the default) and newest commit first; the prompt shows the active order. It uses the same floating fzf picker and project-session logic to open or select the chosen directory. **Ctrl+A h** enters an exclusive, one-shot project mode; Escape, q, or Ctrl+C cancels. Its actions mirror the tmux slot workflow above. **Ctrl+A 0–9** jumps to the project with that explicit index, regardless of array order. Projects without an index appear in **h l** without a numbered shortcut. **h a** deduplicates by path or session name.

The state file contains `version: 2`, `entries`, and a `sessions` map. A numbered entry is `{ "index": 1, "name": "dots", "path": "/absolute/server/path" }`. Indexes must be unique integers from 0 to 9; duplicates raise a Rex action error naming both projects. Array order does not assign shortcuts. Omit an entry to leave a slot empty, or omit its `index` to keep a project only in the picker. **h 0–9** replaces the matching index or creates it if absent; **h a** adds an unindexed project. The picker sorts numbered slots as 1–9, 0, followed by unindexed projects alphabetically.

The session map remembers the directory used when opening a project, so changing a pane's directory does not change later assignments. Rex has no tmux `session_path` field: a manual or pre-existing session is adopted from the source terminal's directory on its first assign/add. No Git-root inference is used. Resetting the slots preserves these live-session directory associations.

### Home server versus session host

Rex's home supplies shortcuts and runs their Lua callbacks. The viewed session can belong to a different server. In that case `ctx.server` forwards Rex API calls, but `io.open`, home expansion, and subprocesses still run on the shortcut server. Merely forwarding `session.create` would therefore mix one machine's paths with another machine's sessions.

The sessionizer instead forwards the entire operation to a registered `dots_host_*` action on the session host using `client.action`. That host reads/writes state, expands paths, discovers directories, creates sessions, and runs picker/editor terminals. The originating app receives `session.select`; a picker callback targets that same app's host-side client connection and retains the source session and pane IDs. It does not infer the intended viewer from pane ownership.

Install this Rex config on both the shortcut home and each session host. A laptop can drive a host's slots without owning or synchronizing its state file; no home-server change is required. A missing host action fails rather than using the shortcut server's filesystem. Programmatic writes use a host-local lock and atomic replacement; a busy lock or malformed JSON fails visibly. Avoid editing the file while assigning slots from another client. **h e** can repair malformed JSON. A lock left by a terminated writer must be removed only after confirming no writer is active.

The config uses dots' shared `config/env/base.sh` environment for subprocesses, including the GUI server's Homebrew/mise PATH. It needs `fd`, `fzf`, Zsh, and `nvim` for the scrollback viewer. Pickers run in floating terminals; Escape or Ctrl+C cancels them.

See Rex's [Lua API](https://www.superlogical.com/rex/docs/reference/lua.md) and [custom actions](https://www.superlogical.com/rex/docs/customize/actions.md) references.

Link from the dots checkout:

```sh
mise run link
rex config check
rex config reload
```

`rex keymap` reports the server's bindings; validating client action names and arguments requires `--request` with the client's action declarations. Lua modules and the picker script are linked by mise with `init.lua`.
