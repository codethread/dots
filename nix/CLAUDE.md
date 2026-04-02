# Nix Configuration (Agent instructions via CLAUDE.md)

Architecture and design rationale are in `specs/nix-infra.md`. This file covers operational how-tos.

## Dual Channel Pattern

Two nixpkgs channels: `pkgs` (unstable) and `pkgsMaster` (bleeding edge). In `common.nix`, `agentPkgSet` resolves to `pkgsMaster` when available. Use `agentPkgSet.*` for packages needing latest nixpkgs-master. Use bare names for overlay or stable packages.

## Adding a New Package

1. **Check nixpkgs first**: `nix search nixpkgs <name>` or `nix eval 'nixpkgs#<attr>'`
2. If it exists — add to `features/common.nix` directly
3. If not — create an overlay (see below)

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

## Adding a Tmux Service

In the host profile (e.g. `profiles/homelab.nix`):

```nix
imports = [
  (import ../services/tmux-service.nix {
    name = "my-service";
    gitUrl = "git@github.com:codethread/my-repo.git";
    command = "{bun} start";  # {bun} and {dir} are substituted automatically
  })
];

services.my-service.enable = true;
services.my-service.workingDirectory = "/home/codethread/dev/projects/my-repo";
```

No flake input changes needed. Commands must start directly (no `make` / `bun install` / build pipelines).

## Validation

After modifying any file under `nix/`, always verify the flake builds before committing:

```bash
nixos-rebuild build --flake 'path:./nix#<host>'
```

A pre-commit hook in `.githooks/` enforces this automatically.

- After modifying `homebrew.taps`, `homebrew.brews`, or `homebrew.casks`, run `nrs-check` to validate before rebuilding.
- Always run `nix-smoke` after Nix changes — verifies environment, binaries, config symlinks, and flake evaluation.

## Build Commands

- macOS: `darwin-rebuild switch --flake .#home`
- macOS (work, `adam.hall`): `darwin-rebuild switch --flake .#work`
- macOS (work, `adamhall`): `darwin-rebuild switch --flake .#work-adamhall`
- NixOS: `sudo nixos-rebuild switch --flake .#homelab`
- Dry-run eval: `nix build .#nixosConfigurations.vm.config.system.build.toplevel --dry-run`
