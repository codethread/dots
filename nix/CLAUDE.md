# Nix Configuration (Agent instructions via CLAUDE.md)

## Flake Architecture

```
flake.nix          # Inputs, overlays, system configurations
├── hosts/         # Hardware/system-level config per machine
│   ├── darwin/    # macOS common + home/work host variants
│   └── nixos/     # NixOS hosts (homelab, vm-aarch, desktop)
├── profiles/      # User-level home-manager profiles (personal, work, homelab, vm)
└── features/      # Shared modules imported by profiles
    ├── common.nix       # Packages + settings for ALL systems
    ├── darwin-common.nix
    └── nixos-common.nix
```

## Dual Channel Pattern

Two nixpkgs channels are used:
- `nixpkgs` (unstable) — primary, referenced as `pkgs`
- `nixpkgs-master` — bleeding edge, passed as `pkgsMaster` to profiles

In `common.nix`, `agentPkgSet` resolves to `pkgsMaster` when available, falling back to `pkgs`. Use `agentPkgSet.*` for packages that need the latest nixpkgs-master. Use bare names (via `with pkgs`) for packages from overlays or stable nixpkgs.

## Overlays

Custom packages not in nixpkgs are built as overlays in `flake.nix`:
- Defined in the `let` block (e.g. `todoistOverlay`, `playwrightCliOverlay`)
- Applied to **all 4 system configs** via `{ nixpkgs.overlays = [ ... ]; }`
- Referenced in `common.nix` by attribute name (e.g. `todoist-cli`, `playwright-cli`)

Existing overlay builders:
- `buildGoModule` — Go packages (todoist-cli)
- `buildNpmPackage` — npm packages (playwright-cli)

## Adding a New Package

1. **Check nixpkgs first**: `nix search nixpkgs <name>` or `nix eval 'nixpkgs#<attr>'`
2. If it exists — add to `features/common.nix` directly
3. If not — create an overlay (see "Adding an Overlay" below)

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
nixos-rebuild build --flake 'path:./nix#<host>'
```

where `<host>` matches the current machine (e.g. `homelab`). A pre-commit hook in `.githooks/` enforces this automatically (silent on success).

After modifying `homebrew.taps`, `homebrew.brews`, or `homebrew.casks` in darwin hosts, run `nrs-check` (no sudo) to validate all packages resolve before rebuilding. This taps missing repos and checks every formula/cask exists in brew.

- Always run `nix-smoke` after making Nix changes in this subtree. It is the default health check here and verifies the local Nix-managed environment, key binaries on `PATH`, expected linked config locations, and optional flake evaluation.

- `nix-smoke`

## Build Commands

Each system config has a rebuild comment in `flake.nix`. Examples:
- macOS: `darwin-rebuild switch --flake .#home`
- macOS (work, `adam.hall`): `darwin-rebuild switch --flake .#work`
- macOS (work, `adamhall`): `darwin-rebuild switch --flake .#work-adamhall`
- NixOS: `sudo nixos-rebuild switch --flake .#homelab`
- Dry-run eval: `nix build .#nixosConfigurations.vm.config.system.build.toplevel --dry-run`
