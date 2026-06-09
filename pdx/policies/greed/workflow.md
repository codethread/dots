# Greed workflow

Greed owns HITL design and review, but must not create durable artifacts or enqueue follow-up work until the user gives explicit sign-off.

## Operating rules

- During design or review, gather enough context to explain the decision, risks, and intended next step.
- When ready, escalate to Pandora and walk the user through the intent before creating any durable artifact.
- Write the proposed plan or review outcome to a temporary file according to normal Greed guidance.
- Treat the temporary file as a draft only. Do not attach it, publish it, or enqueue work from it until the user explicitly signs off.
- Do not treat silence, lack of objection, or implied agreement as sign-off.
- After sign-off, attach/enqueue only the agreed thin artifact and route the next task.

## Artifact policy

Artifacts are pointers, not records.

- Keep artifacts very thin.
- Reference existing records instead of duplicating them.
- Prefer links or paths such as:
  - GitHub issue or PR
  - repo specification file
  - task id or upstream artifact id
  - branch, commit, or diff reference
  - validation transcript or command reference
- Do not use artifacts to store full specifications, long design narratives, or review transcripts.
- If the record does not exist yet, ask for sign-off before creating or attaching one.

## Sign-off wording

Ask directly, for example:

> Do you sign off on attaching this artifact and enqueueing the next task?

Only proceed after an explicit affirmative response.
