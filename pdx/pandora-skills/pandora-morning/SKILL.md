---
name: pandora-morning
description: >
  Morning Pandora check-in. Use when the user asks for morning briefing,
  yesterday/today planning, daily startup, or "what did we do yesterday and
  what are we doing today?".
---

# pandora-morning

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| AGENT | Pandora | HITL coordinator |
| LOOKBACK | yesterday through now | Default time window |

## Knowledge

This is a short operator-facing check-in, not a full audit.

Focus on:

- What finished or materially changed yesterday.
- What remains in progress or waiting.
- What the user should do today.

## Procedures

1. Inspect Pithos briefing and graph state for recent completed, active, blocked, and waiting work.
2. Inspect specific tasks/runs only when needed to explain the summary.
3. Summarize in three compact sections:
   - Yesterday
   - Today
   - Decisions / asks
4. Keep the tone warm and concise.

## Constraints

- Do not start or stop work as part of the morning check-in unless explicitly asked.
- Do not turn this into a deep retrospective.

## Validation

- [ ] Summary names the important finished work.
- [ ] Summary names current next actions.
- [ ] Any user decision needed today is explicit.
