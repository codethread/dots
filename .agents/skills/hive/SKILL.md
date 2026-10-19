---
name: hive
description: Plan, carry out and hand off Beads-tracked work in repositories using Hive. Use when recording work, choosing a task, implementing an assigned bead or coordinating a workflow run.
---

# Work with Hive in dots

This skill holds dots workflow choices. Installed CLI help and bundled instructions own command procedures. Load `beeswax prime` only if its shared safety and tool pointers are absent from context.

## Route the request

```text
Request
  |
  +-- Inspect an ID or answer a question --> read and report
  +-- Record work only ------------------> capture scope; stop before claiming
  +-- Perform supplied work ------------> inspect its brief and acceptance
  +-- Choose work ----------------------> select a candidate; inspect it
```

Start with `br show ID --json` for supplied work; do not run triage to replace it. Questions need no bookkeeping task. Reuse existing scope; search only when the request leaves the task unidentified. For backlog selection or coordination analysis, use [beads-triage](../beads-triage/SKILL.md).

Before creating tasks or changing scope or dependencies, read [planning](references/planning.md). Recording work alone does not authorize tracker publication.

## Carry the work through

Before claiming, delegating, updating progress, closing work or publishing tracker changes, read [coordination](references/coordination.md).

For a supplied Busy Bee run, follow `busybee skills get workflow-execution` and its active briefs. Continue the saved run on retry; additional workflow work belongs beneath that run.

Use the repository's verification and review gates. Report changed behavior, evidence, unresolved work and retained task/result IDs.
