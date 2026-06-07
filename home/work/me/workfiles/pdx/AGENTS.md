This folder contains Pandora's Box user configuration.
Read `PANDORA.md` before any changes. It is gitignored and generated/refreshed by `pdx open` to provide up-to-date bundled Pandora's Box instructions, so it may exist locally even though it is not visible in git/project listings.
Validate rendering with `pandora-spawn preview` after changes when the command is available.

# Workflow policy layout guidance

Use this when writing or revising workflow/policy documents such as `pdx/policies/*/workflow*.md`.

## Goal

Make workflows clear for both humans and agents without creating multiple competing sources of truth.

Use three layers:

1. **Graphviz DOT** for the macro structure.
2. **Terse ASCII scan lines** under recipe/headings for local flow shape.
3. **Prose bullets** for authoritative operational rules.

The prose remains authoritative for exact behaviour. Diagrams and scan lines exist to make structure easier to see and to reduce accidental contradictions in long prose.

## Why this balance

Long prose can lose clarity as policies grow. It is easy for separate paragraphs to imply incompatible ordering, ownership, or feedback rules.

A DOT graph helps because it makes structural constraints visible:

- lifecycle order
- major decision points
- delegation boundaries
- feedback loops
- fan-out / fan-in points
- escalation routes

But DOT should not become a second full state machine unless that is the explicit goal. Over-modelled diagrams become harder to maintain and can drift from the prose.

ASCII scan lines help because they are cheap, raw-markdown-friendly mnemonics. They are better than DOT for simple per-recipe sequences.

## Recommended document shape

````md
# Policy title

Short ownership / intent summary.

The prose is authoritative. The graph is a non-exhaustive structural aid.

## Workflow map

```dot
digraph ExampleWorkflow {
  // Policy notes and graph scope.
}
```
````

## Recipes

### Standard recipe

```text
req -> triage -> execute[N] -> fan-in -> review? -> release
```

Detailed rules...

````

## DOT guidance

Use Graphviz DOT for the top-level workflow map when the policy has real structure.

Good DOT content:

- the normal lifecycle path
- core phase ordering, e.g. `plan -> build -> assess -> release`
- major ambiguity/escalation gates
- key ownership/delegation boundaries
- common feedback loops
- fan-out / fan-in points when multiple tasks can run in parallel

Avoid trying to graph every recipe branch, exception, or failure class. Put those in prose unless the graph remains readable.

Always add comments that explain graph scope and ownership, for example:

```dot
// POLICY NOTE:
// - Toil owns workflow shape.
// - War owns source/code changes.
// - Greed owns delegated design/review work.
//
// The surrounding prose is authoritative for exact operational detail.
// This graph is a navigation aid and structural constraint map.
// Recipe-specific branches and detailed failure handling may be described in prose.
````

Custom DOT attributes such as `owner`, `phase`, and `delegates_to` are acceptable as metadata for agent readers, but Graphviz may not render them. Prefer visible labels or comments for anything humans must see.

Avoid hidden attributes like `meaning` or `action` when they duplicate prose; they create extra drift points.

## ASCII scan-line guidance

Use terse ASCII directly under each recipe or workflow heading when a compact local view helps scanning.

Use this style:

```text
req -> triage -> War execute[N] -> fan-in -> Greed review? -> release checkpoint -> merge/MR
```

Conventions:

- `?` means optional or conditional.
- `[N]` means one or more tasks may fan out.
- `fan-in` means all parallel work must complete before the next checkpoint.
- Use actor names when ownership matters: `War execute`, `Greed review`, `Toil triage`.
- Keep scan lines mnemonic, not exhaustive.

Use ASCII instead of DOT for these local recipe summaries because it is easier to read in raw markdown, cheaper to maintain, and less likely to become a competing state machine.

## Prose guidance

Use prose bullets for exact operational rules:

- what triggers the recipe
- who owns each step
- what must be enqueued or validated
- what must not happen
- how failures route
- when to escalate

If the document uses lifecycle phases and concrete task types, add a bridge sentence/table explaining the mapping. Example:

```md
The notes below describe concrete task types used inside the four lifecycle phases; they are not additional lifecycle phases. `design` and `breakdown` feed planning, `execute` is the build handoff, `validate` provides assessment/release evidence, and `merge` / `merge-request` are release actions.
```

## Maintainability checks

Before finishing a workflow-policy edit, check:

- Does the DOT graph claim to be exhaustive? If not, say what it omits.
- Do graph labels match prose terminology?
- Are ownership/delegation boundaries visible, not only hidden in DOT attributes?
- Are fan-out/fan-in points explicit where multiple tasks can run in parallel?
- Are optional steps marked with `?` in scan lines?
- Is there one authoritative source for exact behaviour? Usually prose.
- Could a human understand the rendered diagram and an agent understand the raw markdown?
