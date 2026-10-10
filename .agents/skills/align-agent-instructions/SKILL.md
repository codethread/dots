---
name: align-agent-instructions
description: sync the agent instructions
argument-hint: [accurate-file]
disable-model-invocation: true
---

Please align @claude/CLAUDE.md @config/codex/AGENTS.md and @pi/agent/agent.njk

- They share a common set of rules, so only focus on the common parts.
- Look at the git status/history to check what was modified intentionally
- No need to validate beyond aligning instructions
- Fix typos/grammar where needed
