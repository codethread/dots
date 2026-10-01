[![wakatime](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71.svg?style=flat-square)](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71)

> We measure our lives in the ways we develop and expand our knowledge through myriad variations. Nothing can take its place. It’s our very soul...
>
> There is no such thing as perfect in this world ... If something is perfect, then there is nothing left. There is no room for imagination.
>
> It is our job to create things more wonderful than anything before them, but never to obtain perfection.
>
> ― Kurotsuchi Mayuri

```sh
# Install Dotfiles (this is meant for me)
curl -fsSL https://raw.githubusercontent.com/codethread/dots/main/boot/boot.sh | DOTFILES="$HOME/dev/dots" bash -s --
```

## Mise packages and services (macOS)

Mise owns user CLI packages, language runtimes, agent CLIs, macOS host packages, cc-notify, and Git maintenance. Global tool defaults live in `config/mise/config.toml` and are linked by dotty; `.mise/conf.d/tools.toml` loads the same definitions in this checkout. `boot/boot.sh` installs Homebrew and mise (`brew install mise`), then applies packages with `mise -C "$DOTFILES" -E <mise-profile> run packages:apply` before the Nix switch and `workstation:setup` afterwards; `work-adamhall-boot` maps to the `work-boot` mise profile. Package lists live in `.mise/conf.d/packages.toml` plus `mise.{dev,work,personal,work-boot}.toml`, while `mise.toml` holds the service Bun pin and shared tasks. From this checkout, select `dev` or `work` explicitly:

```nu
mise -E dev run packages:apply
mise -E dev run packages:status
mise -E dev run workstation:apply # packages, repos, dotfiles, shell caches; no services
mise -E dev bootstrap packages apply --dry-run

mise -E dev tasks
mise -E dev bootstrap macos launchd-agents apply --dry-run
mise -E dev run services:apply
mise -E dev run services:status
```

`packages:apply` installs versioned tools and host packages, builds the pinned Todoist fork, then installs user-prefix `@playwright/cli` and VS Code extensions; the dry run previews host packages only. Applying packages never prunes unlisted packages or upgrades existing formulae, and `mise install` covers versioned tools only. Upgrade Homebrew formulae explicitly with `mise -E dev bootstrap packages upgrade --manager brew`.

On an existing Nix installation, switch the updated Nix configuration **before** applying the mise agents so both managers never run the same service. Nix no longer installs or upgrades Homebrew packages. See [mise services](devflow/specs/mise-services.md) for first-time setup, migration, logs, and restart commands; [docs/mise.md](docs/mise.md) has the full command cheat sheet. No shell activation is required.

## Claude Code settings

Mise renders global Claude settings from `templates/claude-settings.json.tera`, with profile-specific plugins selected by `mise.dev.toml` / `mise.work.toml`. Apply settings from this checkout:

```nu
mise -E dev run claude:apply
mise -E dev run claude:status
```

Use `-E work` on a work machine. See [Claude settings](claude/README.md) for previews, plugin opt-ins, and ownership details. Applying settings does not apply services.

## Formatting

Install the development dependencies with `pnpm install`, then format Markdown with `pnpm fmt`. Use `pnpm fmt:check` to check formatting without writing changes. The pre-commit hook runs Oxfmt directly on staged Markdown files.

<p align="center">
	<img width="460" src="https://64.media.tumblr.com/9f3abf18b67d35111b2b314463093517/tumblr_n8bzxpd3Kn1qzbqw1o1_400.gif">
</p>
