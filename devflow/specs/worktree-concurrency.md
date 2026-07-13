# Worktree Concurrency Specification

Document ID: SPEC-008
Configuration identification: SPEC-008; migrated from `specs/worktree-concurrency.md`; canonical path `devflow/specs/worktree-concurrency.md`.
**Status:** Planned
**Last Updated:** 2026-04-27

## [SPEC-008-S1] 1. Overview

### [SPEC-008-S1.1] Purpose

This system defines how this dotfiles repo can be tested and developed from multiple git worktrees concurrently without changing the host user's active configuration or another agent's workspace. It establishes an isolation contract around `$DOTFILES`, XDG directories, tool state directories, and application-specific entry points so a worktree can validate Neovim, Nushell, tmux, dotty, Nix helpers, and agent tooling in a disposable environment.

### [SPEC-008-S1.2] Goals

- Make every repo-local test entry point honor the current checkout/worktree as `$DOTFILES`.
- Provide a reusable sandbox harness that creates temporary `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, and `XDG_STATE_HOME` roots.
- Allow multiple agents to run tests from different git worktrees at the same time without sharing mutable caches, sockets, history, plugin installs, or generated configs.
- Support both source-from-worktree tests and link/copy-to-temp tests.
- Provide concrete smoke tests for high-risk tools: dotty, Nushell config, Neovim config, tmux sessions, and agent/CLI integration.
- Fail loudly when a test would touch the real home directory or canonical dotfiles clone unexpectedly.
- Keep full system rebuild/switch operations explicitly outside normal concurrent test runs.

### [SPEC-008-S1.3] Non-Goals

- Running multiple real `nix-darwin switch` or `nixos-rebuild switch` operations concurrently against the host.
- Proving visual correctness of terminal/editor UI beyond smoke-testable startup and command execution.
- Virtualizing OS services, launch agents, global keybindings, GUI app preferences, or package-manager state.
- Making all third-party tools perfectly hermetic if they ignore XDG or explicit state flags.
- Supporting legacy fallback paths once an isolated path contract exists.

## [SPEC-008-S2] 2. Design Decisions

- **Decision:** `$DOTFILES` is the authoritative source checkout for all worktree tests.
  - **Rationale:** The repo already uses `$DOTFILES` in dotty config, Nushell module paths, tmux sessions, Nix helpers, and Makefile commands. Enforcing it as the first-class root lets a worktree be tested without rewriting config files.

- **Decision:** Test isolation is environment-based first, symlink-based second.
  - **Rationale:** Many tools already respect `HOME` and XDG variables. A temp-home harness avoids touching the real user profile; dotty symlinks can then be tested inside that temp home when integration coverage needs the linked layout.

- **Decision:** The harness must allocate unique temp roots per invocation, not per branch name.
  - **Rationale:** Multiple agents may test the same branch, rerun concurrently, or leave failed runs behind. Unique temp dirs prevent cache and socket collisions.

- **Decision:** Worktree tests must not call bare `dotty link` against the real home.
  - **Rationale:** Dotty is designed to manage live dotfiles. Concurrent worktree validation must pass an explicit test config or run under an isolated `HOME`/XDG root so it cannot replace the user's active symlinks.

- **Decision:** Application tests should prefer native override knobs over generated config mutation.
  - **Rationale:** `nvim -u <file>`, `nu --config/--env-config`, `tmux -f <file>`, and explicit XDG env vars are clearer, easier to debug, and less likely to leak host state than rewriting configs in-place.

- **Decision:** Shared caches that influence startup behavior must be redirected, not merely cleaned afterward.
  - **Rationale:** Concurrent agents can observe each other's partial writes if they share `~/.local/share`, `~/.cache`, plugin directories, histories, tmux sockets, or compiled outputs. Isolation must happen before process start.

- **Decision:** Nix evaluation can be worktree-concurrent; activation remains host-serialized and opt-in.
  - **Rationale:** `nix flake check`, `nix build`, and `nix eval` can safely target `path:$DOTFILES/nix`. System switch commands mutate global host state and must not be part of default worktree tests.

- **Decision:** Test commands should be grouped by risk level.
  - **Rationale:** Unit/import checks can run constantly. Integration tests that launch tmux, Neovim, or agent CLIs are heavier. Host-mutating checks require explicit manual confirmation.

## [SPEC-008-S3] 3. Architecture

### [SPEC-008-S3.1] Component structure

Planned additions and modifications:

```text
home/.local/bin/
  dots-test-sandbox        New Bash harness for isolated env execution

config/nushell/scripts/ct/test/
  mod.nu                   New Nushell command surface for repo test suites

config/dotty/
  test-dotty.toml          Extend or replace with temp-target aware sandbox config

config/nvim/
  lua/codethread/...       Audit paths/state that assume real home or canonical clone

config/tmux/
  tmux.conf
  sessions.toml            Audit session paths, socket handling, and DOTFILES expansion

Makefile                   Add safe test targets that export DOTFILES=$(ROOT)
devflow/specs/worktree-concurrency.md
```

### [SPEC-008-S3.2] Data flow

```text
agent shell in worktree
  |
  | make test-worktree / ct test worktree / dots-test-sandbox <command>
  v
resolve current checkout root
  |
  | export DOTFILES=<current worktree>
  | create temp root: /tmp/dots-test.<pid>.<random>/
  | export HOME=<temp>/home
  | export XDG_*=<temp>/xdg/{config,data,cache,state}
  | export app-specific state vars
  v
run selected tool command
  |
  | source from $DOTFILES directly, OR
  | dotty link/copy into temp HOME/XDG then run app against linked config
  v
collect logs + exit code
  |
  | cleanup temp root unless --keep
  v
fail loudly on host-path writes or command failure
```

### [SPEC-008-S3.3] Isolation layers

1. **Checkout isolation** — every command receives `DOTFILES=<worktree root>` and module/config paths under that root.
2. **Home isolation** — `HOME` points at a fresh temp dir.
3. **XDG isolation** — config/data/cache/state roots point under the temp dir.
4. **Application isolation** — tools get app-specific state overrides where needed:
   - Neovim: isolated `XDG_*`, optional `NVIM_APPNAME`, no real `stdpath` writes.
   - Nushell: explicit `--config`, `--env-config`, `-I $DOTFILES/config/nushell/scripts`.
   - tmux: unique socket via `tmux -L dots-test-<id>` or `-S <temp>/tmux.sock`.
   - Bash/zsh: isolated history files and rc/config paths where possible.
   - Bun/oven: isolated cache/temp dirs when running build/test in parallel.
   - Claude/Codex/Pi: isolated config homes unless intentionally testing linked configs.
5. **Link isolation** — dotty links only into the temp `HOME`/XDG targets during tests.

## [SPEC-008-S4] 4. Data Model

### [SPEC-008-S4.1] Sandbox environment contract

| Variable | Value in sandbox | Purpose |
| --- | --- | --- |
| `DOTFILES` | Current git worktree root | Source checkout under test |
| `HOME` | `<sandbox>/home` | Prevent writes to real home |
| `XDG_CONFIG_HOME` | `<sandbox>/xdg/config` | Linked/test app config target |
| `XDG_DATA_HOME` | `<sandbox>/xdg/data` | Plugin, history, and app data target |
| `XDG_CACHE_HOME` | `<sandbox>/xdg/cache` | Cache target |
| `XDG_STATE_HOME` | `<sandbox>/xdg/state` | State/history target |
| `TMPDIR` | `<sandbox>/tmp` | Tool temp files |
| `HISTFILE` | `<sandbox>/xdg/state/bash/history` | Bash history isolation |
| `ZDOTDIR` | `<sandbox>/xdg/config/zsh` | Zsh config isolation |
| `RIPGREP_CONFIG_PATH` | `$DOTFILES/config/ripgrep/config` or linked equivalent | Avoid host ripgrep config drift |
| `NU_LIB_DIRS` | Includes `$DOTFILES/config/nushell/scripts` | Nushell module discovery |
| `TMUX_TMPDIR` / socket flag | `<sandbox>/tmux` | Prevent tmux socket collision |
| `DOTS_TEST_SANDBOX` | `<sandbox>` | Debug/cleanup anchor |

### [SPEC-008-S4.2] Test mode model

| Mode | Description | Host mutation risk |
| --- | --- | --- |
| `source` | Run tool directly against files in `$DOTFILES` using explicit config flags | Low |
| `linked` | Run `dotty link` into isolated `HOME`/XDG, then run tool as installed | Low |
| `copied` | Copy selected config subtree into temp XDG before running tool | Low |
| `host` | Real system activation or app preference changes | High; manual opt-in only |

### [SPEC-008-S4.3] Result artifacts

Each integration run should optionally persist, when `--keep` is set:

```text
<sandbox>/
  env.nuon or env.json       Captured env contract
  logs/<tool>.log            Tool stdout/stderr
  home/                      Isolated HOME after run
  xdg/                       Isolated XDG roots after run
  tmux/                      Socket/log artifacts
```

## [SPEC-008-S5] 5. Interfaces

### [SPEC-008-S5.1] Bash harness

```bash
dots-test-sandbox [--keep] [--mode source|linked|copied] [--name NAME] -- COMMAND [ARG...]
```

Behavior:

- Resolves repo root from `git rev-parse --show-toplevel` unless `DOTFILES` is already explicitly set to an existing checkout.
- Exports the sandbox environment contract.
- Creates required directories before command execution.
- Runs command with `set -euo pipefail` semantics.
- Prints the sandbox path on failure and when `--keep` is used.
- Cleans up on success unless `--keep` is set.

### [SPEC-008-S5.2] Nushell command surface

| Command | Description |
| --- | --- |
| `ct test env` | Print the resolved sandbox/worktree environment without running a tool |
| `ct test nu` | Validate Nushell config and module importability from the current worktree |
| `ct test nvim` | Start Neovim headlessly against the worktree config with isolated XDG roots |
| `ct test tmux` | Start tmux with an isolated socket/config and run a minimal session smoke |
| `ct test dotty` | Link dotfiles into isolated HOME/XDG and verify expected symlinks |
| `ct test oven` | Run `bun test`/build checks with worktree-local source and isolated caches |
| `ct test agents` | Smoke agent config loading without using live host config dirs |
| `ct test worktree` | Run the default safe suite: env, nu, dotty, nvim, tmux, oven |

### [SPEC-008-S5.3] Make targets

| Target | Description |
| --- | --- |
| `make test-worktree` | Default safe concurrent suite, exports `DOTFILES=$(ROOT)` |
| `make test-nu` | Nushell syntax/config checks only |
| `make test-nvim` | Headless Neovim startup/config checks only |
| `make test-dotty` | Isolated dotty link checks only |
| `make test-tmux` | Isolated tmux smoke only |

### [SPEC-008-S5.4] Tool-specific smoke contracts

| Tool | Minimum safe smoke |
| --- | --- |
| Nushell | `nu --config $DOTFILES/config/nushell/config.nu --env-config $DOTFILES/config/nushell/env.nu -I $DOTFILES/config/nushell/scripts -c 'print ok'` |
| Neovim | `nvim --headless -u $DOTFILES/config/nvim/init.lua '+checkhealth' '+qa'` with isolated XDG roots; lighter mode may use `'+lua print("ok")' '+qa'` |
| tmux | `tmux -S <sandbox>/tmux.sock -f $DOTFILES/config/tmux/tmux.conf new-session -d -s dots-test -c $DOTFILES` then list/kill session |
| dotty | `dotty link --no-cache $DOTFILES/config/dotty/test-dotty.toml` under sandbox HOME/XDG, then verify symlink targets stay under `$DOTFILES` |
| oven | `cd $DOTFILES/oven && bun test` with cache/temp vars redirected |
| Nix | `nix flake check path:$DOTFILES/nix` or focused `nix eval`; no switch by default |

## [SPEC-008-S6] 6. Implementation Phases

### [SPEC-008-S6.1] Phase 1: Isolation audit and harness (1 day)

- [ ] Audit repo scripts/configs for writes to `~`, canonical `$HOME/dev/dots`, global XDG paths, fixed tmux sockets, fixed plugin directories, or unguarded `dotty link`.
- [ ] Add `home/.local/bin/dots-test-sandbox` with the environment contract above.
- [ ] Add `--keep` support and clear failure output.
- [ ] Add host-path leak checks for common real-home paths in generated symlinks/logs where practical.

### [SPEC-008-S6.2] Phase 2: Safe per-tool smoke commands (1-2 days)

- [ ] Add `ct test nu` and `make test-nu`.
- [ ] Add `ct test dotty` and make `config/dotty/test-dotty.toml` target the sandbox, not real home.
- [ ] Add `ct test nvim` with isolated XDG roots and headless startup.
- [ ] Add `ct test tmux` with unique socket and cleanup.
- [ ] Add `ct test oven` with isolated cache/temp variables.

### [SPEC-008-S6.3] Phase 3: Default concurrent suite (1 day)

- [ ] Add `ct test worktree` orchestration.
- [ ] Add `make test-worktree` that exports `DOTFILES=$(ROOT)`.
- [ ] Ensure each suite command can run in parallel from two sibling git worktrees.
- [ ] Document expected runtime and failure artifact locations.

### [SPEC-008-S6.4] Phase 4: Integration hardening (ongoing)

- [ ] Add optional agent config smoke tests for Claude/Codex/Pi without live config mutation.
- [ ] Add focused Nix evaluation checks that prefer the current worktree and do not switch the host.
- [ ] Add CI-compatible or pre-commit-compatible subsets if useful.
- [ ] Add regression tests whenever a tool gains new writable state.

## [SPEC-008-S7] 7. Code Locations

| File | Change |
| --- | --- |
| `home/.local/bin/dots-test-sandbox` | New: Bash sandbox harness for isolated command execution |
| `config/nushell/scripts/ct/test/mod.nu` | New: Nushell test command module |
| `config/nushell/scripts/ct/core/mod.nu` | Modify if needed to expose test module aliases/imports |
| `config/dotty/test-dotty.toml` | Modify: make test targets sandbox-aware |
| `Makefile` | Modify: add safe worktree test targets with `DOTFILES=$(ROOT)` |
| `config/nvim/` | Modify as audit finds hard-coded state paths or non-XDG writes |
| `config/tmux/` | Modify as audit finds socket/session/path assumptions |
| `oven/package.json` / `oven/tests/` | Modify only if cache isolation or test wrappers are needed |
| `devflow/README.md` | Modify: register this spec |

## [SPEC-008-S8] 8. Open Questions

- Should the harness default to `source` mode for speed, or `linked` mode for closer-to-installed behavior?
- Should `ct test worktree` run Neovim plugin installation/update steps, or only validate startup with existing dependencies?
- Should sandbox leak detection be strict enough to fail on any absolute real-home path in logs, or only on writes/symlinks?
- Should worktree post-create hooks automatically run `make test-worktree`, or leave tests explicit to avoid expensive branch creation?
- Should Nix checks be part of the default safe suite, or a separate `make test-nix-worktree` due to runtime cost?
