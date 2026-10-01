---
paths:
    - "nix/**/*"
---

# Nix Configuration (Agent instructions via CLAUDE.md)

Architecture and design rationale are in [SPEC-006 nix-infra](devflow/specs/nix-infra.md). This file covers operational how-tos.

## Dual Channel Pattern

Two nixpkgs channels: `pkgs` (unstable) and `pkgsMaster` (bleeding edge). In `common.nix`, `agentPkgSet` resolves to `pkgsMaster` when available. Use `agentPkgSet.*` for fast-moving supporting packages from nixpkgs-master. On Darwin, the nix-darwin Homebrew module is disabled: `boot.sh` installs Homebrew and mise, and mise owns host packages (`.mise/conf.d/packages.toml` plus `mise.{dev,work,personal,work-boot}.toml`), while Claude, Cursor, and Pi come from `llm-agents`.

## Adding a New Package

1. **Check nixpkgs first**: `nix search nixpkgs <name>` or `nix eval 'nixpkgs#<attr>'`
2. If it is an agent CLI already provided by `llm-agents.nix` — add `agentPkgSet."llm-agents".<name>` in `features/common.nix`
3. If it exists in nixpkgs — add to `features/common.nix` directly
4. If it is a Homebrew formula or cask — do **not** add it to Nix; add it to `.mise/conf.d/packages.toml` or the relevant profile overlay and apply with `mise -E <profile> run packages:apply`
5. Otherwise — create an overlay (see below)

## Adding an Overlay

1. Add a `flake = false` input in `flake.nix` inputs
2. Add the input name to the `outputs` function args
3. Define the overlay in the `let` block using the appropriate builder
4. Add to all overlay lists: `{ nixpkgs.overlays = [ ... newOverlay ]; }`
5. Reference the package in `features/common.nix`

### Hash Discovery

Use an empty string `""` for the initial hash (`vendorHash`, `npmDepsHash`, etc.). Build will fail and print the correct hash — copy it in.

### Common buildNpmPackage Flags

- `dontNpmBuild = true` — package has no build script
- `env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"` — skip postinstall browser downloads

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
