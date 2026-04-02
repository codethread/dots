# Agentic Configuration Specification

**Status:** Implemented
**Last Updated:** 2026-04-02

## 1. Overview

### Purpose

Declarative configuration system for Claude Code and OpenAI Codex agent platforms. Manages settings generation, hook compilation, asset symlinks, plugin wiring, and shell wrappers — so that a single `make system && make link && make build` produces a fully-configured agentic environment from source.

### Goals

- Single source of truth for global settings in Nix (`nix/features/claude-code.nix`)
- All agent assets (agents, skills, commands, rules) version-controlled and symlinked into place via dotty
- Type-safe hook contracts shared across TypeScript and Bash implementations
- Context-aware shell wrappers that inject environment-specific prompts
- Plugin extensibility via local and remote marketplaces
- Codex configuration colocated and linked alongside Claude Code

### Non-Goals

- Container orchestration and sandboxing — covered by [cc-sandbox spec](./cc-sandbox.md)
- Plugin implementation details — plugins live in `~/dev/projects/claude-code-plugins` (separate repo)
- cc-notify daemon internals — external project at `~/dev/projects/cc-notify`
- Dotty implementation — dotty is a general-purpose symlink manager, not agentic-specific

## 2. Architecture

Three configuration layers compose at runtime:

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: Nix-generated globals                      │
│   nix/features/claude-code.nix                      │
│     → ~/.claude/settings.json (read-only, Nix store)│
│   Owns: permissions, hooks, env vars, plugins,      │
│         marketplaces, feature flags                  │
├─────────────────────────────────────────────────────┤
│ Layer 2: Dotty-symlinked assets                     │
│   claude/ → ~/.claude/                              │
│     agents/, commands/, skills/, rules/,            │
│     CLAUDE.md, keybindings.json                     │
│   config/codex/ → ~/.config/codex/                  │
│     config.toml, AGENTS.md                          │
├─────────────────────────────────────────────────────┤
│ Layer 3: Project-local overrides                    │
│   .claude/settings.json    (repo-specific hooks)    │
│   .claude/settings.local.json (machine-local)       │
│   .claude/agents/          (repo-specific agents)   │
│   .claude/skills/          (repo-specific skills)   │
└─────────────────────────────────────────────────────┘
```

Settings merge order: Nix globals → project settings → local overrides.

### Build Pipeline

```
make system  →  nix rebuild  →  ~/.claude/settings.json regenerated
make link    →  dotty link   →  claude/ assets symlinked to ~/.claude/
make build   →  bun verify   →  oven/bin/*.ts compiled to ~/.local/bin/ wrappers
```

`make` (default) runs `link` then `build`. The project-local Stop hook (`make -C $HOME/PersonalConfigs link build`) re-runs link+build automatically after each Claude session.

## 3. Data Model

### Hook Type System (`oven/shared/claude-hooks.ts`)

All hooks share a base input contract:

```typescript
interface BaseHookInput {
  session_id: string;
  transcript_path: string;
  cwd: string;
  hook_event_name: string;
}
```

Nine event-specific input types extend this: `SessionStartInput`, `SessionEndInput`, `PreToolUseInput`, `PostToolUseInput`, `UserPromptSubmitInput`, `StopInput`, `PreCompactInput`, `NotificationInput`, `StatuslineInput`.

Hook outputs control flow:

```typescript
interface BaseHookOutput {
  continue?: boolean;       // default true; false stops execution
  stopReason?: string;
  suppressOutput?: boolean; // hide from transcript
  systemMessage?: string;   // warning to user
}
```

Specialized outputs: `PreToolUseOutput` adds `permissionDecision` (allow|deny|ask), `PostToolUseOutput` and `UserPromptSubmitOutput` add `additionalContext`, `StopOutput` adds `decision: "block"`, `SessionStartOutput` adds `additionalContext` (context injection).

I/O protocol: JSON on stdin (HookInput), JSON on stdout (HookOutput), exit code 2 to block.

### Dotty Config (`config/dotty/dotty.toml`)

The `claude` project definition:
- Origin: `~/PersonalConfigs/claude/`
- Target: `~/.claude/`
- Excludes: `**/settings.json`, `**/settings.local.json`
- 21 files tracked, cached at `~/.local/data/dotty-cache-claude.nuon`

The `config` project covers `config/codex/` → `~/.config/codex/` as part of the broader `config/ → ~/.config/` mapping.

## 4. Interfaces

### Settings Generation (`nix/features/claude-code.nix`)

**Permissions:**
- Allow: `Bash`, `Edit(.claude)`, `WebFetch`, `WebSearch`, `Skill`, context7 MCP tools
- Deny: secret file reads (`*.key`, `*.pem`, `.env*`, `.netrc`, `id_rsa*`, `secrets/**`), dangerous git ops (`reset --hard`, `clean -f`, `branch -D`, `config`, `commit --amend`, `rebase -i`), `.git/hooks/**`, Plan/statusline-setup agents, `NotebookEdit`, `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode`
- Default mode: `acceptEdits`
- Additional directories: `~/PersonalConfigs`, `~/.local`, `~/.claude`, `~/dev`, `~/work`, `~/workfiles`

**Hooks (global):**

| Event | Handler | Type | Behavior |
|-------|---------|------|----------|
| SessionStart | `cc-hook--context-injector session-start` | TS | Scans README.md files, injects listing as contextOutput |
| PreToolUse[Bash] | `cc-hook--npm-redirect` | TS | Redirects npm/npx/node to detected package manager |
| PostToolUse[Write] | `git add -N` | inline | Intent-to-add for new files |
| SessionEnd | `cc-hook--context-injector session-end` | TS | Removes session state file |

**Plugin hooks (conditional, via cc-notify plugin when `enableNotify=true`):**

| Event | Handler | Type | Behavior |
|-------|---------|------|----------|
| Stop | `cc-hook--notify` | bash | Schedule 60s delayed push notification |
| PermissionRequest | `cc-hook--notify` | bash | Schedule notification with tool context |
| UserPromptSubmit | `cc-hook--activity` | bash | Cancel pending notification |
| SessionEnd | `cc-hook--activity` | bash | Cancel pending notification |

**Environment variables (14):** Disables telemetry, error reporting, feedback, auto-memory, cron, MCP servers, terminal title, 1M context, tool search. Enables PWD maintenance. Sets MANPAGER=cat, ZDOTDIR=~/.config/zsh-claude.

**Nix option:** `ct.claude-code.enableNotify` (boolean) gates cc-notify plugin and its hooks.

**Plugins & Marketplaces:**
- Official marketplace: `frontend-design`, `typescript-lsp`, `claude-md-management`
- `codethread-plugins` (local dir `~/dev/projects/claude-code-plugins`): `claude-code-knowledge`, `bdfl`, `dev`
- `cc-notify-marketplace` (GitHub `codethread/cc-notify`, conditional): `cc-notify`

### Agents

**Global (`claude/agents/` → `~/.claude/agents/`):**

| Agent | Model | Tools/Skills | Purpose |
|-------|-------|-------------|---------|
| api-researcher | haiku | Glob, Grep, Read, Skill, WebFetch, WebSearch, context7 MCP | Version-aware API documentation research |
| browser-user | sonnet | playwright-cli skill | Browser interaction with auth state loading |

**Disabled (`claude/x-agents/`):** `browser-devtools` (sonnet, chrome-devtools MCP) — DevTools diagnostics. Prefix convention keeps files out of Claude's agent discovery.

**Project-local (`PersonalConfigs/.claude/agents/`):** `nix-packager` (sonnet) — Nix packaging workflow.

### Skills

**Global (`claude/skills/` → `~/.claude/skills/`):**

| Skill | Tools | Purpose |
|-------|-------|---------|
| commit | Bash(git:*) | Conventional commits with auto status/diff injection |
| playwright-cli | Bash(playwright-cli:*) | Full browser automation (279 lines + 7 reference docs) |

**Project-local (`PersonalConfigs/.claude/skills/`):** `kitty-terminal` — kitty control via kitten @ commands.

### Commands (`claude/commands/` → `~/.claude/commands/`)

| Command | Key Feature |
|---------|------------|
| github | Issue/PR reading via `gh --json`, PR creation with HEREDOC |
| ct/bonkai | Architect role with subagent delegation (disable-model-invocation) |
| ct/socrates | Self-introspection on knowledge sources |
| ct/speak | Audio communication via cc-speak TTS |

### Rules (`claude/rules/` → `~/.claude/rules/`)

| Rule | Enforces |
|------|----------|
| git | Commit only when asked, atomic, HEREDOC format, never --no-verify |
| review | Mandatory `code-review` CLI before reporting done |
| fixes/comments | Comments explain ambiguity, not changes |

### Claude Wrapper (`home/.local/bin/cl`)

Bash wrapper prepending context-aware system prompts to `claude` CLI:
- Repository type detection: `/work/*` → GitLab hints; else → GitHub hints
- Container awareness: `CC_SANDBOX=1` → "stop immediately if tool missing"
- Always injected: sub-agent concurrency rules, conciseness directive, tool schema warning
- Effort defaults: opus→high, others→medium
- Flags: `-d` (skip permissions), `--dry-run`, `-m/--model`, `--effort`
- Respects `CC_HOST_PWD` for container path translation

### Codex Configuration (`config/codex/`)

- `config.toml`: model gpt-5.4, personality pragmatic, effort high. Profiles: fast-review (gpt-5.3-codex, medium), deep-review (gpt-5.4, high). 15+ trusted project paths. Falls back to CLAUDE.md for project docs.
- `AGENTS.md`: global instruction for conciseness

### Nushell Wrappers (`config/nushell/scripts/ct/interactive/claude.nu`)

- `clo`/`cls`/`clh` — model-specific Claude wrappers (opus/sonnet/haiku)
- `cll` — ephemeral haiku session with auto-cleanup of session files
- `_claude-session`, `_claude-prompts`, `_claude-session-stats` — session log analysis

### Hook Implementations

**TypeScript (oven/bin/, compiled to ~/.local/bin/):**

| Hook | Lines | Key Behavior |
|------|-------|-------------|
| cc-hook--context-injector | 212 | Session start: glob README.md files, output contextOutput. Session end: rm /tmp state file. |
| cc-hook--npm-redirect | 320 | Walk dir tree for lock files (bun > pnpm > yarn > npm). Quote-aware. Skill/plugin context bypass. Exit 2 + suggestion on mismatch. |

**Bash (home/.local/bin/):**

| Hook | Lines | Key Behavior |
|------|-------|-------------|
| cc-hook--notify | 71 | POST to cc-notify daemon. Stop: "Done · $PROJECT" + 120-char snippet. PermissionRequest: tool-specific detail. |
| cc-hook--activity | 10 | POST session_id to /activity to cancel pending notification. Fail silent. |

### Supporting Tools

| Tool | Source | Purpose |
|------|--------|---------|
| cc-statusline | oven/bin/cc-statusline.ts | Process Claude Code status line data |
| cc-speak | oven/bin/cc-speak.ts | TTS with markdown stripping, file/section reading |
| cindex | oven/bin/cindex.ts | Project file index generator for context injection |
| cc-logs--extract-agents | home/.local/bin/ (bash) | Extract agent IDs with prompts/models for session resumption |

### Keybindings (`claude/keybindings.json`)

Disables Ctrl+A in Global context.

## 5. Design Decisions

- **Nix as settings source of truth.** `~/.claude/settings.json` is Nix-store-linked and read-only. Prevents drift from manual edits. Trade-off: requires `make system` (nix rebuild) to change global settings.

- **Dotty for asset linking, not Nix.** Agents, skills, commands, and rules are symlinked by dotty rather than Nix home-manager. This allows editing assets in PersonalConfigs and seeing changes immediately without a nix rebuild. Settings.json (which is JSON and auto-generated) stays in Nix.

- **x-agents/ prefix convention.** Disabled agents live in `claude/x-agents/` — the prefix keeps them out of Claude's discovery path while keeping them version-controlled for re-enablement.

- **Hook I/O via stdin/stdout JSON.** Hooks receive structured input on stdin and return structured output on stdout. Exit code 2 blocks the operation. This matches Claude Code's hook protocol and allows both TypeScript and Bash implementations.

- **Project-local Stop hook for self-rebuild.** The PersonalConfigs repo's `.claude/settings.json` runs `make link build` on Stop, ensuring any changes Claude made to oven/ or home/ are compiled and linked immediately.

- **Wrapper-injected system prompts.** The `cl` wrapper adds repo-type-specific, concurrency, and sandbox-awareness prompts at launch rather than embedding them in settings.json. This keeps prompts context-dependent without polluting global config.

- **Package manager detection by lock file.** `cc-hook--npm-redirect` walks the directory tree looking for lock files in priority order (bun > pnpm > yarn > npm). This is more reliable than checking tool presence and handles monorepos.

## 6. Testing

**TypeScript hooks:** Unit tests in `oven/tests/`:
- `cc-hook--context-injector.test.ts` — session start/end lifecycle
- `cc-hook--npm-redirect.test.ts` — PM detection, redirection, quote awareness, skill bypass

**End-to-end smoke test:** `cc-sandbox-smoke` (nushell function in `config/nushell/scripts/ct/interactive/claude.nu`) verifies inside a container: binary presence (claude, codex, playwright-cli, bun, nu), versions, PATH setup, settings mounted, codex config linked, project mount under /vm/. Optional `--with-models` flag pings Claude and Codex APIs headlessly.

**No direct tests for:** bash hooks (cc-hook--notify, cc-hook--activity), cl wrapper, nushell wrappers. These are verified indirectly through the smoke test and manual usage.

## 7. Open Questions

- The `x-agents/` convention works but is undocumented outside `claude/README.md` — should disabled agents use a more formal mechanism?
- Codex config shares the dotty `config` project with all other XDG configs. If Codex needs more files, a dedicated dotty project may be cleaner.
