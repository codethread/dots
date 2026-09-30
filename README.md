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

## Mise services (macOS)

Mise owns cc-notify and Git maintenance; Nix currently installs mise through Homebrew. Service definitions live in `.mise/conf.d/`, while `mise.toml` holds tools and shared tasks. From this checkout, select `dev` or `work` explicitly:

```nu
mise -E dev tasks
mise -E dev bootstrap macos launchd-agents apply --dry-run
mise -E dev run services:apply
mise -E dev run services:status
```

On an existing Nix installation, switch the updated Nix configuration **before** applying the mise agents so both managers never run the same service. See [mise services](devflow/specs/mise-services.md) for first-time setup, migration, logs, and restart commands. No shell activation is required.

## Formatting

Install the development dependencies with `pnpm install`, then format Markdown with `pnpm fmt`. Use `pnpm fmt:check` to check formatting without writing changes. The pre-commit hook runs Oxfmt directly on staged Markdown files.

<p align="center">
	<img width="460" src="https://64.media.tumblr.com/9f3abf18b67d35111b2b314463093517/tumblr_n8bzxpd3Kn1qzbqw1o1_400.gif">
</p>
