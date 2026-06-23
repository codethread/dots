# Theming Specification

Document ID: SPEC-007
Configuration identification: SPEC-007; migrated from `specs/theming.md`; canonical path `devflow/specs/theming.md`.
**Status:** Partially Implemented
**Last Updated:** 2026-04-18

## [SPEC-007-S1] 1. Overview

### [SPEC-007-S1.1] Purpose

Shared light/dark and theme-family control for the interactive desktop and terminal stack. The current implementation coordinates macOS appearance, desktop wallpaper, Kitty colors, Nushell syntax/table colors, `LS_COLORS`, and Neovim colors from one small state contract.

Most terminal applications are expected to follow the active theme through the combined terminal palette, shell color config, and `LS_COLORS`. Neovim is the main app with explicit extra theme integration; LazyGit has a small adjustment to prefer terminal defaults. Additional app-specific handling should be added only when inheritance is not enough.

The system is intentionally narrow for now. Nix and NixOS desktop theming are not yet controlled by this flow.

### [SPEC-007-S1.2] Goals

- One command to switch between light and dark mode.
- Preserve the chosen theme family while toggling light/dark.
- Support at least `tokyonight` and `rose-pine`.
- Keep terminals and editor config reading the same state.
- Reload live Kitty windows without restarting them.
- Avoid scattering plugin-specific theme choices throughout the Neovim config.

### [SPEC-007-S1.3] Non-Goals

- Full Nix/Home Manager generation of themes. This is intended, but not implemented yet.
- Linux desktop theme switching. NixOS currently has separate static dark GTK/Qt config.
- Per-application theme tables by default. Most terminal apps should inherit from Kitty, Nushell, and `LS_COLORS`.
- Dynamic reload inside already-running Neovim instances.
- Theme package installation or wallpaper provisioning.

## [SPEC-007-S2] 2. Architecture

### [SPEC-007-S2.1] Control Flow

```
theme light|dark|toggle [--family tokyonight|rose-pine]
    |
    +- Resolve mode
    |  +- macOS appearance, when available
    |  +- $XDG_STATE_HOME/color-theme
    |  +- dark fallback
    |
    +- Resolve family
    |  +- --family argument
    |  +- $XDG_STATE_HOME/color-theme-family
    |  +- tokyonight fallback
    |
    +- macOS only
    |  +- set system dark/light appearance
    |  +- set wallpaper on every desktop
    |
    +- write state files
    |  +- color-theme
    |  +- color-theme-family
    |
    +- Kitty
       +- copy selected theme to $XDG_STATE_HOME/kitty/active-theme.conf
       +- reload live windows through kitty remote control
```

### [SPEC-007-S2.2] Component Layout

```
home/.local/bin/theme
    Main theme switcher. Writes shared state, controls macOS, updates Kitty.

config/kitty/kitty.conf
    Includes $XDG_STATE_HOME/kitty/active-theme.conf and enables remote control.

config/kitty/themes/
    rose-pine.conf
    rose-pine-dawn.conf
    tokyonight-day.conf
    tokyonight-moon.conf

$XDG_STATE_HOME/kitty/active-theme.conf
    Written by theme switcher; not tracked in git to avoid noisy history.

config/nushell/config.nu
    Reads color-theme and selects the light/dark Nushell color config.

config/nushell/scripts/ct/themes.nu
    Defines the Nushell light and dark color records.

config/nushell/scripts/ct/ls-colors.nu
    Reads color-theme and color-theme-family, then generates LS_COLORS with vivid.

config/nvim/lua/codethread/theme.lua
    Neovim theme source of truth: active mode, family, palette, and plugin options.

config/nvim/lua/plugins/ui.lua
    Enables the active Neovim theme plugin and applies its colorscheme.
```

## [SPEC-007-S3] 3. State Model

### [SPEC-007-S3.1] Shared State Files

| File | Values | Writer | Readers |
|---|---|---|---|
| `$XDG_STATE_HOME/color-theme` | `light`, `dark` | `theme` | `theme`, Nushell, Neovim |
| `$XDG_STATE_HOME/color-theme-family` | `tokyonight`, `rose-pine` | `theme` | `theme`, Nushell `LS_COLORS`, Neovim |
| `$XDG_STATE_HOME/kitty/active-theme.conf` | Kitty color config | `theme` | Kitty |

`$XDG_STATE_HOME` defaults to `~/.local/state` when unset.

### [SPEC-007-S3.2] Theme Mapping

| Family | Mode | Kitty theme | Neovim style/variant | vivid theme |
|---|---|---|---|---|
| `tokyonight` | `light` | `tokyonight-day` | `day` | `tokyonight-day` |
| `tokyonight` | `dark` | `tokyonight-moon` | `moon` | `tokyonight-moon` |
| `rose-pine` | `light` | `rose-pine-dawn` | `dawn` | `rose-pine-dawn` |
| `rose-pine` | `dark` | `rose-pine` | `moon` | `rose-pine-moon` |

Note: the Kitty dark Rose Pine file is `rose-pine.conf`, while vivid and Neovim refer to the dark variant as `rose-pine-moon`.

### [SPEC-007-S3.3] Defaults

- Default family: `tokyonight`
- Default mode: current macOS appearance when readable, then state file, then `dark`
- Neovim family override: `CT_THEME_FAMILY`

## [SPEC-007-S4] 4. Interfaces

### [SPEC-007-S4.1] CLI

| Command | Action |
|---|---|
| `theme` | Print current family/mode and usage |
| `theme light` | Switch active mode to light, keep current family |
| `theme dark` | Switch active mode to dark, keep current family |
| `theme toggle` | Toggle between light and dark, keep current family |
| `theme --family rose-pine` | Switch family, keep current mode |
| `theme --family tokyonight light` | Switch family and mode together |
| `mac-dark-toggle` | Nushell alias for `theme toggle` |

### [SPEC-007-S4.2] macOS

Implemented in `home/.local/bin/theme`.

- Reads current system appearance through `osascript`.
- Sets system dark mode through `System Events`.
- Sets every desktop wallpaper to an image under `$CT_BACKGROUNDS_DIR` (defaults to `~/sync/images/backgrounds`, a git-synced images project watched by `syncengine` on macOS machines).
- Wallpaper lookup first tries the exact theme name, then falls back to `default` image in the backgrounds directory.

On non-macOS systems these steps are no-ops.

### [SPEC-007-S4.3] Kitty

Implemented by `home/.local/bin/theme` and `config/kitty/kitty.conf`.

- `kitty.conf` includes `$XDG_STATE_HOME/kitty/active-theme.conf`.
- The switcher copies the selected theme file to `$XDG_STATE_HOME/kitty/active-theme.conf`; this file is not tracked in git.
- Live reload uses `kitty @ set-colors --all --configured`.
- Primary remote socket is `unix:/tmp/mykitty`; fallback is Kitty's default remote target.
- `allow_remote_control yes` and `listen_on unix:/tmp/mykitty` must remain enabled.

### [SPEC-007-S4.4] Nushell

Implemented by `config/nushell/config.nu`, `ct/themes.nu`, and `ct/ls-colors.nu`.

- Shell UI colors are selected only by mode: `light` uses `$themes.light`, everything else uses `$themes.dark`.
- `LS_COLORS` is selected by mode and family using `vivid generate`.
- This is evaluated when Nushell starts; existing shells do not live-reload.

### [SPEC-007-S4.5] Neovim

Implemented by `config/nvim/lua/codethread/theme.lua` and consumers.

- `codethread.theme.mode()` reads `color-theme`.
- `codethread.theme.family()` reads `CT_THEME_FAMILY`, then `color-theme-family`, then defaults to `tokyonight`.
- `plugins/ui.lua` enables exactly one theme plugin: `folke/tokyonight.nvim` or `rose-pine/neovim`.
- `theme.lua` centralizes palettes for statusline, notes, Telescope, Snacks, Flash, whitespace, ToggleTerm, and syntax overrides.
- `kitty+page.lua` uses `theme.lazy_plugin_dir()` so Kitty scrollback paging loads the active theme plugin.

Neovim reads state at startup. A running instance needs restart or manual reload to fully change family/style.

## [SPEC-007-S5] 5. Implemented Coverage

| Area | Status | Notes |
|---|---|---|
| macOS appearance | Implemented | Dark/light only, via AppleScript |
| macOS wallpaper | Implemented | External image directory, not managed by repo |
| Kitty config | Implemented | File include plus remote live reload |
| Nushell UI colors | Implemented | Mode-aware, not family-specific |
| Nushell `LS_COLORS` | Implemented | Mode and family aware, generated by vivid |
| Neovim theme plugins | Implemented | Tokyo Night and Rose Pine |
| Neovim shared palette | Implemented | Central Lua module consumed by plugin config |
| LazyGit | Partially aligned | Small config adjustment to prefer terminal defaults |

## [SPEC-007-S6] 6. Not Yet Implemented

### [SPEC-007-S6.1] Nix / Home Manager

Nix currently provisions packages and has separate static desktop theme settings, but it does not own or generate this theme state.

Planned direction:

- Model theme family and mode as Home Manager options or profile-level values.
- Generate initial `$XDG_STATE_HOME/color-theme*` files during activation.
- Generate or install app theme assets where possible.
- Keep imperative `theme` switching for day-to-day toggles.
- Make NixOS GTK/Qt settings read from the same intended theme model instead of hardcoding Rose Pine dark.

### [SPEC-007-S6.2] NixOS Desktop

Current NixOS config hardcodes dark GTK/Qt/freedesktop preferences in `nix/features/nixos-common.nix`. It is not connected to `theme`.

Planned direction:

- Add Linux desktop switching for GTK, Qt, dconf color-scheme, wallpaper, and notification styling.
- Decide whether runtime Linux switching belongs in `theme`, a Nushell function, or a Nix-generated helper.

### [SPEC-007-S6.3] Other Applications

Most CLI/TUI applications should be covered by terminal colors, shell colors, and `LS_COLORS` without direct integration. Extra per-app config should be added as problems appear, not pre-emptively.

Known areas outside the current shared flow:

- WezTerm and Ghostty, if used instead of Kitty.
- Zellij, if terminal inheritance is not enough.
- GUI editors such as Zed and VS Code.
- Desktop/session styling such as Hyprland.
- minimal Neovim.

## [SPEC-007-S7] 7. Design Decisions

- **Tiny state contract** - plain files under `$XDG_STATE_HOME` are easy for Bash, Nushell, Lua, and future Nix activation scripts to share.
- **Imperative runtime switcher** - day/night switching should not require a Nix rebuild.
- **Kitty theme file copy** - `$XDG_STATE_HOME/kitty/active-theme.conf` keeps normal Kitty startup simple while still allowing live reload. Stored outside the repo to avoid git churn on every theme switch.
- **Family and mode are separate** - toggling light/dark preserves the user's preferred family.
- **Neovim owns plugin-specific details** - external state picks family/mode; `codethread.theme` translates that into plugin options and custom highlight palettes.
- **Terminal apps inherit first** - the default approach is terminal palette plus shell color config plus `LS_COLORS`; add app-specific theme config only when inheritance fails.

## [SPEC-007-S8] 8. Open Questions

- Should `theme` be the long-term cross-platform switcher, or should Linux/macOS implementations split behind a common interface?
- Should Nushell prompt/table colors become family-specific, or is light/dark enough?
- Should active Neovim instances get a command/autocmd for runtime theme reload?
- Should wallpapers eventually be provisioned by Nix from the synced images project?
- Should `vivid generate` output be cached under `$XDG_STATE_HOME` to avoid shell-start cost?
