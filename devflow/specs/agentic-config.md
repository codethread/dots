# Agentic Configuration Specification

- Document ID: SPEC-001
- Configuration identification: SPEC-001; migrated from `specs/agentic-config.md`; canonical path `devflow/specs/agentic-config.md`.
- **Status:** Implemented
- **Last Updated:** 2026-10-01

## [SPEC-001-S1] 1. Overview

### [SPEC-001-S1.1] Purpose

Declarative configuration system for Claude Code, OpenAI Codex, Pi, and related agent CLIs. Manages package provisioning, settings generation, hook compilation, asset symlinks, plugin wiring, and shell wrappers — with mise `packages:apply`, `make link`, and `make build` provisioning packages/assets/tools, and `mise -E dev run claude:apply` (or `work`) applying global Claude settings.

### [SPEC-001-S1.2] Goals

- Single source of truth for global Claude settings in `templates/claude-settings.json.tera`, rendered by mise
- Mise provisions native Codex/Claude/Cursor CLIs, Node-based Pi, and Playwright CLI; Pi owns its npm extensions
- All agent assets (agents, skills, commands, rules) version-controlled and symlinked into place via dotty
- Type-safe hook contracts shared across TypeScript and Bash implementations
- Context-aware shell wrappers that inject environment-specific prompts
- Plugin extensibility via local and remote marketplaces
- Codex configuration colocated and linked alongside Claude Code

### [SPEC-001-S1.3] Non-Goals

- Plugin implementation details — plugins live in `~/dev/projects/claude-code-plugins` (separate repo)
- cc-notify daemon internals — external project at `~/dev/projects/cc-notify`
- Dotty implementation — dotty is a general-purpose symlink manager, not agentic-specific
- Project-local `.claude/` config authoring beyond the shared Pi compatibility shim

## [SPEC-001-S2] 2. Architecture

Four configuration layers compose at runtime:

```
┌─────────────────────────────────────────────────────┐
│ Package layer                                        │
│   macOS: Homebrew Codex/Node + ~/.local npm globals │
│   Owns: agent CLI binaries                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Layer 1: Mise-rendered globals                      │
│   templates/claude-settings.json.tera               │
│     → ~/.claude/settings.json (regular file)        │
│   Owns: permissions, hooks, env vars, plugins,      │
│         marketplaces, feature flags                  │
├─────────────────────────────────────────────────────┤
│ Layer 2: Dotty-symlinked assets                     │
│   claude/ → ~/.claude/                              │
│     agents/, commands/, skills/,                    │
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

Settings merge order: mise globals → project settings → local overrides. Agent CLI packages are supplied separately by mise global tools and host package declarations. This spec covers the package layer plus layers 1 and 2 only.

### [SPEC-001-S2.1] Build Pipeline

```
mise -E dev run packages:apply → agent CLI packages provisioned
mise -E dev run claude:apply → ~/.claude/settings.json rendered + /tmp/claude prepared
make link    →  dotty link   →  claude/ assets symlinked to ~/.claude/
make build   →  bun verify   →  oven/bin/*.ts compiled to ~/.local/bin/ wrappers
```

`make` (default target `all`) runs `link`, `build`, then `system` (nix rebuild).

### [SPEC-001-S2.2] Package Provisioning

- Mise declares Homebrew Node/Codex and the user-prefix Playwright CLI in `.mise/conf.d/packages.toml`.
- Global mise tools provide Claude, Cursor (`cursor-agent` and `agent`), and `npm:@earendil-works/pi-coding-agent` with Node. They are available outside this checkout through `config/mise/` and shims.
- Pi installs missing `npm:pi-nvim` and `npm:@narumitw/pi-goal` extensions from `pi/agent/settings.json`; use `pi update --extensions` to update them. The shared shell environment no longer forces offline mode.

`packages:apply` installs missing host packages without pruning or upgrading existing formulae. Use explicit mise package upgrades or `mise upgrade` for versioned tools. Pi's version is pinned in global tool config. `~/.local/bin` stays ahead of shims to preserve the custom Pi wrapper and existing native agent overrides. `nix-smoke` still checks that the binaries are present.

- `config/dotty/dotty.toml` links the tracked `pi/` directory into `~/.pi/agent`
- Most mutable Pi config now lives in `https://github.com/codethread/agents`; this repo keeps the `pi/agent.njk` template plus minimal bootstrap files and symlinks that make Pi consume the shared prompt/config layout

## [SPEC-001-S3] 3. Data Model

### [SPEC-001-S3.1] Hook Type System (`oven/shared/claude-hooks.ts`)

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

### [SPEC-001-S3.2] Dotty Config (`config/dotty/dotty.toml`)

The `claude` project definition:

- Origin: `~/dev/dots/claude/`
- Target: `~/.claude/`
- Excludes: `**/settings.json`, `**/settings.local.json`
- 21 files tracked, cached at `~/.local/data/dotty-cache-claude.nuon`

The `config` project covers `config/codex/` → `~/.config/codex/` as part of the broader `config/ → ~/.config/` mapping.

## [SPEC-001-S4] 4. Interfaces

### [SPEC-001-S4.1] Settings Generation (`templates/claude-settings.json.tera`)

Mise owns `~/.claude/settings.json` as a rendered regular file via `.mise/conf.d/claude-code.toml`; dotty excludes it. Apply with `mise -E dev run claude:apply` or `-E work`. That task prepares `/tmp/claude` with mode `1777`. See [Claude README](../../claude/README.md) for the apply workflow.

**Permissions:** The template preserves the previous allow/deny lists, `acceptEdits` default mode, and additional directories (`$DOTFILES`, `~/.local`, `~/.claude`, `~/dev`, `~/pb`). Secret-file reads, plan/worktree/cron tools, and other unwanted tools remain denied.

**Global hook:** `PostToolUse[Write]` runs inline `git add -N` for new files. Status line uses `cc-statusline`.

**Environment:** Keeps the previous environment variables, including `TMPDIR=/tmp/claude`, disabled auto-updater/feedback/error reporting/auto-memory/terminal titles, project PWD maintenance, and `MANPAGER=cat`. `SHELL` resolves Bash from PATH at render time rather than retaining a Nix store path.

**Plugins & Marketplaces:**

- Shared: `claude-md-management@claude-plugins-official`, `harness@agents`, `coding@agents`; `devflow@agents` disabled
- Personal/dev (`claude_work_machine=false`, the default): `claude-code-knowledge` and `dev` from the local `claude-code-plugins` marketplace, `writing@agents`
- Work (`mise.work.toml`, `claude_work_machine=true`): `admin` and `backend` from `local-work`; `pb-prose`, `pb-news`, and `pb-claude-harness-engineering` from `pb-claude`
- Local marketplaces resolve under the current user's home directory, including the existing work checkout paths
- `claude_enable_notify` defaults to `false`; opt in via `[vars]` in untracked `mise.local.toml` to add `cc-notify@cc-notify-marketplace` and its GitHub marketplace. Notification hooks belong to that plugin; daemon deployment is separate via `services:apply`

All remaining feature flags and skill overrides are preserved in the template. Project-local settings and local overrides are not managed by this resource.

### [SPEC-001-S4.2] Agents

**Global (`claude/agents/` → `~/.claude/agents/`):**

| Agent | Model | Tools/Skills | Purpose |
| --- | --- | --- | --- |
| api-researcher | haiku | Glob, Grep, Read, Skill, WebFetch, WebSearch, context7 MCP | Version-aware API documentation research |
| browser-user | sonnet | playwright-cli skill | Browser interaction with auth state loading |

**Disabled (`claude/x-agents/`):** `browser-devtools` (sonnet, chrome-devtools MCP) — DevTools diagnostics. Prefix convention keeps files out of Claude's agent discovery.

### [SPEC-001-S4.3] Skills

**Global (`claude/skills/` → `~/.claude/skills/`):**

| Skill          | Tools                   | Purpose                                                |
| -------------- | ----------------------- | ------------------------------------------------------ |
| commit         | Bash(git:\*)            | Conventional commits with auto status/diff injection   |
| playwright-cli | Bash(playwright-cli:\*) | Full browser automation (279 lines + 7 reference docs) |

### [SPEC-001-S4.4] Commands (`claude/commands/` → `~/.claude/commands/`)

| Command     | Key Feature                                                        |
| ----------- | ------------------------------------------------------------------ |
| github      | Issue/PR reading via `gh --json`, PR creation with HEREDOC         |
| ct/bonkai   | Architect role with subagent delegation (disable-model-invocation) |
| ct/socrates | Self-introspection on knowledge sources                            |
| ct/speak    | Audio communication via cc-speak TTS                               |

### [SPEC-001-S4.5] Global rules (`claude/CLAUDE.md` → `~/.claude/CLAUDE.md`)

Single file covering ways of working, repo conventions, git rules (commit only when asked, atomic, HEREDOC format, never `--no-verify`), comment style, and tool-schema fixes.

### [SPEC-001-S4.6] Claude Wrapper (`home/.local/bin/cl`)

Bash wrapper prepending context-aware system prompts to `claude` CLI:

- Repository type detection: `/work/*` → GitLab hints; else → GitHub hints
- Always injected: sub-agent concurrency rules, conciseness directive, tool schema warning
- Effort defaults: opus→high, others→medium
- Flags: `-d` (skip permissions), `--dry-run`, `-m/--model`, `--effort`

### [SPEC-001-S4.7] Pi Configuration (`pi/`)

Direct `pi` invocation with shared repo-aware configuration:

- `agent.njk`: template used to inject the appended system prompt and repo-specific runtime instructions into Pi sessions
- `README.md`: local docs for the repo-owned Pi bootstrap layout
- `settings.json`: minimal global Pi defaults and enabled model list used by the subagent compatibility shim
- Most reusable Pi agents/skills now live in `https://github.com/codethread/agents`; this repo keeps the template and any local compatibility glue needed to consume that shared source
- `extensions/claude-sync.ts`: project-local Pi extension that treats `.claude/` as source-of-truth and creates `.pi/skills -> .claude/skills`, `.pi/agents -> .claude/agents`, and flattened `.pi/prompts/*.md -> .claude/commands/**/*.md` symlinks on startup
- `extensions/subagent/agents.ts`: project-local agent loader for the `subagent` extension; follows symlinked `.pi/agents`, normalizes Claude tool names to Pi tools, strips unsupported tools, and resolves Claude model aliases like `sonnet`/`haiku` to concrete enabled OpenAI models from `pi/settings.json`
- `extensions/subagent/index.ts`: adds `/debug-agents` to show discovered agents with resolved model and normalized tools
- Machine-local state stays outside the repo: `auth.json`, `models.json`, `sessions/`

### [SPEC-001-S4.8] Codex Configuration (`config/codex/`)

- `config.toml`: model gpt-5.4, personality pragmatic, effort high. Profiles: fast-review (gpt-5.3-codex, medium), deep-review (gpt-5.4, high). 15 trusted project paths. Falls back to CLAUDE.md for project docs.
- `AGENTS.md`: global instruction for conciseness

### [SPEC-001-S4.9] Agent CLI Packages

- `config/mise/config.toml`: native Claude/Cursor, Node-based Pi, TypeScript and its language server.
- `.mise/conf.d/packages.toml`: Homebrew Codex/Node and user-prefix Playwright CLI.
- `.mise/conf.d/tools.toml`: project link to the global tools file, so first bootstrap does not require installed global config.
- `pi/agent/settings.json`: Pi-owned npm extension installation; no Nix tarballs or manually assembled dependency trees.

### [SPEC-001-S4.10] Nushell Wrappers (`config/nushell/scripts/ct/interactive/claude.nu`)

- `clf`/`clo`/`cls`/`clh` — model-specific Claude wrappers (fable/opus/sonnet/haiku)
- `--output-style` and `--settings` (a nushell record) serialise to `claude --settings '<json>'`, giving per-session overrides of the mise-managed globals
- output style defaults to `pairing` for tty sessions; `--print` runs omit it so headless output stays terse
- `cll` — ephemeral haiku session with auto-cleanup of session files
- `_claude-session`, `_claude-prompts`, `_claude-session-stats` — session log analysis

### [SPEC-001-S4.11] Hook Implementations

**TypeScript (oven/bin/, compiled to ~/.local/bin/):**

| Hook | Key Behavior |
| --- | --- |
| cc-hook--context-injector | Session start: glob README.md files, output listing as plain text to stdout. Session end: rm /tmp state file. |
| cc-hook--npm-redirect | Walk dir tree for lock files (bun > pnpm > yarn > npm). Quote-aware. Skill/plugin context bypass. Exit 2 + suggestion on mismatch. |

**Bash (home/.local/bin/):**

| Hook | Key Behavior |
| --- | --- |
| cc-hook--notify | POST to cc-notify daemon. Stop: "Done · $PROJECT" + 120-char snippet. PermissionRequest: tool-specific detail. |
| cc-hook--activity | POST session_id to /activity to cancel pending notification. Fail silent. |

### [SPEC-001-S4.12] Supporting Tools

| Tool | Source | Purpose |
| --- | --- | --- |
| cc-statusline | oven/bin/cc-statusline.ts | Process Claude Code status line data |
| cc-speak | oven/bin/cc-speak.ts | TTS with markdown stripping, file/section reading |
| cindex | oven/bin/cindex.ts | Project file index generator for context injection |
| cc-logs--extract-agents | home/.local/bin/ (bash) | Extract agent IDs with prompts/models for session resumption |

### [SPEC-001-S4.13] Keybindings (`claude/keybindings.json`)

Disables Ctrl+A in Global context.

## [SPEC-001-S5] 5. Design Decisions

- **Mise as settings source of truth.** `templates/claude-settings.json.tera` renders to a regular `~/.claude/settings.json`; profile overlays select work plugins and marketplaces. Applying settings no longer requires a Nix rebuild. Manual edits to the output are overwritten on apply; use project-local or local override settings for overrides.

- **Native package ownership on macOS.** Mise declares host packages and global tools; Playwright is npm-managed in `~/.local`, and Pi uses its npm/Node distribution. Running Codex as a native binary prevents it from inheriting a project-scoped Node runtime.

- **Dotty for asset linking, not Nix.** Agents, skills, commands, and rules are symlinked by dotty rather than Nix home-manager. This allows editing assets in dots and seeing changes immediately without a nix rebuild. Global settings are templated by mise separately from asset linking.

- **x-agents/ prefix convention.** Disabled agents live in `claude/x-agents/` — the prefix keeps them out of Claude's discovery path while keeping them version-controlled for re-enablement.

- **Hook I/O via stdin/stdout JSON.** Hooks receive structured input on stdin and return structured output on stdout. Exit code 2 blocks the operation. This matches Claude Code's hook protocol and allows both TypeScript and Bash implementations.

- **Shared agent assets live in `codethread/agents`.** Pi-related reusable agents/skills are primarily authored and maintained there now; this repo keeps only the `pi/agent.njk` template and compatibility shims needed to append the right system prompt and consume the shared assets.

- **Wrapper-injected system prompts.** Shell wrappers add context-dependent prompts at launch rather than embedding them in settings.json. `cl` injects richer Claude-specific guidance (repo type, concurrency, concision, tool realism, sandbox awareness). `pi` now uses `pi/agent.njk` as the template for appended system prompt management, while the heavier reusable config lives in `codethread/agents`. This keeps prompts context-dependent without polluting global config.

- **Package manager detection by lock file.** `cc-hook--npm-redirect` walks the directory tree looking for lock files in priority order (bun > pnpm > yarn > npm). This is more reliable than checking tool presence and handles monorepos.

## [SPEC-001-S6] 6. Testing

**TypeScript hooks:** Unit tests in `oven/tests/`:

- `cc-hook--context-injector.test.ts` — session start/end lifecycle
- `cc-hook--npm-redirect.test.ts` — PM detection, redirection, quote awareness, skill bypass

**No direct tests for:** bash hooks (cc-hook--notify, cc-hook--activity), `cl` wrapper, direct `pi` usage, nushell wrappers. These require manual verification.

## [SPEC-001-S7] 7. Open Questions

- The `x-agents/` convention works but is undocumented outside `claude/README.md` — should disabled agents use a more formal mechanism?
- Codex config shares the dotty `config` project with all other XDG configs. If Codex needs more files, a dedicated dotty project may be cleaner.
