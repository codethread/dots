# Migration Guide: Nix Setup

Package management is handled by **Nix** (nixpkgs via home-manager).
App configs stay in this repo, managed by **dotty** as before.
Nix does not touch your neovim/tmux/kitty/nushell configs.

---

## macOS (nix-darwin)

**First time on a new Mac:**

```bash
# 1. Install Homebrew (needed for casks — nix-darwin manages it declaratively after this)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install Nix
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# 3. Enable flakes
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# 4. Clone dotfiles
git clone git@github.com:codethread/PersonalConfigs.git ~/PersonalConfigs

# 5. Apply nix-darwin (first run — installs darwin-rebuild)
cd ~/PersonalConfigs
nix run nix-darwin -- switch --flake ./nix#macbook

# 6. Link dotfiles and set up tools
make link
boot machine --skip-brew  # packages already handled by Nix
```

**Subsequent rebuilds** (after changing nix/ config):

```bash
darwin-rebuild switch --flake ~/PersonalConfigs/nix#macbook
```

**Notes:**
- Change `macbook` in `nix/flake.nix` to match your hostname (`scutil --get LocalHostName`)
- Change `aarch64-darwin` to `x86_64-darwin` if on an Intel Mac
- Homebrew is still used for casks (aerospace, kitty, obsidian, etc.) — nix-darwin manages it declaratively

---

## NixOS (Linux)

**Installing NixOS on a machine:**

1. Download [NixOS ISO](https://nixos.org/download) — use the graphical installer
2. Boot from USB, choose **Erase disk** (or install alongside if dual-booting)
3. Complete install, reboot into NixOS

**First boot after NixOS install:**

```bash
# Clone dotfiles
git clone git@github.com:codethread/PersonalConfigs.git ~/PersonalConfigs
cd ~/PersonalConfigs

# Generate machine-specific hardware config
nixos-generate-config --show-hardware-config > nix/hosts/homelab/hardware-configuration.nix

# Apply NixOS config (installs nushell + all packages)
sudo nixos-rebuild switch --flake ./nix#homelab

# Open a new shell (nushell is now default)
# Link dotfiles and set up tools
make link
boot machine --skip-brew  # packages handled by Nix, brew skipped automatically
```

**Subsequent rebuilds:**

```bash
sudo nixos-rebuild switch --flake ~/PersonalConfigs/nix#homelab
```

**Notes:**
- `hardware-configuration.nix` is machine-specific but should be committed — `boot.sh` handles this automatically after dotfiles are linked
- `x86_64-linux` in `flake.nix` — change to `aarch64-linux` for ARM machines

---

## Package management

| Layer | Tool | What it handles |
|-------|------|-----------------|
| Cross-platform CLI | nixpkgs (home-manager) | go, rust, neovim, tmux, fzf, etc. |
| macOS GUI apps | Homebrew casks (via nix-darwin) | kitty, obsidian, aerospace, etc. |
| Linux GUI apps | nixpkgs | kitty, obsidian, discord, spotify |
| App configs | dotty | Everything in config/ — unchanged |
| CLI tools (custom) | bun (oven/) | Built with `make build` |

## Updating packages

Edit `nix/modules/home.nix` (shared) or `nix/hosts/darwin/default.nix` (macOS casks), then rebuild.

Packages with TODOs in home.nix may not be in nixpkgs yet — check [search.nixos.org](https://search.nixos.org/packages) and add an overlay or install manually if missing.

---

## What stays the same

- All configs in `config/` — managed by dotty, untouched by Nix
- All nushell scripts in `config/nushell/scripts/ct/`
- All `home/.local/bin/` bash scripts
- `oven/` TypeScript tools — still built with `bun run build` (bun installed by Nix)
- `boot machine` command — still works, auto-skips brew on NixOS
