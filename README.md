[![wakatime](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71.svg?style=flat-square)](https://wakatime.com/badge/user/80a39c88-3ac2-4995-beab-fef12c15afd1/project/f780b3f7-f18d-4655-afd7-a76b89cafd71)

> We measure our lives in the ways we develop and expand our knowledge through myriad variations. Nothing can take its place. It’s our very soul...
>
> There is no such thing as perfect in this world ... If something is perfect, then there is nothing left. There is no room for imagination.
>
> It is our job to create things more wonderful than anything before them, but never to obtain perfection.
>
> ― Kurotsuchi Mayuri

Run `make` to set up the workstation; `make help` lists the commands.

## Development workspace

Bun 1.4.2 manages the root formatting tools, `oven/` CLI tools, and `.workflows/` Busy Bee dependencies as one workspace with a single root `bun.lock`. Dependency declarations stay in each owning package; application configuration manifests under `config/` are excluded.

From the repository root:

```nu
bun install --frozen-lockfile
```

Run `make build` to verify and build Oven, or `bun run fmt:check` to check Markdown formatting. See [Oven](oven/README.md) and [workflows](.workflows/README.md) for package-specific commands.

<p align="center">
	<img width="460" src="https://64.media.tumblr.com/9f3abf18b67d35111b2b314463093517/tumblr_n8bzxpd3Kn1qzbqw1o1_400.gif">
</p>
