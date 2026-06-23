# cc-sandbox Specification

Document ID: SPEC-002
Configuration identification: SPEC-002; migrated from `specs/cc-sandbox.md`; canonical path `devflow/specs/cc-sandbox.md`.
**Status:** Implemented
**Last Updated:** 2026-04-04

## [SPEC-002-S1] 1. Overview

### [SPEC-002-S1.1] Purpose

Podman-based container isolation for running Claude Code, Codex, and Pi headless sessions. Provides a reproducible, auditable environment with full config forwarding (SSH, git, credentials, dotfiles) while preventing uncontrolled host access.

### [SPEC-002-S1.2] Goals

- Deterministic container image with pinned tool versions (Claude, Codex, Pi, Bun, Nushell, Playwright, Chromium, GitHub CLI, Neovim)
- Mount current project + credentials without leaking host filesystem
- SSH agent forwarding across Linux and macOS (Podman VM tunnel on macOS)
- Session persistence via host→container project key mapping (Claude + Pi)
- Selective host command execution via cc-bridge Unix socket
- Push notification integration via cc-notify port forwarding
- Smoke-testable: `cc-sandbox-smoke` validates binary presence, PATH, mounts, and optional API pings

### [SPEC-002-S1.3] Non-Goals

- Agent configuration (settings, hooks, agents, skills) — covered by [agentic-config spec](./agentic-config.md)
- cc-notify daemon internals — external project at `~/dev/projects/cc-notify`
- General Podman/container orchestration — this is a single-purpose launcher

## [SPEC-002-S2] 2. Architecture

```
Host                                    Container (Podman)
────────────────────────────────────────────────────────────
cc-sandbox (launcher)
  │
  ├── podman build (Containerfile)
  │     └── node:22-slim base
  │         + system deps (chromium, ffmpeg, git, jq, ...)
  │         + tools (claude, codex, pi, bun, nu, gh, neovim, playwright-cli)
  │         + dots copied + dotty link + bun run build
  │
  ├── podman run
  │     ├── Mounts:
  │     │   ├── $PWD → /vm/$PROJECT_DIR
  │     │   ├── credentials (settings.json, .credentials.json, .claude.json, pi auth/models)
  │     │   ├── git config (ro)
  │     │   ├── SSH agent socket
  │     │   ├── playwright auth states (ro, per --auth flag)
  │     │   ├── todoist config (ro)
  │     │   └── session dirs (~/.claude/projects/$KEY, ~/.pi/agent/sessions/$KEY)
  │     │
  │     ├── Environment:
  │     │   ├── CC_SANDBOX=1, CC_HOST_PWD
  │     │   ├── CC_NOTIFY_HOST, CC_NOTIFY_PORT
  │     │   ├── CODEX_HOME, PI_CODING_AGENT_DIR, GITHUB_TOKEN
  │     │   └── TERM, COLORTERM, SSH_AUTH_SOCK
  │     │
  │     └── Launcher passes: cl --dangerously-skip-permissions [CLAUDE_ARGS...]
  │         (Containerfile CMD is bash; launcher always overrides)
  │         Pi remains available explicitly via --run (e.g. `cc-sandbox -r 'pim ...'`)
  │
  ├── cc-bridge daemon (optional, --bridge flag)
  │     └── Unix socket → container shims for host commands
  │
  └── SSH tunnel (macOS only)
        └── Reverse tunnel for SSH agent into Podman VM

cc-notify daemon (:$PORT)  ◄── POST /notify, /activity
  (separate process)            from hooks inside container
```

### [SPEC-002-S2.1] Component Boundaries

| Component | Location | Role |
|-----------|----------|------|
| Launcher | `home/.local/bin/cc-sandbox` | Builds image, runs container, manages tunnels/bridge |
| Containerfile | `home/.local/share/cc-sandbox/Containerfile` | Image definition with tool installation |
| .containerignore | `home/.local/share/cc-sandbox/.containerignore` | Whitelist-based build context filter |
| Bridge | `oven/bin/cc-bridge.ts` | Host↔container command proxy via Unix socket |
| Smoke test | `config/nushell/scripts/ct/interactive/claude.nu` | `cc-sandbox-smoke` function |

## [SPEC-002-S3] 3. Data Model

### [SPEC-002-S3.1] Session Key Mapping

Host and container use different project keys for the same session directory because the container cwd is `/vm/$PROJECT_DIR`.

#### [SPEC-002-S3.1.1] Claude keys

| Side | Key Format | Example |
|------|-----------|---------|
| Host | `$PWD` with `/` → `-` | `-home-codethread-dev-myproject` |
| Container | `-vm-$PROJECT_DIR` | `-vm-myproject` |

Mount: `~/.claude/projects/${HOST_KEY}/` → `~/.claude/projects/${CONTAINER_KEY}/`

#### [SPEC-002-S3.1.2] Pi keys

Pi session dirs are wrapped in `--...--`:

| Side | Key Format | Example |
|------|-----------|---------|
| Host | `--${HOST_KEY}--` | `--home-codethread-dev-myproject--` |
| Container | `--vm-${PROJECT_DIR}--` | `--vm-myproject--` |

Mount: `~/.pi/agent/sessions/${HOST_PI_KEY}/` → `~/.pi/agent/sessions/${CONTAINER_PI_KEY}/`

This enables both Claude and Pi session persistence across container restarts while translating host/container paths.

### [SPEC-002-S3.2] cc-bridge Protocol

Request (JSON over Unix socket):
```typescript
interface BridgeRequest {
  cmd: string;   // must be in allowlist
  args: string[];
}
```

Response (JSON):
```typescript
interface CommandResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}
```

Stateless, fire-and-forget — no stdin forwarding, no interactive commands.

### [SPEC-002-S3.3] Build Args

| Arg | Default | Detection |
|-----|---------|-----------|
| CLAUDE_VERSION | — | `claude --version` on host |
| NODE_VERSION | 22 | hardcoded |
| NUSHELL_VERSION | 0.111.0 | hardcoded |
| PLAYWRIGHT_CLI_VERSION | latest | `playwright-cli --version` on host |
| CODEX_VERSION | 0.116.0 | `codex --version` on host |
| PI_VERSION | 0.64.0 | `pi --version` on host |
| YT_DLP_VERSION | (empty) | `yt-dlp --version` on host, skipped if absent |
| ARCH_GNU/ARCH_NODE/ARCH_GO | — | detected from `uname -m` |

## [SPEC-002-S4] 4. Interfaces

### [SPEC-002-S4.1] cc-sandbox CLI (`home/.local/bin/cc-sandbox`)

```
cc-sandbox [OPTIONS] [-- CLAUDE_ARGS...]

Options:
  -n, --no-cache     Rebuild image without cache
  -i, --interactive  Start bash shell instead of default `cl` wrapper
  -r, --run CMD      Execute specific command in container (e.g. `pim --help`)
  -b, --bridge CMD   Expose host command via cc-bridge (repeatable)
  -a, --auth SITE    Mount playwright auth state (repeatable)
  -p PORT            Forward port (repeatable)
  -h, --help         Show usage
```

Default command (assembled by launcher, overriding Containerfile's `CMD ["bash"]`): `cl --dangerously-skip-permissions [CLAUDE_ARGS...]`

Pi is still available in the same sandbox image via explicit run commands, e.g. `cc-sandbox -r 'pim --help'`.

### [SPEC-002-S4.2] Mounts

| Host Path | Container Path | Mode | Condition |
|-----------|---------------|------|-----------|
| `$PWD` | `/vm/$PROJECT_DIR` | rw | always |
| `~/.claude/settings.json` | `/home/user/.claude/settings.json` | rw | always (temp copy) |
| `~/.claude/.credentials.json` | `/home/user/.claude/.credentials.json` | rw | always |
| `~/.claude.json` | `/home/user/.claude.json` | rw | always |
| `~/.config/git/` | `/home/user/.config/git/` | ro | if exists |
| `~/.codex/auth.json` | `/home/user/.config/codex/auth.json` | rw | if exists |
| `~/.pi/agent/auth.json` | `/home/user/.pi/agent/auth.json` | rw | if exists |
| `~/.pi/agent/models.json` | `/home/user/.pi/agent/models.json` | ro | if exists |
| SSH agent socket | `/tmp/ssh-agent.sock` | — | Linux: bind; macOS: reverse tunnel |
| `~/.ssh/config` | `/home/user/.ssh/config` | ro | filtered for Linux compat |
| `~/.config/playwright/states/<site>.json` | same path | ro | per `--auth` flag |
| todoist config | `/home/user/.config/todoist/config.json` | ro | if exists AND cwd is `~/dev/projects/notes` or subdirectory |
| cc-bridge socket | `/tmp/cc-bridge.sock` | rw | if `--bridge` |
| Claude session dir | `~/.claude/projects/$CONTAINER_KEY/` | rw | always |
| Pi session dir | `~/.pi/agent/sessions/$CONTAINER_PI_KEY/` | rw | always |
### [SPEC-002-S4.3] Environment Variables Forwarded

| Variable | Value/Source | Purpose |
|----------|-------------|---------|
| CC_SANDBOX | `1` (baked in image via `ENV`, not forwarded by launcher) | Triggers container-aware prompts in wrappers |
| CC_HOST_PWD | `$PWD` (host) | Original host path for wrapper repo classification |
| CC_NOTIFY_HOST | `host.containers.internal` | cc-notify daemon reachable via host gateway |
| CC_NOTIFY_PORT | from port file | cc-notify daemon port |
| CODEX_HOME | `/home/user/.config/codex` | Codex config location |
| PI_CODING_AGENT_DIR | `/home/user/.pi/agent` | Pi config location |
| GITHUB_TOKEN | from `$GH_AGENTS_RO` | Read-only GitHub token |
| SSH_AUTH_SOCK | `/tmp/ssh-agent.sock` | Forwarded agent |
| TERM, COLORTERM | from host | Terminal config |

### [SPEC-002-S4.4] cc-bridge CLI (`oven/bin/cc-bridge.ts`)

Three subcommands:

**`serve`** (host side): Listen on Unix socket, execute allowed commands.
```
cc-bridge serve --allow cmd1,cmd2 [--socket PATH]
```

**`exec`** (container side): Send command to daemon, relay output.
```
cc-bridge exec [--socket PATH] CMD [ARGS...]
```

**`install`** (container side): Create transparent shims in PATH.
```
cc-bridge install --commands cmd1,cmd2 [--bin-dir PATH]
```

Each shim: `#!/usr/bin/env bash\nexec cc-bridge exec CMD "$@"`

### [SPEC-002-S4.5] Containerfile (`home/.local/share/cc-sandbox/Containerfile`)

Multi-stage build:
1. **todoist-build** — Go build of custom todoist fork (`codethread/todoist`, branch `codethread`)
2. **Final stage** — node:22-slim + system deps + tool installation + dots integration

Tool installation order: system packages → neovim → bun → claude binary → yt-dlp → todoist → playwright-cli → codex → pi → gh → nushell.

dots integration:
1. Copy `oven/`, run `bun install` (dependency layer cache)
2. Copy full repo, `git init` (fresh, no history)
3. `dotty link --no-cache` (creates ~/.claude symlinks for agents/commands/skills/rules)
4. `bun run build` in oven/ (compiles hooks + tools to ~/.local/bin/)
5. `nvim --headless "+Lazy! install" +qa` (pre-install neovim plugins)

Container environment: `PLAYWRIGHT_MCP_EXECUTABLE_PATH=/usr/bin/chromium` (prevents .playwright/cli.config.json leaking to host bind mount), `CC_SANDBOX=1`, `EDITOR=nvim`, `NVIM_APPNAME=minimal-nvim`.

### [SPEC-002-S4.6] Podman Execution Flags

- `--userns=keep-id` — UID remapping (non-root)
- `--shm-size=2g` — shared memory for Chromium
- `--security-opt seccomp=unconfined` — required for Chromium
- `--add-host=host.containers.internal:host-gateway` — host reachability
- Container name: `cc-sandbox-<4-byte-random-hex>`
- Signal handlers clean up temp files, SSH tunnels, bridge daemons on exit

### [SPEC-002-S4.7] SSH Agent Forwarding

**Linux:** Direct bind-mount of `$SSH_AUTH_SOCK` into container.

**macOS:** Podman runs in a VM (virtiofs), so direct socket mount doesn't work. Instead:
1. Background: `podman machine ssh -R $VM_SOCK:$SSH_AUTH_SOCK -N`
2. Set socket permissions to 777 inside VM
3. Container binds the VM-side socket

Filtered SSH config: macOS-only directives (`usekeychain`) stripped before mounting.

## [SPEC-002-S5] 5. Design Decisions

- **Podman over Docker.** Rootless by default, UID remapping via `--userns=keep-id`, no daemon required. Aligns with NixOS packaging.

- **Whitelist-based .containerignore.** Starts with `**` (ignore all), then whitelists `claude/`, `pi/`, `config/`, `home/`, `oven/`, `devflow/`, and `nix/` (plus root metadata files like `README.md`, `CLAUDE.md`, `Makefile`, `.gitignore`). This keeps the build context explicit while ensuring in-container access to Pi workflow/spec docs (`specs/README.md`) and Nix configuration files.

- **Fresh git init in container.** `git init && git add .` instead of mounting the real `.git/`. Dotty requires a git repo (for .gitignore awareness), but full history is unnecessary and adds image size.

- **Dependency-first layer caching.** `oven/` is copied and `bun install` runs before the full repo copy. Changing non-oven files doesn't invalidate the dependency layer.

- **PLAYWRIGHT_MCP_EXECUTABLE_PATH hardcoded.** Without this, playwright-cli generates `.playwright/cli.config.json` in the project directory, which leaks into the host via the bind mount. Setting the env var bypasses this file generation.

- **cc-bridge allowlist model.** The bridge daemon only executes commands explicitly listed via `--allow`. This prevents arbitrary host command execution from within the container. Commands are typically things like `obsidian` (open files) — not interactive tools.

- **Session key translation (Claude + Pi).** Host paths contain absolute paths (e.g., `/home/codethread/dev/myproject`), but the container sees `/vm/myproject`. Mapping between keys lets session history persist across container restarts while paths remain valid in each context for both CLIs.

## [SPEC-002-S6] 6. Testing

**Smoke test (`cc-sandbox-smoke`):**
- Runs inside container via `cc-sandbox -r "nu -c 'cc-sandbox-smoke [flags]'"`
- Local checks: binary existence (claude, codex, pi, playwright-cli, bun, nu), versions, PATH (includes ~/.local/bin, ~/.bun/bin), CODEX_HOME and PI_CODING_AGENT_DIR set, settings.json mounted, codex config linked, pi config linked, project under /vm/, neovim plugins loaded
- Model checks (`--with-models`): headless Claude ping (haiku, 30s timeout), headless Codex exec (read-only sandbox, 30s timeout)
- Output: formatted table with check/ok/detail columns
- Full invocation from repo root: `nu -I ./config/nushell/scripts -c 'use ct/interactive/claude.nu *; cc-sandbox-smoke --stream --no-cache --with-models'`

**No unit tests for:** cc-sandbox launcher script, Containerfile. Verified via smoke test and manual usage.

**cc-bridge:** Unit tests in `oven/tests/cc-bridge.test.ts`.

## [SPEC-002-S7] 7. Open Questions

- Chromium version is pinned to whatever Debian ships in `node:22-slim`. May need explicit version pinning if playwright-cli requires a specific Chromium version.
- yt-dlp and todoist are niche tools bundled into the image. Could be moved to a separate "extras" layer or made optional build args.
