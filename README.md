[![wakatime](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71.svg?style=flat-square)](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71)

> We measure our lives in the ways we develop and expand our knowledge through myriad variations. Nothing can take its place. It’s our very soul...
>
> There is no such thing as perfect in this world ... If something is perfect, then there is nothing left. There is no room for imagination.
>
> It is our job to create things more wonderful than anything before them, but never to obtain perfection.
>
> ― Kurotsuchi Mayuri

```sh
curl -fsSL https://raw.githubusercontent.com/codethread/dots/main/boot/boot.sh | bash -s --
# Append `-p dev`, `-p work`, or `-p personal` after `--` to select a profile explicitly.
```

[Botlake operations](docs/botlake.md) describes the Homebrew CLI and mise-managed supervisor, including upgrades and restarts. The repository lake selects Mail with identity links, automatic live delivery, and five-minute agent resumption.

## Checkout development

With mise installed and this checkout trusted, run `mise run setup:repo` from the repository root to install the root Bun workspace (Oven and the Botlake lake) and activate `.githooks`. Unlike the default `mise run`, this does not converge the workstation. See [verification](docs/verification.md) for required checks; `mise run build` also checks repository setup and lake code.

`bun run changelog` displays [recorded history](changelog.json); `bun run changelog:generate` regenerates [CHANGELOG.md](CHANGELOG.md), and `bun run changelog:check` verifies it. Dots has no release version today, so history starts empty rather than assigning a version or inventing earlier release notes. Add curated stable-version entries when releases are established. The shared renderer is pinned to an upstream Git commit until it is published to npm.

<p align="center">
	<img width="460" src="https://64.media.tumblr.com/9f3abf18b67d35111b2b314463093517/tumblr_n8bzxpd3Kn1qzbqw1o1_400.gif">
</p>
