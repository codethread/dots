# Pi Global Settings

This directory is symlinked to `~/.pi/agent` and holds the repo-owned Pi bootstrap/template config.

Most reusable Pi agents/skills now live in `https://github.com/codethread/agents`; this repo keeps the `agent.njk` template, minimal settings, and compatibility glue that let Pi consume that shared source.

`models.json` caps selected Anthropic 1M model metadata at 200k tokens so Pi auto-compacts before entering Anthropic long-context usage. Remove those `modelOverrides` when a session should use the full 1M window.

Architecture: [specs/agentic-config.md](../specs/agentic-config.md). Container support: [specs/cc-sandbox.md](../specs/cc-sandbox.md).
