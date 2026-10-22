---
name: beads-triage
description: >
    Choose and coordinate repository work tracked with Beads using bv robot reports. Use when asked to figure out the next work, prioritize a backlog, plan parallel tracks, analyze dependency bottlenecks, or review project health. Not for implementing an assigned task or bead, recording work, or routine br status, notes, and closure.
---

# Beads triage

Use robot reports for work selection and coordination; bare `bv` launches an interactive TUI. Execution and tracker mutations belong to [hive](../hive/SKILL.md).

## Coordination workflow

1. For broad "what next?" requests, start with `bv --recipe _hive_work --robot-triage`. For a specific question, choose a focused report below.
2. Select from `triage.quick_ref.top_picks`; broader `recommendations` may be blocked or assigned. Inspect the suggested action's local ID, working directory and tracker route rather than using a namespaced display ID.
3. Recheck current state with `br show <id> --json` or `br ready --exclude-label system --json`. Analysis does not reserve work.
4. Return bead IDs, rationale, prerequisites and independent tracks where relevant. An analysis-only request does not authorize claims or mutations. When execution or delegation is also requested, hand the selected scope to the Hive workflow.

## Choose the focused report

Use `--recipe _hive_work` for every ordinary report; it excludes `system` and `busybee-workflow` beads. Beeswax owns the YAML-fenced definitions in `.bv/recipes.yaml`; generic and personal recipes remain user-owned.

Use `_hive_system` and `_hive_workflows` only for explicitly requested automation or workflow inspection. These views grant no execution authority: native Beads owns task state, assignments and readiness. Follow Bee/Colony or Busy Bee protocols for lifecycle changes.

| Need | Command |
| --- | --- |
| One ready recommendation | `bv --recipe _hive_work --robot-next` |
| Dependency-respecting parallel tracks | `bv --recipe _hive_work --robot-plan` |
| Top work per independent track | `bv --recipe _hive_work --robot-triage-by-track` |
| Top work per area | `bv --recipe _hive_work --robot-triage-by-label` |
| Explain why one issue is blocked | `bv --recipe _hive_work --robot-blocker-chain <id>` |
| Detect priority/graph-importance mismatch | `bv --recipe _hive_work --robot-priority` |
| Inspect graph metrics and cycles | `bv --recipe _hive_work --robot-insights` |
| Find staleness, cascades and mismatches | `bv --recipe _hive_work --robot-alerts` |
| Find duplicates, missing dependencies or label issues | `bv --recipe _hive_work --robot-suggest` |
| Search issue text | `bv --recipe _hive_work --robot-search --search "<query>"` |
| Export a dependency graph | `bv --recipe _hive_work --robot-graph --graph-format=json` |
| Compare with an earlier Beads snapshot | `bv --recipe _hive_work --robot-diff --diff-since <ref>` |

For graph output, `--graph-format` also accepts `dot` or `mermaid`; extract their `graph` field from the JSON envelope. Historical commands need a Beads export in the selected revision.

## Discover options and output

Read `bv --help` for report filters: `--label` scopes the graph, `--robot-by-label` filters applicable report results, and alerts use `--alert-label`. Keep `_hive_work` with each filter.

Use `bv --robot-docs commands` for command contracts, `bv --robot-capabilities` for installed capabilities, and `bv --robot-schema --schema-command robot-triage` for exact output fields. Discover recipe definitions with `bv --robot-recipes`. These discovery commands do not query work.

Check `mutates_state` before using unfamiliar robot commands: correlation confirmation and rejection write saved state.
