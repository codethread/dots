---
name: beads-triage
description: >
  Choose and coordinate repository work tracked with Beads using bv robot reports. Use when asked to figure out the next work, prioritize a backlog, plan parallel tracks, analyze dependency bottlenecks, or review project health. Not for implementing an assigned task or bead, recording work, or routine br status, notes, and closure.
---

# Beads triage

Use `bv` to decide what should be done and how work should be coordinated. Routine execution and tracker mutations belong to the `br` workflow in repository `AGENTS.md`; an assigned task does not need a viewer report first.

Never run bare `bv`: it launches an interactive TUI that blocks an agent session. Do not parse `.beads/issues.jsonl` directly or edit it manually.

## Coordination workflow

1. For broad "what next?" requests, start with `bv --robot-triage`. For a specific coordination question, use the focused report below instead.
2. When selecting from triage, use `triage.quick_ref.top_picks`, which reflects current snapshot readiness. Treat broader `recommendations` as analysis: they may be blocked or assigned.
3. Inspect the suggested action's local ID, working directory, tracker route, and reasons. Use that route rather than a namespaced display ID.
4. Recheck current state with `br show <id> --json` or `br ready --json` before recommending or handing off work. Analysis does not reserve work.
5. Return a recommendation or plan with bead IDs, rationale, prerequisites, and independent tracks where relevant. Do not claim or mutate work for an analysis-only request. If also asked to execute or delegate, hand off to the repository's `br` workflow with the selected IDs and scope.

## Choose the focused report

| Need | Command |
| --- | --- |
| One claimable recommendation | `bv --robot-next` |
| Dependency-respecting parallel tracks | `bv --robot-plan` |
| Top work per independent track | `bv --robot-triage-by-track` |
| Top work per area | `bv --robot-triage-by-label` |
| Explain why one issue is blocked | `bv --robot-blocker-chain <id>` |
| Detect priority/graph-importance mismatch | `bv --robot-priority` |
| Inspect graph metrics and cycles | `bv --robot-insights` |
| Find staleness, cascades, and mismatches | `bv --robot-alerts` |
| Find duplicates, missing dependencies, or label issues | `bv --robot-suggest` |
| Search issue text | `bv --robot-search --search "<query>"` |
| Export a dependency graph | `bv --robot-graph --graph-format=json\|dot\|mermaid` |
| Compare with an earlier Beads snapshot | `bv --robot-diff --diff-since <ref>` |

For graph DOT or Mermaid output, extract the `graph` field from the JSON envelope. Historical commands work only when the selected revision contains a Beads export.

## Scope and recipes

- `--label <label>` scopes graph analysis to that label's subgraph.
- `--robot-by-label <label>` filters applicable robot report results without redefining the graph scope.
- Alerts use `--alert-label <label>` plus optional `--severity` or `--alert-type` filters.
- Use `--recipe actionable` for unblocked work, `--recipe high-impact` for graph-important work, and `--recipe quick-wins` for small ready items.
- Run `bv --robot-recipes` rather than guessing other recipe names.

Examples:

```text
bv --robot-plan --label backend
bv --recipe actionable --robot-plan
bv --recipe high-impact --robot-triage
bv --robot-alerts --alert-label backend --severity critical
```

## Discover the installed contract

When flags, fields, or version behavior matter, ask the installed tool instead of relying on remembered output:

```text
bv --robot-docs commands
bv --robot-capabilities
bv --robot-schema --schema-command robot-triage
```

Most robot analysis commands emit one JSON object by default. `--robot-help` is human-readable text. The correlation feedback commands `--robot-confirm-correlation` and `--robot-reject-correlation` mutate saved state; do not treat every `--robot-*` command as read-only.
