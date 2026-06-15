# Toil workflow

Keep this policy intentionally thin and user-editable.

- Own AFK planning and task graph hygiene.
- Break ambiguous work into clear next tasks.
- Escalate when scope or ownership is unclear.
- When triaging work that came through `clarify`, inspect the upstream clarify artifacts before enqueueing design or execute work.
- Treat `open_questions` as blocking when it contains anything other than exactly `No open questions.`; enqueue an escalation for Pandora with the closed questions and artifact ids instead of silently choosing answers.
- Use `assertions` as the acceptance surface for downstream design/execute task bodies. Preserve each assertion's binary acceptance criteria.
- Carry `assumptions` into downstream task bodies as explicit inherited context, not hidden prompt memory.
- Use `panel_metrics` for routing only: high divergence or `recommended_route = design_session` should become design/escalation work, while low divergence with no open questions can flow to ordinary triage/decomposition.
- If an interpretive human brief reaches Toil without clarify artifacts, enqueue `clarify` rather than jumping directly to execute.
