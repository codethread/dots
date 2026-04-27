# Build Protocol

## Code Review Integration

`code-review` is an external CLI that invokes an LLM reviewer. It reads the current git diff and evaluates against the prompt you provide.

### Invocation

```bash
code-review "Implemented task 003 - Add priority filter dropdown: added a select component to the task list that filters by priority level, wired to the existing query parameter system"
```

Always describe:
- **What** was implemented (task title and ID)
- **Why** (the intent, not the implementation details)
- Reference the task from `tasks.yml` so the reviewer can assess alignment

### Handling Feedback

Review returns commentary. Classify each item:

- **Material**: changes correctness, performance, security, or maintainability — must fix
- **Style**: preferences that don't affect behaviour — fix if trivial, skip if not
- **Questions**: reviewer asking for clarification — these indicate unclear code, consider adding a comment

After addressing material feedback, re-run `code-review` with the same prompt. Maximum 3 cycles.

### Failure Modes

- If `code-review` is not on PATH: mark task `blocked`, note "code-review CLI not available"
- If review keeps finding new material issues after 3 cycles: commit what you have, note the unresolved items in the task's `notes` field

## progress.md Format

Append-only log at `.dev/<feature>/progress.md`. Two sections:

### Codebase Patterns (top of file, consolidated)

General, reusable patterns discovered during build. Updated as new patterns emerge. These persist across tasks — every `dev/build` invocation reads this section first.

```markdown
## Codebase Patterns

- Database queries use `sql<Type>` tagged template for type safety
- Always use `IF NOT EXISTS` in migrations
- React components import types from co-located `types.ts`
- Test files use `describe/it` not `test`
```

Only include patterns that help future iterations. Not task-specific details.

### Task Entries (appended per task)

```markdown
## [timestamp] - [task-id]: [task-title]

### What Was Done
Brief summary of implementation.

### Learnings
- Anything surprising discovered during implementation
- Gotchas for related future tasks
- Patterns that should be added to Codebase Patterns section

### Files Changed
- path/to/file.ts (created/modified)
```

## Failure Classification

### Blocked

Environmental issue the user can fix:

- Required service not running
- Missing environment variable
- Port already in use
- Missing binary on PATH
- Permissions issue

**Action**: set task status to `blocked`, describe the issue in notes, stop. User fixes and re-runs.

### Fatal

The plan is wrong:

- Task's acceptance criteria are contradictory
- Required file from a previous task doesn't exist or has wrong shape
- Circular quality failures (3+ attempts, same root cause)
- Task fundamentally can't be implemented as described

**Action**: set task status to `fatal`, explain in notes why the plan is wrong and what needs to change. User goes back to `dev/what` or `dev/how`.

**Never hack around a fatal** — the whole point of the phase system is that a bad plan gets fixed upstream, not patched downstream.
