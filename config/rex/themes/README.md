# Caller-first Rex themes

`theme light`, `theme dark`, `theme toggle`, and `theme --family tokyonight|rose-pine` resolve from the saved state of the **machine executing the CLI**. Status (`theme` without arguments) also reads that machine, without contacting Rex.

```text
Caller differs from selected host:
  resolve once -> apply caller state/desktop/Kitty/Rex app
               -> send explicit mode/family -> apply on host

Caller is the selected host:
  resolve once -> apply once locally; no second host action
```

## Local app and host selection

Local Rex discovery clears inherited `REX_SERVER`, `REX_CLIENT`, `REX_SESSION`, and `REX_BLOCK`, with auto-start disabled. It uses Rex's own default-server discovery, not a hardcoded socket. Only a connected Unix-local app is updated; other viewers are not substitutes. If multiple local instances are running, set `REX_CLIENT` to a local app ID or label from `env -u REX_SERVER rex client ls`. A selector resolving to a remote viewer is rejected.

If `REX_SERVER` selects a different host/account, the caller finishes its local update first, then sends **explicit** `light`/`dark` and family through `dots_theme`. Native host/account identities prevent a second apply when an endpoint alias still identifies the caller's host. With no `REX_SERVER`, the command is local only.

The receiving action runs `theme --host`, which updates that host and its own local Rex app but never forwards. The action rejects `toggle`: it cannot toggle twice or call back to the originating client. `--host` prints the local result as JSON.

A laptop showing a Mini-hosted shell is **not** a laptop-local invocation. The CLI executes on the Mini, so this is the host case: it cannot run a local CLI or change desktop/state files on the viewing laptop.

## Palettes and failures

The four palettes are linked into `~/.config/rex/themes` on each machine. Each machine imports its own selected local file into its own Rex app; no manual remote imports or palette-file transfer are needed. Sync/link the palettes, Oven command, and Rex configuration on caller and host. Reload the host's Rex config after adding `dots_theme`.

- There is no broadcast. Only the caller and selected host are updated; other viewers can intentionally retain different themes.
- If local Rex is absent, state/desktop/Kitty changes still work. Rex is never started implicitly.
- A configured host that cannot be reached, an ambiguous local app, or a failed app/host action is an error. Changes already applied locally are retained. Retry an explicit mode, not another toggle.
- No watcher, client-side listener, application signal, or Neovim refresh is installed. Restart Neovim to read the state on its execution host. Other applications may or may not respond live.

## Sources

Color values mirror the customized counterparts in `config/kitty/themes/`, not the stock upstream presets. This includes foreground/background, cursor, selection, ANSI colors, and configured extended colors. Kitty-only tab, border, opacity, and contrast settings are not translated.

- **TokyoNight Day / Moon:** [Tokyo Night](https://github.com/folke/tokyonight.nvim), by Folke Lemaitre. [Upstream license](LICENSE-tokyonight).
- **Rose Pine Dawn / Moon:** Rosé Pine, by the Rosé Pine contributors. [Upstream license](LICENSE-rose-pine).

Only palette, foreground/background, cursor, and selection colors are included. Kitty retains its own format-specific theme files and terminal settings.
