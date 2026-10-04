# Pi Global Settings

Files from this directory are symlinked into `~/.pi/agent` and hold the repo-owned Pi bootstrap/template config. Runtime installations, credentials, and sessions stay outside the repository.

Most reusable Pi agents/skills now live in `https://github.com/codethread/agents`; this repo keeps the `agent.njk` template, minimal settings, and compatibility glue that let Pi consume that shared source.

Pi uses native MCP support. Keep `pi-mcp-adapter` out of `settings.json`: it disables the built-in MCP runtime. Agent-local servers are registered by the shared subagent extension and called through `codemode`.

`models.json` caps selected Anthropic 1M model metadata at 200k tokens so Pi auto-compacts before entering Anthropic long-context usage. Remove those `modelOverrides` when a session should use the full 1M window.

Pi owns extension installation: `settings.json` declares `npm:pi-nvim` and `npm:@narumitw/pi-goal`, installed with their dependencies on startup.

Agent CLIs are installed by `boot/setup.sh` during `mise bootstrap`; use `mise run llm:update` to update them and Pi's extensions. The update task lives in [mise.toml](../../mise.toml).

Pi's official managed launcher lives at `$PI_CODING_AGENT_DIR/bin/pi` (default `~/.pi/agent/bin/pi`), after `~/.local/bin` on PATH so the pies wrapper stays in control. `mise bootstrap --update` updates declared repositories, then setup builds and links the `pi`/`pies` wrappers. Plain `mise bootstrap` does not pull current branches. It does not restart a running Pies daemon.

Architecture: [SPEC-001 agentic-config](../../devflow/specs/agentic-config.md).
