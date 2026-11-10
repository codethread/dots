---
name: align-agent-instructions
description: sync the agent instructions
argument-hint: [accurate-file]
disable-model-invocation: true
---

Maintain shared rules in @templates/agents/common.md and harness-specific additions in @templates/agents/claude.md.tera, @templates/agents/codex.md.tera, and @templates/agents/pi.md.tera. Keep Pi's session-dependent rules in @pi/agent/agent.njk.

- Read @templates/agents/README.md for deployment and loading behavior.
- Inspect git status/history to preserve intentional harness differences.
- Keep shared rules in the common base once; fix typos and grammar where needed.
- Preview the three generated files with `mise dot diff` before applying. Apply only when requested, using `mise run link`.
- For Pi's runtime template variables, consult `~/dev/projects/agents/pi/extensions/system-prompt/README.md`.
