{
  config,
  lib,
  ...
}:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
in
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

  # User CLI packages, JVM tooling, and fonts are owned by mise.

  # Keyboard repeat: lower values are faster on macOS.
  system.defaults.NSGlobalDomain = {
    ApplePressAndHoldEnabled = false;
    AppleShowAllExtensions = true;
    AppleShowScrollBars = "WhenScrolling";
    InitialKeyRepeat = 12;
    KeyRepeat = 2;
    NSAutomaticWindowAnimationsEnabled = false;
    NSNavPanelExpandedStateForSaveMode = true;
  };

  # Keep macOS defaults declarative under darwin-rebuild even where nix-darwin
  # has no dedicated option. Avoid com.apple.universalaccess here: recent macOS
  # releases can reject writes to that domain during nix-darwin's defaults phase,
  # causing the whole activation to fail.
  system.defaults.CustomUserPreferences = {
    "com.apple.dock" = {
      autohide = true;
      "expose-animation-duration" = 0.0;
      "expose-group-apps" = true;
      "mru-spaces" = false;
      orientation = "left";
      "static-only" = true;
      tilesize = 50;
    };
    "com.apple.finder" = {
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowRecentTags = false;
      ShowRemovableMediaOnDesktop = true;
      ShowStatusBar = true;
      "_FXShowPosixPathInTitle" = false;
      "_FXSortFoldersFirst" = true;
    };
    "com.apple.screencapture" = {
      location = "${homeDir}/Pictures";
    };
    "com.apple.spaces" = {
      # false = each display has its own spaces (required for AeroSpace)
      "spans-displays" = false;
    };
  };

  # macOS supplies /bin/zsh; dotfiles own startup and mise owns its cache.
  # nix-darwin enables Zsh by default, installing a second binary and global
  # startup files.
  programs.zsh.enable = false;

  # syncengine is owned by mise (.mise/conf.d/syncengine.toml).
  system.activationScripts.postActivation.text = lib.mkBefore ''
    # Best-effort: this domain may be protected on some macOS versions. Keep it
    # out of system.defaults.CustomUserPreferences so a rejected write does not
    # abort the full system activation.
    if ! /bin/launchctl asuser "$(/usr/bin/id -u ${config.system.primaryUser})" \
      /usr/bin/sudo -u ${config.system.primaryUser} \
      /usr/bin/defaults write com.apple.universalaccess reduceMotion -bool true; then
      echo "warning: could not write com.apple.universalaccess reduceMotion; set it in System Settings > Accessibility > Display" >&2
    fi

    /usr/bin/killall SystemUIServer >/dev/null 2>&1 || true
    /usr/bin/killall Finder >/dev/null 2>&1 || true
    /usr/bin/killall Dock >/dev/null 2>&1 || true
  '';

  # Homebrew packages are owned by mise (.mise/conf.d/packages.toml and overlays).
  # Leave nix-darwin Homebrew disabled: its Bundle cleanup must not remove them.

  # Touch ID for sudo, including inside tmux and screen.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  system.stateVersion = 5;
}
