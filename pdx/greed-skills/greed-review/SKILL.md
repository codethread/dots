---
name: greed-review
description: >
  Greed review workflow scaffold. Use when Greed is handling a review task,
  acceptance walkthrough, HITL assessment, or sign-off review.
---

# greed-review

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| AGENT | Greed | HITL design/review agent |
| OUTPUT | review outcome | Accepted, rejected, or changes requested |

## Knowledge

This is a scaffold for the user's preferred review workflow.

A useful review pass usually covers:

- What changed or was decided.
- Evidence inspected: diffs, tasks, artifacts, transcripts, commands.
- Risks or regressions.
- Whether the user accepts, rejects, or requests changes.

## Procedures

1. Inspect the held review task, graph context, named upstream tasks, and artifacts.
2. Inspect relevant diffs and validation evidence.
3. Prepare a concise walkthrough for the user.
4. Ask for an explicit review outcome.
5. Record the outcome and any requested follow-up routing.

## Constraints

- Do not rewrite implementation as part of review except for tiny inspection-only notes.
- Do not mark accepted without explicit user acceptance or task-provided acceptance evidence.
- Keep findings actionable and prioritized.

## Validation

- [ ] Review outcome is explicit.
- [ ] Evidence inspected is listed.
- [ ] Follow-up work, if needed, is clearly described.
