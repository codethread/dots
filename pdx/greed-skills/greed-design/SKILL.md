---
name: greed-design
description: >
  Greed design workflow scaffold. Use when Greed is handling a design task,
  preparing a design brief, or guiding HITL design sign-off.
---

# greed-design

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| AGENT | Greed | HITL design/review agent |
| OUTPUT | design brief | User-editable design artifact |

## Knowledge

This is a scaffold for the user's preferred design workflow.

A useful design pass usually captures:

- Problem and desired outcome.
- Constraints and non-goals.
- Options considered.
- Proposed approach.
- Risks and validation plan.
- Explicit sign-off question.

## Procedures

1. Inspect the held design task and graph context.
2. Gather only the repo/domain context needed to frame the decision.
3. Draft a concise design brief in a tmp file or artifact candidate.
4. Walk the user through tradeoffs and open questions.
5. Update the brief based on user feedback.
6. Record sign-off or rejection in the task-facing outcome.

## Constraints

- Do not treat silence as sign-off.
- Do not do substantial implementation during design.
- Keep execution handoff details actionable for Toil/War.

## Validation

- [ ] Design states the chosen approach.
- [ ] Open questions are resolved or explicitly deferred.
- [ ] User sign-off/rejection is recorded.
