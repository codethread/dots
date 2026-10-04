# Claude Code Global Settings

This directory is symlinked to `~/.claude` and shares global Claude Code settings between machines.

Custom directories (those not carrying Claude Code significance like `agents/` or `commands/`) are prefixed with `x-` for clarity and to avoid accidental name collision.

> **Architecture details**: See [SPEC-001 agentic-config](../devflow/specs/agentic-config.md) for the full configuration architecture (settings generation, hook contracts, type system, design decisions).

## Settings Source of Truth

The global `~/.claude/settings.json` is a **regular file rendered by mise** from `templates/claude-settings.json.tera`. Edit the template, then apply it; edits to the generated file are overwritten on the next apply. The resource lives in root `mise.toml`. The `.claude/settings.json` in this repo is project-local settings (for this repo only) and `.claude/settings.local.json` is the local override.

### Apply

From the dots checkout (mise 2026.9.15 or newer):

```nu
mise dot apply ~/.claude/settings.json
mise dot status
```

Use `-E work` for work-only marketplaces/plugins. Without an overlay, the personal/dev plugin set is used. `/tmp/claude` is declared in root `mise.toml` and prepared by the native files phase, not `mise dot apply`. Bash is resolved from PATH when rendering.

Other Claude assets remain managed by dotty; project-local settings and local overrides are untouched.

## cc-notify (Push Notifications)

iOS push notifications via Pushover, triggered by Claude Code hooks.

- **Source**: `~/dev/projects/cc-notify` (Effect + Bun HTTP server)
- **API**: `POST /notify`, `POST /activity`, `GET /toggle`, `GET /health`
- **Gated by**: mise variable `claude_enable_notify` (defaults to `false`, as before)

To enable the plugin, add this to the checkout's untracked `mise.local.toml`, then rerun `mise dot apply ~/.claude/settings.json`:

```toml
[vars]
claude_enable_notify = true
```

The plugin opt-in is independent of daemon ownership. Prepare/apply the daemon with `mise bootstrap`; see [mise services](../devflow/specs/mise-services.md).

## Agents

### Active (`claude/agents/`)

| Agent          | Model  | Purpose                                     |
| -------------- | ------ | ------------------------------------------- |
| api-researcher | haiku  | API documentation research via context7 MCP |
| browser-user   | sonnet | Browser interaction via playwright-cli      |

### Disabled (`claude/x-agents/`)

| Agent            | Model  | Purpose                                      |
| ---------------- | ------ | -------------------------------------------- |
| browser-devtools | sonnet | DevTools diagnostics via chrome-devtools MCP |

## Skills

| Skill              | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| commit (ct:commit) | Conventional commits with auto status/diff injection |
| playwright-cli     | Browser automation with 7 reference docs             |
| wktree             | Local git worktree workflow via `wk`/`wktree`        |

## Slash Commands

| Command            | Purpose                                   |
| ------------------ | ----------------------------------------- |
| /github \<number\> | Read GitHub issues/PRs with image support |
| /ct:speak [msg]    | Audio communication via cc-speak TTS      |
| /ct:bonkai [plan]  | Architect role with subagent delegation   |
| /ct:socrates       | Self-introspection on knowledge sources   |

## Plugins

Configured in `templates/claude-settings.json.tera`. Shared: claude-md-management, harness, coding (devflow disabled). Personal/dev: claude-code-knowledge, dev, writing. Work: admin, backend, pb-prose, pb-news, pb-claude-harness-engineering. Optional: cc-notify.

## Supporting Tools

| Tool                    | Source           | Purpose                                  |
| ----------------------- | ---------------- | ---------------------------------------- |
| cc-statusline           | oven/bin/        | Status line formatter                    |
| cc-speak                | oven/bin/        | TTS with file/section reading            |
| cindex                  | oven/bin/        | Project file index generator             |
| cc-logs--extract-agents | home/.local/bin/ | Extract agent IDs for session resumption |

## Hook Development

1. Follow naming: `cc-hook--<purpose>`
2. TypeScript hooks → `oven/bin/`, bash hooks → `home/.local/bin/`
3. Use shared types from `oven/shared/claude-hooks.ts`
4. stdin for input (JSON), stdout for responses (JSON), exit code 2 to block

## Agent Resumption

Claude Code supports resuming Task agents from previous executions. **Caveat**: only the initial context is recalled on resume, not follow-up tasks.
