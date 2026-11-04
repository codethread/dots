# Theming Specification

- Document ID: SPEC-007
- Configuration identification: SPEC-007; migrated from `specs/theming.md`; canonical path `devflow/specs/theming.md`.
- **Status:** Partially Implemented
- **Last Updated:** 2026-11-04

## [SPEC-007-S1] 1. Overview

### [SPEC-007-S1.1] Purpose

Apply a mode/family change first on the machine executing `theme`, then forward the same explicit state to a separately selected Rex host. Each machine updates its own state files, desktop, Kitty, and local Rex app. Neovim and shell applications read the state where they execute.

There is no all-client broadcast. Other Rex viewers may intentionally remain different. A laptop displaying a remote shell does not make the CLI laptop-local: a command in a Mini-hosted pane executes on the Mini.

### [SPEC-007-S1.2] Goals

- One command for light/dark and `tokyonight`/`rose-pine` family selection.
- Resolve `toggle` once from caller-local state, then send explicit mode/family.
- Apply once when caller and selected host are the same host/account.
- Share one TypeScript local-apply implementation between caller and receiving host.
- Identify partial failures without reverting already-applied caller state.

### [SPEC-007-S1.3] Non-Goals

- Broadcasting to other connected viewers or synchronizing every Rex server.
- A client listener, reconnect watcher, or background theme service.
- Signaling, refreshing, or injecting commands into running Neovim instances.
- Guaranteed live reload in arbitrary applications.
- Linux desktop theming, wallpaper provisioning, or terminal package installation.

## [SPEC-007-S2] 2. Architecture

### [SPEC-007-S2.1] Control Flow

```text
theme [mode] [--family FAMILY]
    |
    +- Resolve from caller-local saved mode/family
    |  +- status request -> display; no writes or Rex calls
    |
    +- Preflight local palette/Kitty/wallpaper assets
    +- Apply local state, desktop and Kitty
    +- Discover local Rex with inherited remote routing cleared
    |  +- absent -> continue without a local app update
    |  +- present -> update the caller's local app only
    |
    +- --host, or no REX_SERVER -> finish locally
    |
    +- Query selected Rex host identity
    |  +- same host/account -> finish; do not apply twice
    |  +- different -> client.action dots_theme(mode, family)
    |     +- receiver runs theme --host with explicit values
    |     +- receiver applies locally and never forwards
    |
    +- Report success, or partial failure with explicit-mode retry guidance
```

### [SPEC-007-S2.2] Component Layout

- `oven/bin/theme.ts`: CLI parsing, local state/asset/desktop engine, own-app targeting, host identity comparison, and forwarding.
- `oven/bin/manifest.json`: installs the `theme` wrapper through Oven.
- `oven/tests/theme.test.ts`: state resolution, local app targeting, caller-before-host ordering, deduplication, no-loop behavior, and failure coverage.
- `config/rex/theme.lua`: `dots_theme` receiver, accepting explicit mode/family and invoking `theme --host` on its server.
- `config/rex/init.lua`: loads the theme action.
- `config/rex/themes/`: four self-contained Rex palettes, licenses, and usage notes.
- `config/kitty/themes/`: Kitty-specific source themes; the generated active file stays outside git.
- `config/nushell/config.nu`, `ct/themes.nu`, `ct/ls-colors.nu`: execution-local shell colors and `LS_COLORS`.
- `config/nvim/lua/codethread/theme.lua`, `plugins/ui.lua`: execution-local Neovim configuration, read at startup.

### [SPEC-007-S2.3] Execution and Installation

Rex's default CLI server is local; `REX_HOME` controls hosts/shortcuts, while `REX_SERVER` selects a command target. Local discovery uses `env -u` to clear inherited `REX_SERVER`, `REX_CLIENT`, `REX_SESSION`, and `REX_BLOCK`, with `--autostart=false`. Subsequent local app commands explicitly target the discovered local endpoint and full app ID. No platform-specific socket path is hardcoded.

Connected Unix-local app clients are candidates. A remote viewer is never chosen in place of a missing local app. More than one local app requires an explicit `REX_CLIENT`, resolved by Rex and checked against the local candidate list. The selector cannot redirect the local phase to another machine.

After local success, a configured `REX_SERVER` is queried through `whoami`. Compare native `host_id` and account with the local identity to detect endpoint aliases of the same host/account. A separate host receives raw `client.action` for `dots_theme`, without a session or app target. The payload always includes resolved `light`/`dark` and family, never `toggle`.

Configuration callbacks execute on their server; standalone `rex do` scripts execute on the CLI machine. The receiver therefore uses a configuration callback to run the same Oven command with `--host`. That path applies local state and its own Rex app, prints JSON, and cannot forward again. Both caller and host need current Oven/configuration/palette files. Reload Rex configuration after installing the receiver.

Each machine imports its own palette from its own filesystem. Remote app theme-name selection, one-time remote imports, and palette transfer are not needed. Other viewers are not modified.

## [SPEC-007-S3] 3. State Model

### [SPEC-007-S3.1] State Files

These paths belong to each **execution machine**. A separate host receives the same explicit values after the caller has applied them.

| File | Values | Writer | Readers |
| --- | --- | --- | --- |
| `$XDG_STATE_HOME/color-theme` | `light`, `dark` | local engine | `theme`, Nushell, Neovim |
| `$XDG_STATE_HOME/color-theme-family` | `tokyonight`, `rose-pine` | local engine | `theme`, Nushell `LS_COLORS`, Neovim |
| `$XDG_CONFIG_HOME/kitty/themes/active.conf` | Kitty color config | local engine | Kitty |

`XDG_STATE_HOME` defaults to `~/.local/state`; `XDG_CONFIG_HOME` defaults to `~/.config`. Rex owns its app's imported palettes and runtime appearance preferences. No second generated Rex active-config file is written.

### [SPEC-007-S3.2] Theme Mapping

| Family       | Mode    | Kitty theme       | Rex palette       | Neovim variant | vivid theme       |
| ------------ | ------- | ----------------- | ----------------- | -------------- | ----------------- |
| `tokyonight` | `light` | `tokyonight-day`  | `TokyoNight Day`  | `day`          | `tokyonight-day`  |
| `tokyonight` | `dark`  | `tokyonight-moon` | `TokyoNight Moon` | `moon`         | `tokyonight-moon` |
| `rose-pine`  | `light` | `rose-pine-dawn`  | `Rose Pine Dawn`  | `dawn`         | `rose-pine-dawn`  |
| `rose-pine`  | `dark`  | `rose-pine`       | `Rose Pine Moon`  | `moon`         | `rose-pine-moon`  |

### [SPEC-007-S3.3] Defaults

- Family: saved local state, otherwise `tokyonight`.
- Mode: saved local state, otherwise `dark`.
- Explicit CLI arguments override their respective saved values.
- `toggle` flips the caller's saved mode exactly once.
- macOS appearance follows the resolved local mode; it is not read as the authority.
- Neovim retains its existing `CT_THEME_FAMILY` override.

## [SPEC-007-S4] 4. Interfaces

### [SPEC-007-S4.1] CLI

| Command                           | Action                                                              |
| --------------------------------- | ------------------------------------------------------------------- |
| `theme`                           | Print caller-local mode/family and usage, with no Rex calls         |
| `theme light` / `theme dark`      | Apply locally, then send explicit state to a separate `REX_SERVER`  |
| `theme toggle`                    | Toggle caller-local state once, then follow the same flow           |
| `theme --family rose-pine`        | Change family, preserve caller-local mode                           |
| `theme --family tokyonight light` | Set both values                                                     |
| `theme --host light`              | Apply locally including its own Rex app; JSON result; no forwarding |
| `mac-dark-toggle`                 | Nushell alias for `theme toggle`                                    |

Rex is never auto-started. Without local Rex, local state/desktop/Kitty can still change. A configured host that cannot be reached fails after the caller phase; it is not silently ignored. The receiving host must have `dots_theme` installed.

### [SPEC-007-S4.2] macOS

On each execution machine, set system dark mode and every desktop wallpaper through `osascript`. Images come from `CT_BACKGROUNDS_DIR`, defaulting to `~/sync/images/backgrounds`. Exact-theme images precede defaults; JPG precedes PNG. Non-macOS machines omit desktop steps.

### [SPEC-007-S4.3] Kitty

Copy the selected source theme to `kitty/themes/active.conf` before reloading. Primary socket: `unix:/tmp/mykitty`; on failure try Kitty's default target. Reloads remain best effort, including absent Kitty. Managed remote reload requires `allow_remote_control yes` and `listen_on unix:/tmp/mykitty`.

### [SPEC-007-S4.4] Rex

Use local CLI discovery and local `client.list`, then send `client.appearance.switch_mode` and `client.theme.import` only to the chosen local app. Import uses that machine's local palette file. CLI, disconnected, unidentified, and remote viewer connections are not automatic candidates.

A separate selected host receives `dots_theme` with explicit mode/family. The receiving action rejects `toggle`, applies through `--host`, and does not forward or broadcast. Its own local app updates through the same TypeScript local workflow.

### [SPEC-007-S4.5] Nushell

Read execution-local mode for syntax/table colors and local mode/family for `vivid`-generated `LS_COLORS`. Existing shells do not automatically reload. The state-file contract is unchanged.

### [SPEC-007-S4.6] Neovim

Read mode/family on the execution host when loading the configured theme. No signals, refresh commands, RPC injections, or editor changes are part of this flow. Restart Neovim to pick up its host's state. Other applications may or may not respond live.

## [SPEC-007-S5] 5. Failure Semantics

Host-local independent updates run concurrently and are drained before returning. Local state may already be written when a desktop or app update fails. Stop before forwarding if the caller phase fails. If forwarding fails, retain the caller's applied state and identify the failed host phase.

There is no transaction or rollback across machines. Retry an explicit mode to reapply intent; another toggle would reverse the caller's current state. Unsupported/refused app actions and ambiguous local instances are visible errors, not reasons to choose another viewer.

## [SPEC-007-S6] 6. Outside the Shared Flow

Other viewers, separate unselected servers, GUI editor themes, minimal Neovim, and Linux desktop styling are not automatically synchronized. A remote-hosted shell cannot update the viewing laptop's local files or desktop without separate client-side machinery, which is deliberately deferred.

## [SPEC-007-S7] 7. Design Decisions

- **Caller-first:** the CLI's execution machine is the initiating authority.
- **Explicit forwarding:** mode/family, not a second toggle, cross the host boundary.
- **Identity-based deduplication:** endpoint aliases do not require a second apply on the same host/account.
- **Terminal receiver:** `--host` cannot forward or loop back to the caller.
- **No broadcast:** other viewers may intentionally retain a different theme.
- **Applications own refresh:** propagate state/actions without editor reload machinery.

## [SPEC-007-S8] 8. Open Questions

- Should later work add explicit client-side execution support for remote-hosted panes?
- Should wallpapers be provisioned automatically from the synced images project?
