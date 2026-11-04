# Rex palettes

`theme light`, `theme dark`, `theme toggle`, and `theme --family tokyonight|rose-pine` update Rex directly. These four self-contained palettes are linked into `~/.config/rex/themes` and imported with Rex's theme-import action. No other terminal app, palette export, or separate helper is required.

The switcher checks for a connected app with `rex --autostart=false client ls --json`. If Rex is unavailable or only a headless server is running, it skips Rex. Otherwise it sets the requested appearance mode and imports the selected palette. Stable filenames keep light/dark variants separate and let repeated imports reuse the same named custom themes. Rex is never auto-started; update errors from a running app fail the command visibly.

Set `REX_CLIENT` when multiple apps are connected. Run `theme` on the Mac running that app, since palette import reads a local file. After editing a palette, rerun `theme` with a mode or family to apply it; there is no watcher. Kitty, shell colors, Neovim, and macOS continue to share the existing mode/family state.

## Sources

- **TokyoNight Day / Moon:** [Tokyo Night](https://github.com/folke/tokyonight.nvim), by Folke Lemaitre. [Upstream license](LICENSE-tokyonight).
- **Rose Pine Dawn / Moon:** Rosé Pine, by the Rosé Pine contributors. [Upstream license](LICENSE-rose-pine).

Only palette, foreground/background, cursor, and selection colors are included. Kitty retains its own format-specific theme files and terminal settings.
