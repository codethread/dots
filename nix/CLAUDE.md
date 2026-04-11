# Nix Configuration (Agent instructions via CLAUDE.md)

Architecture and design rationale are in `specs/nix-infra.md`. This file covers operational how-tos.

## Dual Channel Pattern

Two nixpkgs channels: `pkgs` (unstable) and `pkgsMaster` (bleeding edge). In `common.nix`, `agentPkgSet` resolves to `pkgsMaster` when available. Use `agentPkgSet.*` for fast-moving supporting packages from nixpkgs-master. Agent CLIs (`claude-code`, `codex`, `opencode`, `pi`) come from the `llm-agents.nix` overlay via `agentPkgSet."llm-agents".*`.

## Adding a New Package

1. **Check nixpkgs first**: `nix search nixpkgs <name>` or `nix eval 'nixpkgs#<attr>'`
2. If it is an agent CLI already provided by `llm-agents.nix` — add `agentPkgSet."llm-agents".<name>` in `features/common.nix`
3. If it exists in nixpkgs — add to `features/common.nix` directly
4. If not — create an overlay (see below)

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

## Adding a Service

In the host profile (e.g. `profiles/homelab.nix`):

```nix
imports = [
  (import ../services/repo-service.nix {
    name = "my-service";
    gitUrl = "git@github.com:codethread/my-repo.git";
    command = "{bun} start";  # {bun} and {dir} are substituted automatically
    devShell = "default";     # standard: run under {dir}#default via `nix develop`
    # extraPackages = pkgs: [ pkgs.some-tool ];  # last resort only — prefer target repo's flake.nix
  })
];

services.my-service.enable = true;
services.my-service.workingDirectory = "/home/codethread/dev/projects/my-repo";
```

Logs: `journalctl --user -u my-service -f`  
Control: `systemctl --user restart my-service`  
No flake input changes needed on the dotfiles side.

**Standard pattern**: every service should use `devShell` pointing to a shell in the target repo's own `flake.nix`. This keeps runtime deps pinned alongside the code. The target repo must expose that shell (ideally with a committed `flake.lock`). Commands must start directly (no `make` / `bun install` / build pipelines).

**`extraPackages`** is a last-resort escape hatch for tools that cannot be added to the target repo's flake (e.g. the repo is not yours). Prefer putting deps in the target flake's devShell instead.

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
