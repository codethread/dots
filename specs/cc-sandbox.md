# cc-sandbox Specification

**Status:** Implemented
**Last Updated:** 2026-04-02

## 1. Overview

### Purpose

Podman-based container isolation for running Claude Code (and Codex) headless sessions. Provides a reproducible, auditable environment with full config forwarding (SSH, git, credentials, dotfiles) while preventing uncontrolled host access.

### Goals

- Deterministic container image with pinned tool versions (Claude, Codex, Bun, Nushell, Playwright, Chromium, GitHub CLI, Neovim)
- Mount current project + credentials without leaking host filesystem
- SSH agent forwarding across Linux and macOS (Podman VM tunnel on macOS)
- Session persistence via host→container project key mapping
- Selective host command execution via cc-bridge Unix socket
- Push notification integration via cc-notify port forwarding
- Smoke-testable: `cc-sandbox-smoke` validates binary presence, PATH, mounts, and optional API pings

### Non-Goals

- Agent configuration (settings, hooks, agents, skills) — covered by [agentic-config spec](./agentic-config.md)
- cc-notify daemon internals — external project at `~/dev/projects/cc-notify`
- General Podman/container orchestration — this is a single-purpose launcher

## 2. Architecture

```
Host                                    Container (Podman)
────────────────────────────────────────────────────────────
cc-sandbox (launcher)
  │
  ├── podman build (Containerfile)
  │     └── node:22-slim base
  │         + system deps (chromium, ffmpeg, git, jq, ...)
  │         + tools (claude, codex, bun, nu, gh, neovim, playwright-cli)
  │         + PersonalConfigs copied + dotty link + bun run build
  │
  ├── podman run
  │     ├── Mounts:
  │     │   ├── $PWD → /vm/$PROJECT_DIR
  │     │   ├── credentials (settings.json, .credentials.json, .claude.json)
  │     │   ├── git config (ro)
  │     │   ├── SSH agent socket
  │     │   ├── playwright auth states (ro, per --auth flag)
  │     │   ├── todoist config (ro)
  │     │   └── session dir (~/.claude/projects/$KEY)
  │     │
  │     ├── Environment:
  │     │   ├── CC_SANDBOX=1, CC_HOST_PWD
  │     │   ├── CC_NOTIFY_HOST, CC_NOTIFY_PORT
  │     │   ├── CODEX_HOME, GITHUB_TOKEN
  │     │   └── TERM, COLORTERM, SSH_AUTH_SOCK
  │     │
  │     └── Launcher passes: cl --dangerously-skip-permissions
  │         (Containerfile CMD is bash; launcher always overrides)
  │
  ├── cc-bridge daemon (optional, --bridge flag)
  │     └── Unix socket → container shims for host commands
  │
  └── SSH tunnel (macOS only)
        └── Reverse tunnel for SSH agent into Podman VM

cc-notify daemon (:$PORT)  ◄── POST /notify, /activity
  (separate process)            from hooks inside container
```

### Component Boundaries

| Component | Location | Role |
|-----------|----------|------|
| Launcher | `home/.local/bin/cc-sandbox` | Builds image, runs container, manages tunnels/bridge |
| Containerfile | `home/.local/share/cc-sandbox/Containerfile` | Image definition with tool installation |
| .containerignore | `home/.local/share/cc-sandbox/.containerignore` | Whitelist-based build context filter |
| Bridge | `oven/bin/cc-bridge.ts` | Host↔container command proxy via Unix socket |
| Smoke test | `config/nushell/scripts/ct/interactive/claude.nu` | `cc-sandbox-smoke` function |

## 3. Data Model

### Session Key Mapping

Host and container use different project keys for the same session directory:

| Side | Key Format | Example |
|------|-----------|---------|
| Host | `$PWD` with `/` → `-` | `-home-codethread-dev-myproject` |
| Container | `-vm-$PROJECT_DIR` | `-vm-myproject` |

Host mounts `~/.claude/projects/${HOST_KEY}/` into container at `~/.claude/projects/${CONTAINER_KEY}/`. This enables session persistence across container restarts while translating paths.

### cc-bridge Protocol

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

### Build Args

| Arg | Default | Detection |
|-----|---------|-----------|
| CLAUDE_VERSION | — | `claude --version` on host |
| NODE_VERSION | 22 | hardcoded |
| NUSHELL_VERSION | 0.111.0 | hardcoded |
| PLAYWRIGHT_CLI_VERSION | latest | `playwright-cli --version` on host |
| CODEX_VERSION | 0.116.0 | `codex --version` on host |
| YT_DLP_VERSION | (empty) | `yt-dlp --version` on host, skipped if absent |
| ARCH_GNU/ARCH_NODE/ARCH_GO | — | detected from `uname -m` |

## 4. Interfaces

### cc-sandbox CLI (`home/.local/bin/cc-sandbox`)

```
cc-sandbox [OPTIONS] [-- CLAUDE_ARGS...]

Options:
  -n, --no-cache     Rebuild image without cache
  -i, --interactive  Start bash shell instead of claude
  -r, --run CMD      Execute specific command in container
  -b, --bridge CMD   Expose host command via cc-bridge (repeatable)
  -a, --auth SITE    Mount playwright auth state (repeatable)
  -p PORT            Forward port (repeatable)
  -h, --help         Show usage
```

Default command (assembled by launcher, overriding Containerfile's `CMD ["bash"]`): `cl --dangerously-skip-permissions [CLAUDE_ARGS...]`

### Mounts

| Host Path | Container Path | Mode | Condition |
|-----------|---------------|------|-----------|
| `$PWD` | `/vm/$PROJECT_DIR` | rw | always |
| `~/.claude/settings.json` | `/home/user/.claude/settings.json` | rw | always (temp copy) |
| `~/.claude/.credentials.json` | `/home/user/.claude/.credentials.json` | rw | always |
| `~/.claude.json` | `/home/user/.claude.json` | rw | always |
| `~/.config/git/` | `/home/user/.config/git/` | ro | if exists |
| `~/.codex/auth.json` | `/home/user/.config/codex/auth.json` | rw | if exists |
| SSH agent socket | `/tmp/ssh-agent.sock` | — | Linux: bind; macOS: reverse tunnel |
| `~/.ssh/config` | `/home/user/.ssh/config` | ro | filtered for Linux compat |
| `~/.config/playwright/states/<site>.json` | same path | ro | per `--auth` flag |
| todoist config | `/home/user/.config/todoist/config.json` | ro | if exists AND cwd is `~/dev/projects/notes` or subdirectory |
| cc-bridge socket | `/tmp/cc-bridge.sock` | rw | if `--bridge` |
| session dir | `~/.claude/projects/$CONTAINER_KEY/` | rw | always |

### Environment Variables Forwarded

| Variable | Value/Source | Purpose |
|----------|-------------|---------|
| CC_SANDBOX | `1` (baked in image via `ENV`, not forwarded by launcher) | Triggers container-aware prompts in cl wrapper |
| CC_HOST_PWD | `$PWD` (host) | Original path for cl wrapper |
| CC_NOTIFY_HOST | `host.containers.internal` | cc-notify daemon reachable via host gateway |
| CC_NOTIFY_PORT | from port file | cc-notify daemon port |
| CODEX_HOME | `/home/user/.config/codex` | Codex config location |
| GITHUB_TOKEN | from `$GH_AGENTS_RO` | Read-only GitHub token |
| SSH_AUTH_SOCK | `/tmp/ssh-agent.sock` | Forwarded agent |
| TERM, COLORTERM | from host | Terminal config |

### cc-bridge CLI (`oven/bin/cc-bridge.ts`)

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

### Containerfile (`home/.local/share/cc-sandbox/Containerfile`)

Multi-stage build:
1. **todoist-build** — Go build of custom todoist fork (`codethread/todoist`, branch `codethread`)
2. **Final stage** — node:22-slim + system deps + tool installation + PersonalConfigs integration

Tool installation order: system packages → neovim → bun → claude binary → yt-dlp → todoist → playwright-cli → codex → gh → nushell.

PersonalConfigs integration:
1. Copy `oven/`, run `bun install` (dependency layer cache)
2. Copy full repo, `git init` (fresh, no history)
3. `dotty link --no-cache` (creates ~/.claude symlinks for agents/commands/skills/rules)
4. `bun run build` in oven/ (compiles hooks + tools to ~/.local/bin/)
5. `nvim --headless "+Lazy! install" +qa` (pre-install neovim plugins)

Container environment: `PLAYWRIGHT_MCP_EXECUTABLE_PATH=/usr/bin/chromium` (prevents .playwright/cli.config.json leaking to host bind mount), `CC_SANDBOX=1`, `EDITOR=nvim`, `NVIM_APPNAME=minimal-nvim`.

### Podman Execution Flags

- `--userns=keep-id` — UID remapping (non-root)
- `--shm-size=2g` — shared memory for Chromium
- `--security-opt seccomp=unconfined` — required for Chromium
- `--add-host=host.containers.internal:host-gateway` — host reachability
- Container name: `cc-sandbox-<4-byte-random-hex>`
- Signal handlers clean up temp files, SSH tunnels, bridge daemons on exit

### SSH Agent Forwarding

**Linux:** Direct bind-mount of `$SSH_AUTH_SOCK` into container.

**macOS:** Podman runs in a VM (virtiofs), so direct socket mount doesn't work. Instead:
1. Background: `podman machine ssh -R $VM_SOCK:$SSH_AUTH_SOCK -N`
2. Set socket permissions to 777 inside VM
3. Container binds the VM-side socket

Filtered SSH config: macOS-only directives (`usekeychain`) stripped before mounting.

## 5. Design Decisions

- **Podman over Docker.** Rootless by default, UID remapping via `--userns=keep-id`, no daemon required. Aligns with NixOS packaging.

- **Whitelist-based .containerignore.** Starts with `**` (ignore all), then whitelists `claude/`, `config/`, `home/`, `oven/`. Prevents accidental inclusion of large/sensitive directories (nix/, .git/, node_modules/).

- **Fresh git init in container.** `git init && git add .` instead of mounting the real `.git/`. Dotty requires a git repo (for .gitignore awareness), but full history is unnecessary and adds image size.

- **Dependency-first layer caching.** `oven/` is copied and `bun install` runs before the full repo copy. Changing non-oven files doesn't invalidate the dependency layer.

- **PLAYWRIGHT_MCP_EXECUTABLE_PATH hardcoded.** Without this, playwright-cli generates `.playwright/cli.config.json` in the project directory, which leaks into the host via the bind mount. Setting the env var bypasses this file generation.

- **cc-bridge allowlist model.** The bridge daemon only executes commands explicitly listed via `--allow`. This prevents arbitrary host command execution from within the container. Commands are typically things like `obsidian` (open files) — not interactive tools.

- **Session key translation.** Host paths contain absolute paths (e.g., `/home/codethread/dev/myproject`), but the container sees `/vm/myproject`. Mapping between keys lets session history persist across container restarts while paths remain valid in each context.

## 6. Testing

**Smoke test (`cc-sandbox-smoke`):**
- Runs inside container via `cc-sandbox -r "nu -c 'cc-sandbox-smoke [flags]'"`
- Local checks: binary existence (claude, codex, playwright-cli, bun, nu), versions, PATH (includes ~/.local/bin, ~/.bun/bin), CODEX_HOME set, settings.json mounted, codex config linked, project under /vm/, neovim plugins loaded
- Model checks (`--with-models`): headless Claude ping (haiku, 30s timeout), headless Codex exec (read-only sandbox, 30s timeout)
- Output: formatted table with check/ok/detail columns
- Full invocation from host: `nu -I ~/PersonalConfigs/config/nushell/scripts -c 'use ct/interactive/claude.nu *; cc-sandbox-smoke --stream --no-cache --with-models'`

**No unit tests for:** cc-sandbox launcher script, Containerfile. Verified via smoke test and manual usage.

**cc-bridge:** Unit tests in `oven/tests/cc-bridge.test.ts`.

## 7. Open Questions

- Chromium version is pinned to whatever Debian ships in `node:22-slim`. May need explicit version pinning if playwright-cli requires a specific Chromium version.
- yt-dlp and todoist are niche tools bundled into the image. Could be moved to a separate "extras" layer or made optional build args.
