# Workflow

## Knowledge

Start by checking the CLI surface:

```sh
strand -h
```

A `depends-on` edge is directional: `A --edge depends-on:B` means **A is blocked by B**.

Prefer grouping planned work under a feature/epic strand. Give every strand in the plan a shared `feature=<feature-id-or-slug>` attribute, and connect the feature strand to child work with `parent-of` edges. This makes it easy to query/delegate ready work for one feature instead of the whole world.

Use only established workflow attributes:

- `feature=<feature-id-or-slug>` groups a plan under one feature/epic.
- `kind=task|plan|review` classifies the strand.
- `hitl=true|false` marks whether a human must be in the loop. Assume `hitl=false` when omitted.

Do not invent extra attributes. Add new schema only when the user explicitly defines it.

## Decisions

Entry state: CLASSIFY_WORK

### CLASSIFY_WORK

- guard: task is one small direct action
  → NO_STRAND_NEEDED
- guard: task has multiple steps, dependencies, validation, or review
  → CREATE_PLAN
- guard: user explicitly asks to create/manage strands
  → CREATE_PLAN

### CREATE_PLAN

- action: create a small DAG of strands
- always → WORK_READY

### WORK_READY

- action: run `strand ready`
- guard: ready strands exist and selected ready strand has `hitl=true`
  → HITL_CHECKPOINT
- guard: ready strands exist and selected ready strand does not have `hitl=true`
  → EXECUTE_ONE_READY_STRAND
- guard: no ready strands and active strands remain
  → INSPECT_BLOCKERS
- guard: no active strands remain
  → DONE

### HITL_CHECKPOINT

- terminal state; state the ready HITL strand back to the user and wait for further instructions before doing the work

### EXECUTE_ONE_READY_STRAND

- action: complete exactly one ready strand or a tightly related pair
- guard: work completed and validated locally
  → MARK_DONE
- guard: work reveals new required work
  → ADD_OR_UPDATE_STRANDS
- guard: work blocked by missing decision/input
  → STOP_AND_REPORT

### MARK_DONE

- action: mark completed strand inactive
- always → WORK_READY

### ADD_OR_UPDATE_STRANDS

- action: add new strand(s) and dependencies for newly discovered work
- always → WORK_READY

### INSPECT_BLOCKERS

- action: inspect active strands and their edges; report why nothing is ready
- terminal state unless user asks to change the plan

### NO_STRAND_NEEDED

- terminal state; do the direct task without creating strand noise

### STOP_AND_REPORT

- terminal state; report blocker, current strand, and needed input/decision

### DONE

- terminal state; all planned active strands are complete

## Procedures

### CREATE_PLAN

1. Keep plans small: 2-6 strands is usually enough.
2. Create or identify one feature/epic strand for the work.
3. Name strands as concrete outcomes, not vague activities.
4. Add a shared `feature=<feature-id-or-slug>` attribute to every strand in the plan.
5. Add `kind=plan` to the feature/epic strand, `kind=task` to implementation/work strands, and `kind=review` to review/checkpoint strands.
6. Add `hitl=true` only when the strand requires a human checkpoint. Omit `hitl` otherwise.
7. Connect the feature strand to each child work strand with `parent-of` edges.
8. Model `depends-on` edges only when they affect execution order.
9. Include validation and review as explicit strands when they can uncover more work.
10. Run `strand ready` after creating edges to confirm the graph behaves as expected.

Example CLI creation, copying ids from the JSON output:

```sh
strand add "Feature: JSON-only CLI and resilient config" --attr feature=json-cli-config --attr kind=plan
strand add "Remove format from config model" --attr feature=json-cli-config --attr kind=task
strand add "Make CLI output JSON-only" --attr feature=json-cli-config --attr kind=task
strand add "Review JSON-only CLI and resilient config" --attr feature=json-cli-config --attr kind=review --attr hitl=true
strand update <feature-id> --edge parent-of:<config-id> --edge parent-of:<cli-id> --edge parent-of:<review-id>
strand update <review-id> --edge depends-on:<config-id> --edge depends-on:<cli-id>
strand ready
```

For larger DAGs, prefer the REPL and batch creation patterns in `repl-usage.md`.

### EXECUTE_ONE_READY_STRAND

1. Pick from `strand ready`, not from the full active list.
2. If the selected ready strand has `hitl=true`, stop: state it back to the user and wait for further instructions.
3. Do the smallest coherent unit of work for that strand.
4. Run relevant validation before marking it inactive.
5. If validation/review uncovers follow-up work, create a new strand before closing the current workflow.

### MARK_DONE

Use active state as completion:

```sh
strand update <id> --active false
```

Do not invent `status=done`.

### ADD_OR_UPDATE_STRANDS

1. Add new strands for discovered work that is not part of the current strand's acceptance criteria.
2. Wire dependencies immediately.
3. Re-run `strand ready`.
4. Explain the graph change briefly if reporting to the user.

## Constraints

- Do not create a strand for every tiny sub-step.
- Do not invent attributes beyond the established workflow schema: `feature`, `kind`, and `hitl`.
- `kind` must be one of `task`, `plan`, or `review`.
- If a ready strand has `hitl=true`, do not perform it autonomously; report it and wait for human instruction.
- Do not mark validation/review strands done before review/validation has actually completed.
- Do not close all strands before incorporating review findings.
- Avoid opaque dependency webs; if the edge direction feels confusing, restate it in prose before applying it.
- Keep user-facing CLI usage JSON-oriented; do not rely on human formatting.
- When using a disposable or explicit world, include `--config-dir <dir>` on every command.

## Validation

Before reporting success:

- [ ] `strand ready` matches the expected next work or is empty because all planned work is inactive.
- [ ] Completed strands are inactive.
- [ ] Newly discovered work is represented by active strands.
- [ ] Dependencies reflect actual blocking relationships.
