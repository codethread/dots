# Specifications

Persistent domain specifications. Organized by system area, not feature chronology.

**Rule:** specs describe intent, code describes reality. Always check the codebase before assuming a spec is fully implemented.

## Agentic

| Spec | Code | Purpose |
|---|---|---|
| [agentic-config.md](./agentic-config.md) | `nix/features/claude-code.nix`, `claude/`, `config/codex/`, `home/.local/bin/cl`, `oven/bin/cc-hook--*.ts`, `oven/shared/claude-hooks.ts`, `home/.local/bin/cc-hook--*` | Claude Code & Codex global configuration: settings, hooks, agents, skills, plugins, wrappers |
| [cc-sandbox.md](./cc-sandbox.md) | `home/.local/bin/cc-sandbox`, `home/.local/share/cc-sandbox/`, `oven/bin/cc-bridge.ts`, `config/nushell/scripts/ct/interactive/claude.nu` | Podman container isolation for headless Claude Code and Codex sessions |

## Infrastructure

| Spec | Code | Purpose |
|---|---|---|
| [nix-infra.md](./nix-infra.md) | `nix/`, `boot/`, `config/nushell/scripts/ct/nix.nu`, `config/nushell/scripts/ct/nixos.nu`, `.githooks/pre-commit` | Declarative system configuration and bootstrap for macOS and NixOS machines |
