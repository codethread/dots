# Specifications

Persistent domain specifications. Organized by system area, not feature chronology.

**Rule:** specs describe intent, code describes reality. Always check the codebase before assuming a spec is fully implemented.

## Infrastructure

| Spec | Code | Purpose |
|---|---|---|
| [nix-infra.md](./nix-infra.md) | `nix/`, `boot/`, `config/nushell/scripts/ct/nix.nu`, `config/nushell/scripts/ct/nixos.nu`, `.githooks/pre-commit` | Declarative system configuration and bootstrap for macOS and NixOS machines |
