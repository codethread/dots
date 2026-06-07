---
name: toil-workflows
description: >
  Toil workflow graph-shape index. Use when Toil needs to choose or explain the
  Pithos task graph shape for simple work, design-led work, or design/review
  chains.
---

# toil-workflows

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| SIMPLE | reference/simple.md | Thin simple execution chain example |
| DESIGN_REVIEW | reference/design-review.md | Thin design + execute + review example |

## Knowledge

This skill is intentionally an index. Read the reference file matching the task shape before enqueueing.

Available references:

- `reference/simple.md` — straightforward triage to execution.
- `reference/design-review.md` — design-led workflow with optional HITL review.

## Procedures

1. Classify the task shape:
   - simple implementation → read SIMPLE.
   - design or acceptance-sensitive work → read DESIGN_REVIEW.
2. Use the selected reference as the graph-shape scaffold.
3. Keep task bodies concise and name upstream task ids, scopes, branches, and existing artifacts when relevant.

## Constraints

- Do not create review tasks by default; only when requested or when the selected workflow requires HITL acceptance.
- Do not fan out more tasks than needed to move the chain forward.
- Do not duplicate reference details in this index; put details under `reference/`.

## Validation

- [ ] Selected graph shape matches task complexity.
- [ ] Enqueued tasks have clear capabilities and scopes.
- [ ] Any review/design gate is intentional and visible.
