---
paths:
    - "nix/**/*"
---

# Nix Configuration (Agent instructions via CLAUDE.md)

Architecture and design rationale are in [SPEC-006 nix-infra](devflow/specs/nix-infra.md). This file covers operational how-tos.

## Package Ownership

Mise owns user CLI packages, runtimes, agent CLIs, and Homebrew applications:

- `config/mise/config.toml` declares global versioned tools; `.mise/conf.d/tools.toml` links the same file into the project.
- `.mise/conf.d/packages.toml` and `mise.{dev,work,personal,work-boot}.toml` declare host packages.
- `config/mise/config.{dev,work}.toml` mirrors profile-specific `[tools]` for use outside the checkout.
- Pi installs its own npm extensions from `pi/agent/settings.json`.
- `.mise/conf.d/todoist.toml` builds the pinned codethread fork.

Load the mise skill before adding packages. Use `mise -E <profile> run packages:apply`; do not add user packages or agent overlays back to Nix. The flake now uses one nixpkgs channel. Remaining Darwin system packages, defaults, login shell, and Nix-owned services stay in `nix/hosts/darwin/` until separately migrated.

## Validation

After modifying any file under `nix/`, always verify the flake builds before committing:

```bash
nix build 'path:./nix#darwinConfigurations.<host>.system' --no-link
```

A pre-commit hook in `.githooks/` enforces this automatically.

- Homebrew packages are mise-owned, not Nix-owned. After changing `.mise/conf.d/packages.toml` or a profile overlay, preview with `mise -E <profile> bootstrap packages apply --dry-run` and inspect with `mise -E <profile> run packages:status`. The old `nrs-check` brew validator was removed with Nix-owned Homebrew.
- A Nix switch does not install or upgrade Homebrew packages; upgrade formulae explicitly with `mise bootstrap packages upgrade --manager brew`.
- Always run `nix-smoke` after Nix changes — verifies environment, binaries, config symlinks, and flake evaluation.

## Build Commands

- `dev`: `darwin-rebuild switch --flake .#dev`
- `personal`: `darwin-rebuild switch --flake .#personal`
- `work` (`adamhall`): `darwin-rebuild switch --flake .#work`
- `work-boot` (`adam.hall`): `darwin-rebuild switch --flake .#work-boot`
- `work-adamhall-boot` (`adamhall`): `darwin-rebuild switch --flake .#work-adamhall-boot`
- Dry-run eval: `nix build 'path:./nix#darwinConfigurations.dev.system' --dry-run --no-link`

## Debugging

When inspecting nix config, always check `launchd` and system logs where appropriate to see if services are running as expected
