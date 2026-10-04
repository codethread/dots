[![wakatime](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71.svg?style=flat-square)](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71)

> We measure our lives in the ways we develop and expand our knowledge through myriad variations. Nothing can take its place. It’s our very soul...
>
> There is no such thing as perfect in this world ... If something is perfect, then there is nothing left. There is no room for imagination.
>
> It is our job to create things more wonderful than anything before them, but never to obtain perfection.
>
> ― Kurotsuchi Mayuri

## Workstation setup

Apple Silicon macOS, managed with mise and Homebrew:

```nu
# New machine (this is meant for me)
curl -fsSL https://raw.githubusercontent.com/codethread/dots/main/boot/boot.sh | bash -s --

# Existing machine, from this checkout
mise bootstrap --dry-run
mise bootstrap
mise bootstrap status

# Frequent updates
mise run llm:update
```

Select `dev`, `work`, or `personal` with `MISE_ENV` or `mise -E work bootstrap`. `make` is a shortcut for bootstrap; `make build` verifies/builds Oven. Use a durable checkout: services embed its path. Existing Nix installations must follow the [migration guide](docs/nix-to-mise.md) first.

Configuration has three distinct roles:

- **Project bootstrap:** `mise.toml` owns shared bootstrap resources, repo-local hooks, and `llm:update`; `mise.<profile>.toml` overlays machine differences. `.mise/conf.d/` contains only reusable entrypoints: `tools*.toml` links global tool sources, while environment-suffixed service links are enabled by `.miserc.toml`.
- **Shared service source:** `.mise/dev-work-services.toml` is not automatically loaded; `.mise/conf.d/services.dev.toml` and `.mise/conf.d/services.work.toml` symlink to it for dev/work only.
- **Global tools:** `config/mise/config*.toml` are CLI/tool configs linked by dotty into `~/.config/mise`, available outside dots, and reused through `.mise/conf.d/tools*.toml` before those links exist.

`.miserc.toml` controls discovery only, not another package list. Project bootstrap, global tools, and the explicit service source remain distinct.

Mise handles native resources; bootstrap hooks install repo-specific CLIs, build/link supporting tools, prepare shells, and verify service credentials before LaunchAgents load. Private repository access and credentials remain machine-local. `mise bootstrap --update` also updates declared repositories; ordinary bootstrap does not pull existing branches. Dirty checkouts stop setup—resolve them before applying.

Use native commands for targeted work: `mise install`, `mise upgrade`, `mise bootstrap packages status`, `mise dot diff`, or `mise bootstrap macos launchd-agents status`. Narrow applies do not prepare all dependencies; use full bootstrap for initial setup. No packages are pruned implicitly.

Details: [workstation](devflow/specs/mise-infra.md), [services](devflow/specs/mise-services.md), [shell environment](devflow/specs/shell-environment.md).

<p align="center">
	<img width="460" src="https://64.media.tumblr.com/9f3abf18b67d35111b2b314463093517/tumblr_n8bzxpd3Kn1qzbqw1o1_400.gif">
</p>
