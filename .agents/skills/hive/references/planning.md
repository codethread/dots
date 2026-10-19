# Plan Beads work

Use focused `br COMMAND --help` for fields and operations; apply prime's ordinary-work query filters when searching or selecting work.

Give each task a problem, bounded scope, source pointers and observable acceptance criteria. Distinguish reports, implementation and landing so completing advice does not close the work it examines.

## Dots task policy

Use `task` for scoped work, `bug` for defects, `feature` for new capability, `epic` for a larger effort, and `chore` or `docs` for maintenance or documentation. Priorities run P0 (critical) through P4 (backlog), with P2 for normal work. When a workflow requires an accountable human owner, use `ct` unless the request names another; preserve existing ownership. Owner, assignee and mutation actor are distinct.

Break multi-step work, especially features, into children with separate acceptance and verification; avoid splitting trivial work. Any task type can have children at as many levels as useful. Parent links group work; blocking dependencies record execution prerequisites. Use `br dep add --help` for dependency direction and options.

For delegated work, name writable paths, expected outputs, verification and boundaries with concurrent work. Keep integration and shared-file decisions with a named owner. Record newly discovered work beneath its existing scope; keep independent work separate.
