# Pi Global Settings

This directory is symlinked to `~/.pi/agent` and holds shared Pi config.

Architecture: [specs/agentic-config.md](../specs/agentic-config.md). Container support: [specs/cc-sandbox.md](../specs/cc-sandbox.md).

## Tracked files

- `AGENTS.md` — startup working-style instructions
- `APPEND_SYSTEM.md` — globally appended system prompt text
- `settings.json` — global Pi settings

## Local state

Keep mutable machine-local state out of the repo:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/models.json`
- `~/.pi/agent/sessions/`

Dotty links tracked files into `~/.pi/agent/` and leaves local state untouched.

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
