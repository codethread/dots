---
name: strands
description: >
  Use `strand` cli for planning and tracking multi-step coding work. Trigger when
  the user asks to create strands, use strands, track work in Skein, build a task
  graph, inspect ready work, mark strands done, or when a non-trivial coding task
  would benefit from a small explicit DAG of work.
---

# Strands (powered by Skein)

Use strands as a live execution plan for multi-step work.

Read and follow `references/workflow.md` for the standard workflow.

Additional references:

- `<skill-dir>/references/repl-usage.md` — use when the REPL is available or when creating richer DAGs than the CLI comfortably supports.
- `<skill-dir>/references/adding-queries.md` — use when adding named queries or config-backed views over strands.

Userland Skein config lives in `~/.config/skein/`; check that directory when you need to inspect or update config-backed queries/views/helpers for the user's default world.
