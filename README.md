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

Configuration is grouped in `.mise/conf.d/`: **packages**, **workstation**, **macos**, **services**, and shared **tools**. Profile fragments reuse global tool lists and the dev/work service declarations without duplication; `.miserc.toml` enables environment suffixes. Only `llm:update` is a custom task.

Mise handles native resources; bootstrap hooks install repo-specific CLIs, build/link supporting tools, prepare shells, and verify service credentials before LaunchAgents load. Private repository access and credentials remain machine-local. `mise bootstrap --update` also updates declared repositories; ordinary bootstrap does not pull existing branches. Dirty checkouts stop setup—resolve them before applying.

Use native commands for targeted work: `mise install`, `mise upgrade`, `mise bootstrap packages status`, `mise dot diff`, or `mise bootstrap macos launchd-agents status`. Narrow applies do not prepare all dependencies; use full bootstrap for initial setup. No packages are pruned implicitly.

Details: [workstation](devflow/specs/mise-infra.md), [services](devflow/specs/mise-services.md), [shell environment](devflow/specs/shell-environment.md).

<p align="center">
	<img width="460" src="https://64.media.tumblr.com/9f3abf18b67d35111b2b314463093517/tumblr_n8bzxpd3Kn1qzbqw1o1_400.gif">
</p>
