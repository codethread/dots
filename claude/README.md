# Claude Code Global Settings

Dotty links this directory’s assets into `~/.claude`, except settings and skills, which mise manages separately. Destination directories remain real directories so Claude can keep its own state.

Custom directories (those not carrying Claude Code significance like `agents/` or `commands/`) are prefixed with `x-` for clarity and to avoid accidental name collision.

> **Architecture details**: See [SPEC-001 agentic-config](../devflow/specs/agentic-config.md) for the full configuration architecture (settings generation, hook contracts, type system, design decisions).

## Settings Source of Truth

The global `~/.claude/settings.json` is a **regular file rendered by mise** from `templates/claude-settings.json.tera`. Edit the template, then apply it; edits to the generated file are overwritten on the next apply. The resource lives in root `mise.toml`. The `.claude/settings.json` in this repo is project-local settings (for this repo only) and `.claude/settings.local.json` is the local override.

### Apply

From the dots checkout (mise 2026.10.4 or newer):

```nu
mise dot apply ~/.claude/settings.json
mise dot status
```

Workfiles' `make` installs `~/.config/claude/settings-overlay.json` and requests a targeted rerender of this shared output. The template deep-merges that optional JSON object; work-specific plugins, marketplaces and permissions live in workfiles rather than dots' profile. Without an installed overlay, the personal/dev defaults are used. Malformed overlays fail rather than silently dropping work settings. `/tmp/claude` is declared in root `mise.toml` and prepared by the native files phase, not `mise dot apply`. Bash is resolved from PATH when rendering.

Other Claude assets except shared skills remain managed by dotty; project-local settings and local overrides are untouched.

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

Author shared personal skills in `home/.agents/skills/`. Mise links that source into both `~/.agents/skills/` (as part of the `home/` mapping) and `~/.claude/skills/` using `symlink-each`. It links individual files, leaving Claude’s `synced/`, `.trash/`, and other destination-only files untouched.

| Skill      | Purpose                                            |
| ---------- | -------------------------------------------------- |
| attention  | Get the user’s attention after a long-running task |
| github     | Work with GitHub issues and pull requests          |
| repo-setup | Set up repository agent scaffolding                |
| socrates   | Inspect knowledge sources and assumptions          |

Existing linked-file edits are visible immediately. After adding or removing source files, run `make link`, or from the dots checkout:

```nu
mise dot apply ~ ~/.claude/skills
```

Files created only in a destination are not imported into the repository. Keep shared skill changes in the source. Plugin-provided skills remain owned by their plugins.

## Slash Commands

| Command            | Purpose                                   |
| ------------------ | ----------------------------------------- |
| /github \<number\> | Read GitHub issues/PRs with image support |
| /ct:speak [msg]    | Audio communication via cc-speak TTS      |
| /ct:bonkai [plan]  | Architect role with subagent delegation   |
| /ct:socrates       | Self-introspection on knowledge sources   |

## Plugins

Shared defaults are configured in `templates/claude-settings.json.tera`: claude-md-management, harness, coding (devflow disabled), plus claude-code-knowledge, dev and writing. Workfiles owns its plugin overrides and marketplaces through the installed JSON overlay. Optional: cc-notify.

## Supporting Tools

| Tool                    | Source                             | Purpose                                    |
| ----------------------- | ---------------------------------- | ------------------------------------------ |
| cc-statusline           | oven/bin/                          | Status line formatter                      |
| cc-speak                | oven/bin/                          | TTS with file/section reading              |
| cindex                  | oven/bin/                          | Project file index generator               |
| cc-logs--extract-agents | home/.local/bin/                   | Extract agent IDs for session resumption   |
| honeycomb               | ~/dev/projects/hive/lib/honeycomb/ | Git worktree lifecycle; see `honeycomb -h` |

## Hook Development

1. Follow naming: `cc-hook--<purpose>`
2. TypeScript hooks → `oven/bin/`, bash hooks → `home/.local/bin/`
3. Use shared types from `oven/shared/claude-hooks.ts`
4. stdin for input (JSON), stdout for responses (JSON), exit code 2 to block

## Agent Resumption

Claude Code supports resuming Task agents from previous executions. **Caveat**: only the initial context is recalled on resume, not follow-up tasks.
