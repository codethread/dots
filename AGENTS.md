# Dotfiles Monorepo

- Completion requires every matching check in [docs/verification.md](docs/verification.md). Report each result and every exact untested behavior or blocker; partial previews are not completion evidence.
- Before changing profiles, deployment, bootstrap ordering, or application ownership, read [docs/components.md](docs/components.md).
- Run mise from the checkout: `mise -C` from elsewhere misses early `.miserc.toml` discovery.
- Use the root Bun workspace and lockfile; declare dependencies in their owning package.
- Keep `core.hooksPath = .githooks`; staged Markdown and Nushell are formatted at commit.
- `templates/agents/` and `pi/agent/agent.njk` are deployed global policy, not contribution guides.
- Tool removal includes owned documentation and direct consumers in one `GOODBYE <tool>` commit, with the reason in its body.
