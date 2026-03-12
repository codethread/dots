# Claude Code Global Settings

This directory is symlinked to `~/.claude` and shares global Claude Code settings between machines.

Custom directories (those not carrying Claude Code significance like `agents/` or `commands/`) are prefixed with `x-` for clarity and to avoid accidental name collision.

## Sandbox Strategy (cc-sandbox)

The goal is to run all Claude Code work inside a sandboxed Podman container (`cc-sandbox`) for isolation and reproducibility. The container provides a full development environment with Claude Code, browser automation, and all hooks/tools pre-built.

- **Script**: `home/.local/bin/cc-sandbox`
- **Containerfile**: `home/.local/share/cc-sandbox/Containerfile`
- **Base image**: `node:22-slim` with Chromium, Bun, Nushell, Claude Code CLI, playwright-cli
- **Runs as**: non-root user with UID remapping (`--userns=keep-id`)

### What gets mounted

- Current directory as `/vm/<dirname>` (basename of cwd, e.g. `myapp` → `/vm/myapp`)
- Claude credentials (`~/.claude/.credentials.json`, `~/.claude.json`)
- Claude settings (copied, not bind-mounted)
- Git config (read-only)
- SSH agent (Linux: direct socket mount; macOS: reverse SSH tunnel into Podman VM)
- cc-notify env vars (`CC_NOTIFY_HOST`, `CC_NOTIFY_PORT`) for container hooks to reach host notification daemon
- Playwright auth states (via `-a`/`--auth` flag, read-only)

### What gets built inside the container

The Containerfile COPYs the PersonalConfigs repo and runs `dotty link` + `bun run build` inside, so all hooks and tools are compiled natively against container glibc.

### Usage

```bash
cc-sandbox                    # Run claude --dangerously-skip-permissions
cc-sandbox -i                 # Interactive bash shell
cc-sandbox -r 'claude -p "describe this project" --output-format text'
cc-sandbox -n                 # Rebuild image without cache
cc-sandbox -a ocado            # Mount playwright auth state (readonly)
cc-sandbox -p 3000:3000       # Forward ports
```

## cc-notify (Push Notifications)

iOS push notifications via Pushover, triggered by Claude Code hooks or the `/notify` skill.

- **Source**: `~/dev/projects/cc-notify` (Effect + Bun HTTP server)
- **Runs on host**: binds to a port in range 7777–7800, writes port to `${XDG_RUNTIME_DIR:-/tmp}/cc-notify.port`
- **API**: `POST /notify` (title, message, session_id), `POST /activity` (cancel pending), `GET /toggle`, `GET /health`

### How it connects

```
Host                                    Container (cc-sandbox)
─────────────────────                   ──────────────────────
cc-notify server (:7777)           ◄──  CC_NOTIFY_HOST=host.containers.internal
  ▲                                     CC_NOTIFY_PORT=7777 (read at sandbox start)
  │                                       ▲
  │                                       │
cc-hook--notify (Stop)                  cc-hook--notify (Stop)
cc-hook--activity (UserPromptSubmit)    cc-hook--activity (UserPromptSubmit)
                                        /notify skill (ad-hoc, notes repo only)
```

- **Host hooks** read port from `$CC_NOTIFY_PORT` or fall back to the port file, connect via `localhost`
- **Container hooks** use `$CC_NOTIFY_PORT` + `$CC_NOTIFY_HOST` (set by cc-sandbox at launch), connect via `host.containers.internal`
- **Delay**: notifications are scheduled with a 60s delay; cancelled by `cc-hook--activity` if the user responds before then

## Hooks Architecture

Hooks are orchestrated through `settings.json` and implemented as either:

- **TypeScript/Bun scripts** in `oven/bin/cc-hook--*.ts` (compiled to `~/.local/bin/`)
- **Bash scripts** in `home/.local/bin/cc-hook--*` (symlinked to `~/.local/bin/`)

### Hook Event Flow

```
SessionStart ──► cc-hook--context-injector session-start (list README.md files)
UserPromptSubmit ──► cc-hook--activity (cancel pending notification)
PreToolUse[Bash] ──► cc-hook--npm-redirect (redirect npm/npx/node)
PostToolUse[Write] ──► git add -N (intent-to-add for new files)
Stop ──► cc-hook--notify (schedule delayed notification)
PermissionRequest ──► cc-hook--notify (schedule delayed notification)
SessionEnd ──► cc-hook--context-injector session-end (cleanup)
SessionEnd ──► cc-hook--activity (cancel pending notification)
```

### Active Hooks

#### cc-hook--context-injector (TypeScript)

- **Events**: SessionStart, SessionEnd
- **Purpose**: Lists all README.md files in the project at session start; cleans up session state on end

#### cc-hook--npm-redirect (TypeScript)

- **Events**: PreToolUse[Bash]
- **Purpose**: Intercepts npm/npx/node commands and redirects to detected package manager (pnpm/bun/yarn) based on lock files

#### cc-hook--notify (Bash)

- **Events**: Stop, PermissionRequest
- **Purpose**: Sends delayed push notification via cc-notify daemon when Claude finishes or needs permission. Includes project name, event context, and a snippet of the assistant's last message

#### cc-hook--activity (Bash)

- **Events**: UserPromptSubmit, SessionEnd
- **Purpose**: Cancels pending cc-notify notifications (user is active, no alert needed)

#### git add -N (inline)

- **Events**: PostToolUse[Write]
- **Purpose**: Runs `git add -N` on newly created files so they appear in `git diff` without staging

#### cc-hook--chrome-stop (Bash, SubagentStop)

- **Events**: SubagentStop[browser-devtools]
- **Purpose**: Kills Chrome on debugging port 9222 when browser-devtools agent exits. Handles both sentinel-tracked and MCP-spawned Chrome instances

### Hook Configuration

Hooks are configured in `settings.json`:

```json
{
  "hooks": {
    "<EventName>": [
      {
        "matcher": "<ToolName>",
        "hooks": [{ "type": "command", "command": "<command>" }]
      }
    ]
  }
}
```

### Hook Development Guidelines

1. Follow naming convention: `cc-hook--<purpose>`
2. TypeScript hooks go in `oven/bin/`, bash hooks in `home/.local/bin/`
3. Use shared types from `oven/shared/claude-hooks.ts` for TypeScript hooks
4. Handle stdin for hook input and stdout for responses
5. Use exit code 2 to block operations with a reason

## Custom Agents

### Global agents

Defined in `claude/agents/`. Available in all projects.

#### api-research

- **Model**: haiku
- **Tools**: Glob, Grep, Read, Skill, context7 MCP
- **Purpose**: Research API documentation for project dependencies or new technologies

#### browser-user

- **Model**: sonnet
- **Tools**: playwright-cli MCP
- **Purpose**: Browser navigation, reading page content, interacting with web apps

#### browser-devtools

- **Model**: sonnet
- **Tools**: chrome-devtools MCP (auto-launches headless Chrome)
- **Cleanup**: SubagentStop hook runs cc-hook--chrome-stop
- **Purpose**: Browser automation and UI testing via Chrome DevTools Protocol

## Custom Slash Commands

### Naming Convention

- `ct:*`: Namespaced personal commands
- `prime-*`: Set up context for a specific task
- `refine-*`: Repetitive improvement tasks (e.g., updating docs)

### Available Commands

#### /ct:speak [optional initial message]

- **Location**: `claude/commands/ct/speak.md`
- **Purpose**: Enable audio communication mode using `cc-speak` TTS tool

#### /ct:yt-transcript \<youtube-url-or-search-query\>

- **Location**: `claude/commands/ct/yt-transcript.md`
- **Purpose**: Download YouTube transcript, clean it, save to `~/dev/projects/notes/resources/yt/`

#### /ct:commit

- **Location**: `claude/commands/ct/commit.md`
- **Purpose**: Create conventional commits

#### /ct:list-skills

- **Location**: `claude/commands/ct/list-skills.md`
- **Model**: haiku
- **Purpose**: List available skills

#### /ct:bonkai

- **Location**: `claude/commands/ct/bonkai.md`
- **Purpose**: Plan execution as architect

## Plugins

Configured in `settings.json` under `enabledPlugins`:

| Plugin | Status | Purpose |
|--------|--------|---------|
| `code-review@ai-tools-marketplace` | enabled | Final review step for completed work |
| `frontend-design@claude-plugins-official` | enabled | Production-grade frontend interface generation |
| `typescript-lsp@claude-plugins-official` | enabled | TypeScript language server integration |
| `claude-md-management@claude-plugins-official` | enabled | CLAUDE.md audit and improvement |
| `logger@codethread-plugins` | disabled | Event logging (not currently in use) |

## Supporting Tools

Built in `oven/bin/` and compiled to `~/.local/bin/`:

| Tool | Purpose |
|------|---------|
| `cc-statusline` | Custom status line formatter for Claude Code |
| `cc-speak` | TTS with markdown stripping, file/section reading |
| `cindex` | Generate project file indices for context injection |

Log analysis in `home/.local/bin/`:

| Tool | Purpose |
|------|---------|
| `cc-logs--extract-agents` | Extract agent IDs with prompts and models for resumption |

## Agent Resumption

Claude Code supports resuming Task agents from previous executions. Useful for continuing analysis or adding follow-up work without re-executing expensive operations.

**Caveat**: Claude Code only resumes the initial context for an agent — if you ask agent task A, then resume and ask task B, a later resume only recalls task A, not B.
