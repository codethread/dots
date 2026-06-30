---
name: strand
description: >
  Use `strand` cli for planning and tracking multi-step coding work. Trigger when
  the user asks to create strands, use strands, track work in Skein, build a task
  graph, inspect ready work, mark strands done, or when a non-trivial coding task
  would benefit from a small explicit DAG of work.
---

# Strand workflow

## When to use strands

- Skip strands for one small direct action.
- Create a strand plan for multi-step work, dependencies, validation, review, or
  when the user explicitly asks to use/manage strands.
- Keep plans small: usually 2-6 strands.
- Do not create a strand for every tiny sub-step.

## Workflow schema

Use only these planning attributes unless the user defines more:

- `feature=<feature-id-or-slug>` groups a plan under one feature/epic.
- `kind=plan|task|review` classifies the strand.
- `hitl=true` marks a human checkpoint. Omit it otherwise.

Use `active=false` for completion. Do not invent `status=done`.

Dependency reminder:

```text
A --edge depends-on:B  means  A is blocked by B
```

## Standard loop

1. Create or identify one feature/epic strand with `kind=plan`.
2. Add concrete task/review strands with the same `feature=...`.
3. Connect the feature to children with `parent-of` edges.
4. Add `depends-on` edges only for real blocking order.
5. Run `strand ready` and pick from ready work, not the full list.
6. If a ready strand has `hitl=true`, stop and ask the user before doing it.
7. Complete one ready strand or one tightly related pair.
8. Run relevant validation.
9. If new work is discovered, add/wire it before closing the current loop.
10. Mark completed strands inactive.
11. Repeat `strand ready` until done or blocked.

## Choice commands

Check the current CLI surface:

```sh
strand -h
```

Create a small plan:

```sh
strand add "Feature: <name>" --attr feature=<slug> --attr kind=plan
strand add "Implement <outcome>" --attr feature=<slug> --attr kind=task
strand add "Validate <outcome>" --attr feature=<slug> --attr kind=review
strand update <feature-id> --edge parent-of:<task-id> --edge parent-of:<review-id>
strand update <review-id> --edge depends-on:<task-id>
strand ready
```

Mark done:

```sh
strand update <id> --active false
```

Use a config dir explicitly for disposable or non-default worlds:

```sh
strand --config-dir <dir> ready
strand --config-dir <dir> update <id> --active false
```

One-shot REPL helpers when CLI is awkward:

```sh
printf '(ready)\n' | strand weaver repl --stdin
printf '(strands)\n' | strand weaver repl --stdin
```

Hot-reload selected config after config/library edits:

```sh
printf "(do (require '[skein.libs.alpha :as libs]) (libs/reload!))\n" \
  | strand weaver repl --stdin
```

Register a temporary named query for this weaver lifetime:

```sh
printf "(defquery! 'agent-owned '[:= [:attr :owner] \"agent\"])\n" \
  | strand weaver repl --stdin
strand list --query agent-owned
strand ready --query agent-owned
```

## Validation before reporting success

- `strand ready` matches the expected next work, or is empty because all planned
  work is inactive.
- Completed strands are inactive.
- Newly discovered work is represented by active strands.
- Dependencies reflect actual blocking relationships.
