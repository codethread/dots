# Agentic Configuration Specification

**Status:** Implemented
**Last Updated:** 2026-04-09

## 1. Overview

### Purpose

Declarative configuration system for Claude Code, OpenAI Codex, Pi, and related agent CLIs. Manages package provisioning, settings generation, hook compilation, asset symlinks, plugin wiring, and shell wrappers — so that a single `make system && make link && make build` produces a fully-configured agentic environment from source.

### Goals

- Single source of truth for global settings in Nix (`nix/features/claude-code.nix`)
- Agent CLI binaries provisioned declaratively via `llm-agents.nix`
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
- Project-local `.claude/` config authoring beyond the shared Pi compatibility shim

## 2. Architecture

Four configuration layers compose at runtime:

```
┌─────────────────────────────────────────────────────┐
│ Package layer: Nix flake inputs + overlays          │
│   nix/flake.nix, nix/features/common.nix            │
│   Owns: claude-code, codex, pi binaries   │
├─────────────────────────────────────────────────────┤
│                                                     │
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
│   pi/ → ~/.pi/agent/                                │
│     agent.njk, README.md, settings.json             │
│     (appended system prompt + shared defaults)       │
│   config/codex/ → ~/.config/codex/                  │
│     config.toml, AGENTS.md                          │
├─────────────────────────────────────────────────────┤
│ Layer 3: Project-local overrides (per-repo)         │
│   .claude/settings.json    (repo-specific hooks)    │
│   .claude/settings.local.json (machine-local)       │
│   .claude/agents/, .claude/skills/, .claude/commands/ │
│   .pi/{agents,skills,prompts} may be generated as   │
│   symlinks back to .claude for Pi compatibility     │
└─────────────────────────────────────────────────────┘
```

Settings merge order: Nix globals → project settings → local overrides. Agent CLI packages are supplied separately by the flake package layer. This spec covers the package layer plus layers 1 and 2 only.

### Build Pipeline

```
make system  →  nix rebuild  →  ~/.claude/settings.json regenerated
make link    →  dotty link   →  claude/ assets symlinked to ~/.claude/
make build   →  bun verify   →  oven/bin/*.ts compiled to ~/.local/bin/ wrappers
```

`make` (default target `all`) runs `link`, `build`, then `system` (nix rebuild).

### Package Provisioning

- `nix/flake.nix` imports `github:numtide/llm-agents.nix`
- Its overlay is applied to both the system package set and `pkgsMaster`
- `nix/features/common.nix` installs `llm-agents` packages for `claude-code`, `codex`, and `pi`
- `config/dotty/dotty.toml` links the tracked `pi/` directory into `~/.pi/agent`
- Most mutable Pi config now lives in `https://github.com/codethread/agents`; this repo keeps the `pi/agent.njk` template plus minimal bootstrap files and symlinks that make Pi consume the shared prompt/config layout

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
	continue?: boolean; // default true; false stops execution
	stopReason?: string;
	suppressOutput?: boolean; // hide from transcript
	systemMessage?: string; // warning to user
}
```

Specialized outputs nest event-specific fields inside `hookSpecificOutput`:

- `PreToolUseOutput`: `hookSpecificOutput.permissionDecision` (allow|deny|ask)
- `PostToolUseOutput`, `UserPromptSubmitOutput`, `SessionStartOutput`: `hookSpecificOutput.additionalContext`
- `StopOutput`: `decision: "block"` (top-level)

Legacy compat fields (`decision`, `reason`) also exist at the top level for older hook implementations.

I/O protocol: JSON on stdin (HookInput), JSON on stdout (HookOutput), exit code 2 to block. Some hooks (e.g., `cc-hook--context-injector`) output plain text to stdout instead of JSON — Claude Code accepts both.

### Dotty Config (`config/dotty/dotty.toml`)

The `claude` project definition:

- Origin: `~/dev/dots/claude/`
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
- Additional directories: `~/dev/dots`, `~/.local`, `~/.claude`, `~/dev`, `~/work`, `~/workfiles`

**Hooks (global):**

| Event              | Handler                                   | Type   | Behavior                                                       |
| ------------------ | ----------------------------------------- | ------ | -------------------------------------------------------------- |
| SessionStart       | `cc-hook--context-injector session-start` | TS     | Scans README.md files, outputs listing as plain text to stdout |
| PreToolUse[Bash]   | `cc-hook--npm-redirect`                   | TS     | Redirects npm/npx/node to detected package manager             |
| PostToolUse[Write] | `git add -N`                              | inline | Intent-to-add for new files                                    |
| SessionEnd         | `cc-hook--context-injector session-end`   | TS     | Removes session state file                                     |

**Plugin hooks (wired by the cc-notify plugin itself, not the Nix module; available when `enableNotify=true`):**

Note: `PermissionRequest` is a Claude Code hook event not represented in the TypeScript type system (`oven/shared/claude-hooks.ts`). It is handled only by the bash hook `cc-hook--notify`.

| Event             | Handler             | Type | Behavior                                |
| ----------------- | ------------------- | ---- | --------------------------------------- |
| Stop              | `cc-hook--notify`   | bash | Schedule 60s delayed push notification  |
| PermissionRequest | `cc-hook--notify`   | bash | Schedule notification with tool context |
| UserPromptSubmit  | `cc-hook--activity` | bash | Cancel pending notification             |
| SessionEnd        | `cc-hook--activity` | bash | Cancel pending notification             |

**Environment variables (13):** Disables telemetry, error reporting, feedback, auto-memory, cron, MCP servers, terminal title, 1M context, tool search. Keeps auto-updater enabled (`DISABLE_AUTOUPDATER=0`). Enables PWD maintenance. Sets MANPAGER=cat, ZDOTDIR=~/.config/zsh-claude.

**Nix option:** `ct.claude-code.enableNotify` (boolean) gates cc-notify plugin and its hooks.

**Plugins & Marketplaces:**

- Official marketplace: `frontend-design`, `typescript-lsp`, `claude-md-management`
- `codethread-plugins` (local dir `~/dev/projects/claude-code-plugins`): `claude-code-knowledge`, `bdfl`, `dev`
- `cc-notify-marketplace` (GitHub `codethread/cc-notify`, conditional): `cc-notify`

### Agents

**Global (`claude/agents/` → `~/.claude/agents/`):**

| Agent          | Model  | Tools/Skills                                               | Purpose                                     |
| -------------- | ------ | ---------------------------------------------------------- | ------------------------------------------- |
| api-researcher | haiku  | Glob, Grep, Read, Skill, WebFetch, WebSearch, context7 MCP | Version-aware API documentation research    |
| browser-user   | sonnet | playwright-cli skill                                       | Browser interaction with auth state loading |

**Disabled (`claude/x-agents/`):** `browser-devtools` (sonnet, chrome-devtools MCP) — DevTools diagnostics. Prefix convention keeps files out of Claude's agent discovery.

### Skills

**Global (`claude/skills/` → `~/.claude/skills/`):**

| Skill          | Tools                   | Purpose                                                |
| -------------- | ----------------------- | ------------------------------------------------------ |
| commit         | Bash(git:\*)            | Conventional commits with auto status/diff injection   |
| playwright-cli | Bash(playwright-cli:\*) | Full browser automation (279 lines + 7 reference docs) |

### Commands (`claude/commands/` → `~/.claude/commands/`)

| Command     | Key Feature                                                        |
| ----------- | ------------------------------------------------------------------ |
| github      | Issue/PR reading via `gh --json`, PR creation with HEREDOC         |
| ct/bonkai   | Architect role with subagent delegation (disable-model-invocation) |
| ct/socrates | Self-introspection on knowledge sources                            |
| ct/speak    | Audio communication via cc-speak TTS                               |

### Rules (`claude/rules/` → `~/.claude/rules/`)

| Rule           | Enforces                                                          |
| -------------- | ----------------------------------------------------------------- |
| git            | Commit only when asked, atomic, HEREDOC format, never --no-verify |
| review         | Mandatory `code-review` CLI before reporting done                 |
| fixes/comments | Comments explain ambiguity, not changes                           |

### Claude Wrapper (`home/.local/bin/cl`)

Bash wrapper prepending context-aware system prompts to `claude` CLI:

- Repository type detection: `/work/*` → GitLab hints; else → GitHub hints
- Container awareness: `CC_SANDBOX=1` → "stop immediately if tool missing"
- Always injected: sub-agent concurrency rules, conciseness directive, tool schema warning
- Effort defaults: opus→high, others→medium
- Flags: `-d` (skip permissions), `--dry-run`, `-m/--model`, `--effort`
- Respects `CC_HOST_PWD` for container path translation

### Pi Configuration (`pi/`)

Direct `pi` invocation with shared repo-aware configuration:

- `agent.njk`: template used to inject the appended system prompt and repo-specific runtime instructions into Pi sessions
- `README.md`: local docs for the repo-owned Pi bootstrap layout
- `settings.json`: minimal global Pi defaults and enabled model list used by the subagent compatibility shim
- Most reusable Pi agents/skills now live in `https://github.com/codethread/agents`; this repo keeps the template and any local compatibility glue needed to consume that shared source
- `extensions/claude-sync.ts`: project-local Pi extension that treats `.claude/` as source-of-truth and creates `.pi/skills -> .claude/skills`, `.pi/agents -> .claude/agents`, and flattened `.pi/prompts/*.md -> .claude/commands/**/*.md` symlinks on startup
- `extensions/subagent/agents.ts`: project-local agent loader for the `subagent` extension; follows symlinked `.pi/agents`, normalizes Claude tool names to Pi tools, strips unsupported tools, and resolves Claude model aliases like `sonnet`/`haiku` to concrete enabled OpenAI models from `pi/settings.json`
- `extensions/subagent/index.ts`: adds `/debug-agents` to show discovered agents with resolved model and normalized tools
- Machine-local state stays outside the repo: `auth.json`, `models.json`, `sessions/`

### Codex Configuration (`config/codex/`)

- `config.toml`: model gpt-5.4, personality pragmatic, effort high. Profiles: fast-review (gpt-5.3-codex, medium), deep-review (gpt-5.4, high). 15 trusted project paths. Falls back to CLAUDE.md for project docs.
- `AGENTS.md`: global instruction for conciseness

### Agent CLI Packages (`nix/flake.nix`, `nix/features/common.nix`)

- Source: `llm-agents.nix` overlay
- Installed CLIs: `claude-code`, `codex`, `pi`
- `pkgsMaster` remains the preferred source for fast-moving supporting packages like Node.js and TypeScript

### Nushell Wrappers (`config/nushell/scripts/ct/interactive/claude.nu`)

- `clo`/`cls`/`clh` — model-specific Claude wrappers (opus/sonnet/haiku)
- `cll` — ephemeral haiku session with auto-cleanup of session files
- `_claude-session`, `_claude-prompts`, `_claude-session-stats` — session log analysis

### Hook Implementations

**TypeScript (oven/bin/, compiled to ~/.local/bin/):**

| Hook                      | Key Behavior                                                                                                                       |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| cc-hook--context-injector | Session start: glob README.md files, output listing as plain text to stdout. Session end: rm /tmp state file.                      |
| cc-hook--npm-redirect     | Walk dir tree for lock files (bun > pnpm > yarn > npm). Quote-aware. Skill/plugin context bypass. Exit 2 + suggestion on mismatch. |

**Bash (home/.local/bin/):**

| Hook              | Key Behavior                                                                                                   |
| ----------------- | -------------------------------------------------------------------------------------------------------------- |
| cc-hook--notify   | POST to cc-notify daemon. Stop: "Done · $PROJECT" + 120-char snippet. PermissionRequest: tool-specific detail. |
| cc-hook--activity | POST session_id to /activity to cancel pending notification. Fail silent.                                      |

### Supporting Tools

| Tool                    | Source                    | Purpose                                                      |
| ----------------------- | ------------------------- | ------------------------------------------------------------ |
| cc-statusline           | oven/bin/cc-statusline.ts | Process Claude Code status line data                         |
| cc-speak                | oven/bin/cc-speak.ts      | TTS with markdown stripping, file/section reading            |
| cindex                  | oven/bin/cindex.ts        | Project file index generator for context injection           |
| cc-logs--extract-agents | home/.local/bin/ (bash)   | Extract agent IDs with prompts/models for session resumption |

### Keybindings (`claude/keybindings.json`)

Disables Ctrl+A in Global context.

## 5. Design Decisions

- **Nix as settings source of truth.** `~/.claude/settings.json` is Nix-store-linked and read-only. Prevents drift from manual edits. Trade-off: requires `make system` (nix rebuild) to change global settings.

- **`llm-agents.nix` for agent CLI packaging.** Agent binaries come from a dedicated upstream flake rather than ad hoc package sources. This reduces custom packaging maintenance and makes adding new CLIs like `pi` trivial.

- **Dotty for asset linking, not Nix.** Agents, skills, commands, and rules are symlinked by dotty rather than Nix home-manager. This allows editing assets in dots and seeing changes immediately without a nix rebuild. Settings.json (which is JSON and auto-generated) stays in Nix.

- **x-agents/ prefix convention.** Disabled agents live in `claude/x-agents/` — the prefix keeps them out of Claude's discovery path while keeping them version-controlled for re-enablement.

- **Hook I/O via stdin/stdout JSON.** Hooks receive structured input on stdin and return structured output on stdout. Exit code 2 blocks the operation. This matches Claude Code's hook protocol and allows both TypeScript and Bash implementations.

- **Shared agent assets live in `codethread/agents`.** Pi-related reusable agents/skills are primarily authored and maintained there now; this repo keeps only the `pi/agent.njk` template and compatibility shims needed to append the right system prompt and consume the shared assets.

- **Wrapper-injected system prompts.** Shell wrappers add context-dependent prompts at launch rather than embedding them in settings.json. `cl` injects richer Claude-specific guidance (repo type, concurrency, concision, tool realism, sandbox awareness). `pi` now uses `pi/agent.njk` as the template for appended system prompt management, while the heavier reusable config lives in `codethread/agents`. This keeps prompts context-dependent without polluting global config.

- **Package manager detection by lock file.** `cc-hook--npm-redirect` walks the directory tree looking for lock files in priority order (bun > pnpm > yarn > npm). This is more reliable than checking tool presence and handles monorepos.

## 6. Testing

**TypeScript hooks:** Unit tests in `oven/tests/`:

- `cc-hook--context-injector.test.ts` — session start/end lifecycle
- `cc-hook--npm-redirect.test.ts` — PM detection, redirection, quote awareness, skill bypass

**End-to-end smoke test:** `cc-sandbox-smoke` (nushell function in `config/nushell/scripts/ct/interactive/claude.nu`) verifies inside a container: binary presence (claude, codex, pi, playwright-cli, bun, nu), versions, PATH setup, settings mounted, codex config linked, pi template/config wired, project mount under /vm/. Optional `--with-models` flag pings Claude and Codex APIs headlessly.

**No direct tests for:** bash hooks (cc-hook--notify, cc-hook--activity), `cl` wrapper, direct `pi` usage, nushell wrappers. These are verified indirectly through the smoke test and manual usage.

## 7. Open Questions

- The `x-agents/` convention works but is undocumented outside `claude/README.md` — should disabled agents use a more formal mechanism?
- Codex config shares the dotty `config` project with all other XDG configs. If Codex needs more files, a dedicated dotty project may be cleaner.
