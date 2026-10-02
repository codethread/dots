{ config, ... }:

{
  nix.settings = {
    experimental-features = "nix-command flakes";
    accept-flake-config = true;
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
    # Without this, flake-declared caches (exactly the extra-trusted-public-keys
    # above) are ignored with "not a trusted user" on every user-run nix command,
    # since restricted settings need a trusted user to take effect. Root is
    # trusted by default; the list merges with that default.
    trusted-users = [ config.system.primaryUser ];
  };
  nixpkgs.config.allowUnfree = true;

  # User CLI packages, JVM tooling, fonts, and macOS user defaults are owned by mise.

  # macOS supplies /bin/zsh; dotfiles own startup and mise owns its cache.
  # nix-darwin enables Zsh by default, installing a second binary and global
  # startup files.
  programs.zsh.enable = false;

  # Homebrew packages are owned by mise (.mise/conf.d/packages.toml and overlays).
  # Leave nix-darwin Homebrew disabled: its Bundle cleanup must not remove them.

  # Touch ID for sudo, including inside tmux and screen.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  system.stateVersion = 5;
}
