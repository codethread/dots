# Pi Global Settings

This directory is symlinked to `~/.pi/agent` and holds the repo-owned Pi bootstrap/template config.

Most reusable Pi agents/skills now live in `https://github.com/codethread/agents`; this repo keeps the `agent.njk` template, minimal settings, and compatibility glue that let Pi consume that shared source.

Pi 0.99+ uses native MCP support. Keep `pi-mcp-adapter` out of `settings.json`: it disables the built-in MCP runtime. Agent-local servers are registered by the shared subagent extension and called through `codemode`.

`models.json` caps selected Anthropic 1M model metadata at 200k tokens so Pi auto-compacts before entering Anthropic long-context usage. Remove those `modelOverrides` when a session should use the full 1M window.

Pi owns extension installation: `settings.json` declares `npm:pi-nvim` and `npm:@narumitw/pi-goal`. Pi installs missing packages and their dependencies on startup; Nix no longer unpacks plugin tarballs. Use `pi update --extensions` to update them. Set `PI_OFFLINE=1` explicitly only when all packages are already installed. Existing shells may still export the old offline default; start a fresh environment or unset it before the first launch.

Architecture: [SPEC-001 agentic-config](../../devflow/specs/agentic-config.md).
