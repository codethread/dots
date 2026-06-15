---
name: clarify-judge
description: >
  Envy clarify workflow. Use when Envy has claimed a `clarify` task or needs to
  measure ambiguity in an interpretive human brief before routing to triage.
---

# clarify-judge

## Knowledge

`clarify` measures ambiguity; it does not resolve material ambiguity. Envy stays faithful to the source brief and records what the reader panel shows.

Use the Pi `clarify-panel` swarm to fan out independent interpretations. The panel members are intentionally isolated:

- literalist reader
- minimalist reader
- maximalist reader
- hostile reader
- precedent reader

Pithos does not know about the panel. Pithos only enforces that the held `clarify` task records the artifacts configured in `$PDX_USER_DATA_DIR/artifacts.toml` before completion.

Configured artifact kinds for `clarify` are expected to include:

- `open_questions`
- `assertions`
- `assumptions`
- `panel_metrics`

Use the generated Artifact Contract prompt block as the source of truth if it differs from this skill.

## Procedures

### 1. Inspect the held clarify task

1. Inspect the task and graph context.
2. Identify the source brief, scope, repo/worktree path, and any attached context.
3. Preserve source wording. Do not rewrite the user's intent as your own interpretation.

### 2. Run the reader panel

Call the Pi subagent swarm named `clarify-panel` with the same brief and relevant context for every member.

Use a task prompt shaped like:

```text
Interpret this brief for a Pandora's Box clarify task.

Held task: <task-id>
Scope: <scope id/kind/path>
Source/context tasks or artifacts: <ids if relevant>
Brief:
<verbatim task body or source brief>

Return your required headings. Do not coordinate with other readers.
```

Set `cwd` to the repo/worktree path when available; otherwise use the current working directory.

### 3. Judge divergence

Compare the panel outputs. Do not average away disagreement.

Classify each divergence:

- **material**: affects architecture, scope, user-visible behavior, data/state semantics, validation, safety, or acceptance
- **non-material**: naming, ordering, formatting, or implementation detail that can be defaulted without changing user intent

Record material divergence as closed questions where possible. Record non-material defaults as assumptions.

### 4. Write artifacts

Attach artifacts to the held clarify task using the current fencing token.

Use `pithos task artifact add <task-id> --token <token> --kind <kind> --title <title> --stdin`.

#### `open_questions`

Markdown body:

- If material questions exist, write a numbered list.
- Prefer closed questions with recommended default where honest.
- If none exist, write exactly: `No open questions.`

#### `assertions`

Markdown body:

- Include only contested or divergence-derived assertions, not a summary of the whole brief.
- Each assertion must be one atomic claim.
- Each assertion must include at least one binary acceptance criterion.
- Use Given/When/Then or an executable check when practical.

#### `assumptions`

Markdown body:

- List non-material default decisions.
- Include the reason for each default, usually panel convergence or repo precedent.
- Do not hide material ambiguity here.

#### `panel_metrics`

Markdown body with terse bullets:

- `reader_count`: number of successful panel members
- `divergence`: `low | medium | high`
- `material_question_count`: count
- `assertion_count`: count
- `precedent_signal`: `none | weak | mixed | strong`
- `recommended_route`: `triage | escalate_for_questions | design_session`

### 5. Route follow-up

- If `open_questions` has material questions, enqueue an `escalate` task for Pandora with the closed questions and relevant artifact ids.
- If no material questions remain, enqueue `triage` with artifact ids and a concise handoff.
- Complete the `clarify` task only after required artifacts are attached.

## Constraints

- Do not answer material questions yourself.
- Do not treat a broad interpretation as chosen unless the brief supports it.
- Do not summarize the brief as `assertions`; assertions are selected from divergence.
- Do not proceed to `execute` from `clarify`.
- If a panel member fails, record it in `panel_metrics`; do not fabricate its view.
- If the swarm is unavailable, perform sequential persona reads yourself and record the weaker isolation in `panel_metrics`.

## Validation

Before completing the clarify task:

- [ ] Reader panel outputs were compared, not merged blindly.
- [ ] Material divergences became `open_questions`.
- [ ] Non-material defaults became `assumptions`.
- [ ] Contested claims with binary acceptance criteria became `assertions`.
- [ ] `panel_metrics` records reader count, divergence, and route.
- [ ] Required artifacts from the generated Artifact Contract are attached and active.
