---
name: pandora-find-agents
description: >
  Use when the user asks Pandora to find running agent sessions outside Pithos,
  discover orphaned Claude/Pi/Codex/tmux agents, compare tmux agents against the
  pithos db, or audit agent panes not managed by pdx.
---

# pandora-find-agents

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| AGENT | Pandora | HITL coordinator |
| TMUX_SOURCE | `tmux-agent-switch --json` | Reuses the same agent-pane discovery logic as the interactive switcher |
| PDX_TMUX_PREFIX | `pdx--` | Pithos-managed tmux sessions use this prefix |
| SCOPE | global | Discovery/triage should happen outside any single repo/worktree |

## Knowledge

Pandora should use this skill to discover live agent panes that are running outside
Pandora's Box / Pithos supervision.

The local tmux convention for Pithos-managed agents is:

- `pdx--pandora`
- `pdx--greed-<session>`
- Any tmux session whose name starts with `pdx--`

Those panes are managed by pdx and must be filtered out. The target set is only
agentic panes whose tmux `session` does **not** start with `pdx--`.

`tmux-agent-switch --json` emits an array of candidate agent panes with fields like:

- `session`
- `window`
- `tool`
- `path`
- `pane_id`
- `window_target`
- `active`
- `preview`
- `session_type`
- `envy_repo`

This view is usually enough for Pandora's first pass. Do not scrape large pane
history unless the JSON preview is insufficient to identify the session record.

## Procedures

### 1. Discover non-pdx agent panes

Run:

```sh
tmux-agent-switch --json \
  | jq '[.[] | select(.session | startswith("pdx--") | not)]'
```

If `tmux-agent-switch` is unavailable but tmux is available, stop and report that
the discovery source is missing rather than inventing a different heuristic.

### 2. Compare against Pithos-owned state

Inspect the Pithos database/state only enough to confirm which live agents are
already known to pdx. Treat `pdx--*` tmux sessions as Pithos-owned even if a db
query is inconclusive.

Keep the candidate set to running agents outside pdx.

### 3. Delegate global triage

For every candidate or small batch of candidates, delegate triage in the **global**
scope. The triage brief should include the JSON object(s) from discovery and ask the
triager to use the appropriate session-introspection skill:

- Use `pi-session-introspection` for Pi sessions.
- Use `claude-session-introspection` for Claude sessions.
- If the harness/tool is unclear, identify the likely harness from the pane preview,
  process args, cwd, and session files, then use the matching skill.

The triage instruction must ask for a compact artifact back to Pandora, not a long
transcript dump.

Suggested triage brief:

```text
Global triage: inspect this running non-pdx agent pane and identify the underlying
session. Use pi-session-introspection or claude-session-introspection as appropriate.
Summarize only likely intent from user messages and agent responses; do not dig into
tool-call payloads unless needed to identify cwd/project/worktree.

Candidate JSON:
<json>

Return an artifact with: pane identity, harness/session id, cwd/project/worktree,
likely intent, workload class, status class, evidence, and uncertainties.
```

### 4. Session summary expectations

For each non-pdx agent session, triage should return an artifact containing:

```yaml
pane:
  session: "<tmux session>"
  window: "<tmux window>"
  pane_id: "<tmux pane id>"
  tool: "<pi|claude|codex|unknown>"
  path: "<tmux pane current path>"
harness:
  kind: "<pi|claude|codex|unknown>"
  session_id: "<session id or file path if found>"
context:
  cwd: "<current working directory>"
  project: "<project/repo name if clear>"
  worktree: "<branch/worktree path if clear>"
summary:
  likely_intent: "<what the user appears to have asked for>"
  recent_agent_state: "<what the agent appears to be doing / last meaningful response>"
classification:
  workload: "light|medium|heave"
  status: "active|waiting|done|unsure"
evidence:
  user_messages: "<short quoted/paraphrased evidence>"
  agent_responses: "<short quoted/paraphrased evidence>"
uncertainties:
  - "<anything unclear>"
```

Classification rules:

- `light`: short discussion, little or no implementation/investigation, narrow ask.
- `medium`: meaningful investigation or edits, several exchanges, moderate scope.
- `heave`: long discussion, broad investigation, substantial implementation, or many
  decisions/actions already taken.
- `active`: tool calls or command activity appear to be ongoing without a final agent
  message.
- `waiting`: the agent is clearly waiting on user input or has asked an open question.
- `done`: the agent has unambiguously completed and there are no more expected tool calls.
- `unsure`: safe default when status is ambiguous.

### 5. Report back to the user

After triage artifacts return, Pandora should discuss next steps with the user before
taking action. Good next-step options include:

- Leave the external sessions alone.
- Ask the user to close/archive sessions that are `done`.
- Bring useful context into Pithos as new intake/triage work.
- Attach triage artifacts to an existing Pithos task if the session clearly belongs there.
- Ask follow-up questions for `waiting` or `unsure` sessions.

## Constraints

- Do not include `pdx--*` tmux sessions in the orphan/non-pdx candidate list.
- Do not kill, interrupt, close, or take over external sessions during discovery.
- Do not surface large tool-call payloads by default; summarize intent from user
  messages and agent responses first.
- Do not silently import sessions into Pithos. Discuss next steps with the user after
  artifacts are returned.

## Validation

- [ ] Discovery uses `tmux-agent-switch --json` or reports why it cannot.
- [ ] `pdx--*` tmux sessions are filtered out.
- [ ] Triage is delegated in global scope.
- [ ] Pi/Claude introspection skills are used according to harness kind.
- [ ] Each session has cwd/project/worktree when available.
- [ ] Each session has `light|medium|heave` and `active|waiting|done|unsure` classifications.
- [ ] Pandora discusses next steps with the user before acting.
