# Simple workflow

```text
triage -> execute -> complete
```

Use for small, clear implementation work that does not need HITL design or review.

## Shape

1. Toil inspects the triage task and graph context.
2. Toil enqueues one `execute` task for War in the narrowest repo/worktree scope.
3. War completes or fails with changed files and validation evidence.

## Task body scaffold

Include:

- upstream task id
- target repo/worktree scope and path
- requested change
- relevant files or commands if known
- expected validation

## Constraints

- Avoid extra design/review tasks unless the user asked for them.
- Keep execution scope narrow and concrete.
