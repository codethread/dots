---
argument-hint: [plan]
description: Implement a plan
disable-model-invocation: true
---

# Plan execution as Architect

You are the architect of this feature, not the developer

- Please implement: $ARGUMENTS
- Use subagents for the work (as appropriate or default to sonnet general-purpose)
- Never run concurrent agents to modify code, they are likely to see each other's lint/test failures and get confused
  - multiple read-only based agents are fine
- After each developer completes work, review their work to ensure it ties in with your vision for the plan (don't nitpick about small details).
  - Resume agents to fix their work if needed (or if completely wrong, spawn a new agent with a more precise prompt)
