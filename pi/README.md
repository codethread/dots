# Pi Global Settings

This directory is symlinked to `~/.pi/agent` and holds the repo-owned Pi bootstrap/template config.

Most reusable Pi agents/skills now live in `https://github.com/codethread/agents`; this repo keeps the `agent.njk` template, minimal settings, and compatibility glue that let Pi consume that shared source.

Architecture: [specs/agentic-config.md](../specs/agentic-config.md). Container support: [specs/cc-sandbox.md](../specs/cc-sandbox.md).

## Tracked files

- `agent.njk` — template for appended system prompt + repo-specific runtime instructions
- `README.md` — this overview
- `settings.json` — global Pi settings

## Local state

Keep mutable machine-local state out of the repo:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/models.json`
- `~/.pi/agent/sessions/`

Dotty links tracked files into `~/.pi/agent/` and leaves local state untouched. The shared Pi asset set comes from `codethread/agents`; this repo only owns the local template/bootstrap layer.

## Model flags

Use explicit `provider/modelId` for deterministic selection.

Forms:
- `--provider <provider> --model <model-id-or-pattern>`
- `--model <provider>/<model-id-or-pattern>`
- `--model <pattern>`
- `--model <pattern>:<thinking>` where thinking = `off|minimal|low|medium|high|xhigh`

Examples:
- `pi --model anthropic/claude-opus-4-6`
- `pi --provider openai --model gpt-5.4`
- `pi --model sonnet:high`

List available models on this machine:
- `pi --list-models`
- `pi --list-models sonnet`

If `--provider` / `--model` are omitted, Pi picks the initial model in this order:
1. CLI `--model`
2. Scoped models (`--models` / `/scoped-models`) first entry for new sessions
3. `settings.json`: `defaultProvider` + `defaultModel`
4. First authenticated available model, preferring Pi built-in provider defaults
5. Error if nothing is available

Tip: set `defaultProvider` and `defaultModel` in `settings.json` for stable startup defaults.
