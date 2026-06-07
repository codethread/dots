# Design + review workflow

```text
triage -> design(HITL) -> execute -> review?(HITL) -> complete
```

Use when the work needs explicit planning, tradeoff discussion, acceptance review, or user sign-off.

## Shape

1. Toil enqueues `design` for Greed when the approach needs HITL planning.
2. Greed records design outcome and sign-off evidence.
3. Toil or the continued chain enqueues `execute` for War with the signed-off design context.
4. Enqueue `review` for Greed only when requested or when the task explicitly requires acceptance/sign-off after execution.

## Task body scaffold

Design task:

- problem statement
- constraints/non-goals
- decision needed
- expected output artifact or brief

Execute task:

- upstream design task id
- approved approach summary
- target repo/worktree scope and path
- validation expectations

Review task:

- upstream execute task id
- review focus
- evidence to inspect
- acceptance question

## Constraints

- Do not assume design approval from silence.
- Do not make review automatic for every execution task.
- Keep gates and dependencies explicit when multiple execution tasks fan out.
