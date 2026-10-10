# Agentic Configuration Specification

- Document ID: SPEC-001
- Configuration identification: SPEC-001; migrated from `specs/agentic-config.md`; canonical path `devflow/specs/agentic-config.md`.
- **Status:** Implemented
- **Last Updated:** 2026-10-10

## [SPEC-001-S1] 1. Overview

### [SPEC-001-S1.1] Purpose

Declarative configuration system for Claude Code, OpenAI Codex, Pi, and related agent CLIs. Manages package provisioning, settings generation, hook compilation, asset symlinks, plugin wiring, and shell wrappers — with `mise bootstrap` provisioning packages/assets/tools and applying workstation setup, and `mise dot apply ~/.claude/settings.json` applying global Claude settings.

### [SPEC-001-S1.2] Goals

- Single source of truth for global Claude settings in `templates/claude-settings.json.tera`, rendered by mise
- Mise provisions native Codex/Claude CLIs, Node-based Pi, and Playwright CLI; Pi owns its npm extensions
- Agent assets version-controlled and symlinked into place: mise owns shared personal skills; Dotty owns other agent assets
- Type-safe hook contracts shared across TypeScript and Bash implementations
- Context-aware shell wrappers that inject environment-specific prompts
- Plugin extensibility via local and remote marketplaces
- Shared Codex settings merged by mise without replacing machine-local state

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
│   Official agent installers via bootstrap setup     │
│   Owns: agent CLI binaries                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Layer 1: Mise-rendered globals                      │
│   templates/claude-settings.json.tera               │
│     → ~/.claude/settings.json (regular file)        │
│   templates/codex-config.toml                       │
│     → ~/.config/codex/config.toml (key merge)       │
│   Owns: permissions, hooks, env vars, plugins,      │
│         marketplaces, feature flags                  │
├─────────────────────────────────────────────────────┤
│ Layer 2: Symlinked assets                          │
│   mise: home/.agents/skills/                        │
│     → ~/.agents/skills/ and ~/.claude/skills/       │
│   dotty: claude/ → ~/.claude/                      │
│     agents/, commands/,                            │
│     CLAUDE.md, keybindings.json                     │
│   pi/ → ~/.pi/agent/                                │
│     agent.njk, README.md, settings.json             │
│     (appended system prompt + shared defaults)       │
│   config/codex/ → ~/.config/codex/                  │
│     AGENTS.md                                      │
├─────────────────────────────────────────────────────┤
│ Layer 3: Project-local overrides (per-repo)         │
│   .claude/settings.json    (repo-specific hooks)    │
│   .claude/settings.local.json (machine-local)       │
│   .claude/agents/, .claude/skills/, .claude/commands/ │
│   .pi/{agents,skills,prompts} may be generated as   │
│   symlinks back to .claude for Pi compatibility     │
└─────────────────────────────────────────────────────┘
```

Settings merge order: mise globals → project settings → local overrides. Agent CLI packages are supplied separately by official installers run from the bootstrap setup hook; explicit updates use the `llm:update` task. This spec covers the package layer plus layers 1 and 2 only.

### [SPEC-001-S2.1] Build Pipeline

```
mise bootstrap → packages, declared repositories, native files, and setup applied
mise dot apply ~/.claude/settings.json → ~/.claude/settings.json rendered
mise dot apply ~/.config/codex/config.toml/shared → shared Codex keys merged
make link    →  dotty link + targeted mise apply → assets, home files, shared skills
make build   →  bun verify   →  oven/bin/*.ts compiled to ~/.local/bin/ wrappers
```

`make` (default target `all`) runs `boot`, which invokes `mise bootstrap`. Bootstrap applies packages, declared repositories, native files, and services; its setup hook installs agent CLIs, links dotfiles, prepares the shell, and verifies/builds Oven.

### [SPEC-001-S2.2] Package Provisioning

- Mise provides the Node runtime; root `mise.toml` installs the user-prefix Playwright CLI with that runtime.
- `mise.toml` provides the `llm:update` task, while `boot/setup.sh` invokes `home/.local/bin/mise-llm install` during bootstrap for official Claude, Codex, and Pi installers. `llm:update` updates them and Pi's npm extensions, stopping on failure.
- Pi installs missing `npm:pi-nvim` and `npm:@narumitw/pi-goal` extensions from `pi/agent/settings.json`.

`boot/setup.sh` invokes `home/.local/bin/mise-llm install` in the bootstrap post-repos hook. `~/.local/bin` precedes `$PI_CODING_AGENT_DIR/bin` and mise shims, preserving the custom Pi wrapper. Use `mise run llm:update` for explicit updates.

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
- Excludes: `**/settings.json`, `**/settings.local.json`, `**/skills/**`
- Linked paths cached at `~/.local/data/dotty-cache-claude.nuon`; home files and shared skills are mise-owned

The `config` project covers `config/codex/` → `~/.config/codex/` as part of the broader `config/ → ~/.config/` mapping.

## [SPEC-001-S4] 4. Interfaces

### [SPEC-001-S4.1] Settings Generation (`templates/claude-settings.json.tera`)

Mise owns `~/.claude/settings.json` as a rendered regular file via root `mise.toml`; dotty excludes it. Apply with `mise dot apply ~/.claude/settings.json`. `/tmp/claude` is declared in root `mise.toml` and prepared by the native files phase, not `mise dot apply`. See [Claude README](../../claude/README.md) for the apply workflow.

**Permissions:** The shared template owns the common allow/deny lists, `acceptEdits` default mode, and additional directories (`~/.local`, `~/.claude`, `~/dev`). Workfiles' JSON overlay adds the work directory and Microsoft 365/Atlassian allowances; the template unions overlay `permissions` lists (`allow`, `ask`, `deny`, `additionalDirectories`) with its own, so the overlay lists only additions. Secret-file reads, plan/worktree/cron tools, and other unwanted tools remain denied.

**Global hook:** `PostToolUse[Write]` runs inline `git add -N` for new files. Status line uses `cc-statusline`.

**Environment:** Keeps the previous environment variables, including `TMPDIR=/tmp/claude`, disabled auto-updater/feedback/error reporting/auto-memory/terminal titles, project PWD maintenance, and `MANPAGER=cat`. `SHELL` resolves Bash from PATH at render time rather than retaining a fixed system path.

**Plugins & Marketplaces:**

- Shared: `claude-md-management@claude-plugins-official`, `harness@agents`, `coding@agents`; `devflow@agents` disabled
- Default: `claude-code-knowledge` and `dev` from the local `claude-code-plugins` marketplace, `writing@agents`
- Workfiles installs `~/.config/claude/settings-overlay.json`: it disables those default plugins and enables its work plugins/marketplaces, with paths rendered under the current user's home directory
- The shared template deep-merges that optional JSON object over its base; malformed overlays fail visibly. Dots remains the only owner of `~/.claude/settings.json`. Workfiles' post-dotfiles hook requests a targeted rerender from dots after installing its overlay; subsequent dots applies consume the same overlay
- `claude_enable_notify` defaults to `false`; opt in via `[vars]` in untracked `mise.local.toml` to add `cc-notify@cc-notify-marketplace` and its GitHub marketplace. Notification hooks belong to that plugin; daemon deployment is part of `mise bootstrap`

All remaining feature flags and skill overrides are preserved in the template. Project-local settings and local overrides are not managed by this resource.

### [SPEC-001-S4.2] Agents

**Global (`claude/agents/` → `~/.claude/agents/`):**

| Agent | Model | Tools/Skills | Purpose |
| --- | --- | --- | --- |
| api-researcher | haiku | Glob, Grep, Read, Skill, WebFetch, WebSearch, context7 MCP | Version-aware API documentation research |
| browser-user | sonnet | playwright-cli skill | Browser interaction with auth state loading |

**Disabled (`claude/x-agents/`):** `browser-devtools` (sonnet, chrome-devtools MCP) — DevTools diagnostics. Prefix convention keeps files out of Claude's agent discovery.

### [SPEC-001-S4.3] Skills

**Shared personal (`home/.agents/skills/` → both `~/.agents/skills/` and `~/.claude/skills/`):**

Root mise entries use `symlink-each`: the home mapping supplies the first destination, and a second entry supplies Claude’s. Both keep destination directories real and preserve unmanaged files, including Claude’s `synced/` and `.trash/`. Existing-file edits are immediate; additions/removals require `make link` or `mise dot apply ~ ~/.claude/skills` from dots. Destination-only skills are not copied back into the repository. Plugin skills remain plugin-owned.

| Skill      | Purpose                                            |
| ---------- | -------------------------------------------------- |
| attention  | Get the user’s attention after a long-running task |
| github     | Work with GitHub issues and pull requests          |
| repo-setup | Set up repository agent scaffolding                |
| socrates   | Inspect knowledge sources and assumptions          |

### [SPEC-001-S4.4] Commands (`claude/commands/` → `~/.claude/commands/`)

| Command     | Key Feature                                                        |
| ----------- | ------------------------------------------------------------------ |
| github      | Issue/PR reading via `gh --json`, PR creation with HEREDOC         |
| ct/bonkai   | Architect role with subagent delegation (disable-model-invocation) |
| ct/socrates | Self-introspection on knowledge sources                            |
| ct/speak    | Audio communication via cc-speak TTS                               |

### [SPEC-001-S4.5] Global rules (`claude/CLAUDE.md` → `~/.claude/CLAUDE.md`)

Single file covering ways of working, repo conventions, git rules (commit only when asked, atomic, HEREDOC format, never `--no-verify`), comment style, and tool-schema fixes.

### [SPEC-001-S4.6] Claude Launcher (`home/.local/bin/cl`)

The single Claude entrypoint for people and tooling: sensible defaults, with flags to override them. Shells add only conveniences (S4.10).

- Defaults: `--dangerously-skip-permissions`; `outputStyle: pairing` for interactive sessions (`-p/--print` omits it so headless output stays terse); claude.ai connectors off via the shared template's `env.ENABLE_CLAUDEAI_MCP_SERVERS="false"`
- Appended system prompt: forge hint from `origin` (`github.com` → gh, any other remote → glab, none outside git) and sub-agent concurrency rules; a caller's `--append-system-prompt` is appended after them
- Overrides: `-s/--safe` keeps permission prompts; `--mcp-work` sets `env.ENABLE_CLAUDEAI_MCP_SERVERS="true"` in the session `--settings`, which outranks user settings. Settings `env` also outranks the process environment, so launchers must re-enable connectors with `--settings`, not an exported variable. `disableClaudeAiConnectors` is unsuitable: any source setting it true wins
- `-m/--mine` sets `CLAUDE_CONFIG_DIR=~/.config/claude`; `--output-style` and `--settings` (JSON object or file) merge into one session `--settings`
- `--dry-run` prints the command; `-h/--help` prints cl's options followed by `claude --help`
- Claude subcommands (`mcp`, `plugin`, `doctor`, ...) pass through untouched; all other arguments pass to `claude`
- Effort comes from the shared `effortLevel` setting; `--effort` passes through

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

### [SPEC-001-S4.8] Codex Configuration

- `templates/codex-config.toml`: shared model, reasoning, TUI, plugin, marketplace, and skill settings. Root `mise.toml` owns these keys via a native `merge = true` edit at `~/.config/codex/config.toml/shared` (mise 2026.10.4+). The destination follows this repo's `CODEX_HOME`, not Codex's default `~/.codex`.
- Tables merge recursively; target-only settings such as trusted projects, MCP servers, and application state remain local. Comments and untouched TOML formatting survive. Arrays, including `skills.config`, replace wholesale. Removing a source key does not delete it from the target. Live edits are not synchronized back into the source.
- Preview with `mise dot diff ~/.config/codex/config.toml/shared`; apply with `mise dot apply ~/.config/codex/config.toml/shared`. Dotty's former structured-template option and cache are no longer used.
- `config/codex/AGENTS.md`: global instruction for conciseness, still symlinked by dotty.

### [SPEC-001-S4.9] Agent CLI Packages

- `mise.toml`, `boot/setup.sh`, and `home/.local/bin/mise-llm`: official agent CLI installation and updates.
- `config/mise/config.toml`: runtimes, TypeScript and its language server.
- `mise.toml`: user-prefix Playwright CLI.
- `.mise/conf.d/tools.toml`: project link to the global tools file, so first bootstrap does not require installed global config.
- `pi/agent/settings.json`: Pi-owned npm extension declarations.

### [SPEC-001-S4.10] Zsh Conveniences (`config/zsh/claude.zsh`)

- `cls`/`clo`/`clh`: `cl --model sonnet|opus|haiku`
- `_dots_cl` completion for `cl` and the shortcuts: options parsed from `cl --help` (cl's plus claude's), with values for `--output-style` (built-ins plus `output-styles/*.md`), `--model`, `--effort`, `--permission-mode`, `--settings` and `--add-dir`
- Sourced after `compinit` so `compdef` is available

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

- **Mise as settings source of truth.** `templates/claude-settings.json.tera` renders to a regular `~/.claude/settings.json`; an optional `~/.config/claude/settings-overlay.json` supplies separately owned machine policy. Applying settings requires no system-layer change. Manual edits to the output are overwritten on apply; use project-local or local override settings for overrides.

- **One owner per agent CLI.** Official vendor installers own Claude, Codex, and Pi; bootstrap setup installs them and the `llm:update` task updates them. Node remains mise-managed, Playwright is npm-managed in `~/.local`, and Pi uses its official locked Node/npm installation. Running Codex as a native binary prevents it from inheriting a project-scoped Node runtime.

- **One owner per asset path.** Mise links `home/` and exposes its shared skills to both agent locations with `symlink-each`; Dotty links other agents, commands, and rules, excluding Claude settings and skills. Real destination directories preserve application-owned metadata. Existing linked-file edits remain immediate, while new or removed files require another apply. Global settings are managed separately by mise.

- **x-agents/ prefix convention.** Disabled agents live in `claude/x-agents/` — the prefix keeps them out of Claude's discovery path while keeping them version-controlled for re-enablement.

- **Hook I/O via stdin/stdout JSON.** Hooks receive structured input on stdin and return structured output on stdout. Exit code 2 blocks the operation. This matches Claude Code's hook protocol and allows both TypeScript and Bash implementations.

- **Shared agent assets live in `codethread/agents`.** Pi-related reusable agents/skills are primarily authored and maintained there now; this repo keeps only the `pi/agent.njk` template and compatibility shims needed to append the right system prompt and consume the shared assets.

- **Wrapper-injected system prompts.** Shell wrappers add context-dependent prompts at launch rather than embedding them in settings.json. `cl` injects the forge hint and sub-agent concurrency rules. `pi` now uses `pi/agent.njk` as the template for appended system prompt management, while the heavier reusable config lives in `codethread/agents`. This keeps prompts context-dependent without polluting global config.

- **Package manager detection by lock file.** `cc-hook--npm-redirect` walks the directory tree looking for lock files in priority order (bun > pnpm > yarn > npm). This is more reliable than checking tool presence and handles monorepos.

## [SPEC-001-S6] 6. Testing

**TypeScript hooks:** Unit tests in `oven/tests/`:

- `cc-hook--context-injector.test.ts` — session start/end lifecycle
- `cc-hook--npm-redirect.test.ts` — PM detection, redirection, quote awareness, skill bypass

**No direct tests for:** bash hooks (cc-hook--notify, cc-hook--activity), `cl` wrapper, direct `pi` usage, zsh wrappers. These require manual verification.

## [SPEC-001-S7] 7. Open Questions

- The `x-agents/` convention works but is undocumented outside `claude/README.md` — should disabled agents use a more formal mechanism?
- Codex config shares the dotty `config` project with all other XDG configs. If Codex needs more files, a dedicated dotty project may be cleaner.
