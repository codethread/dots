{
  pkgs,
  config,
  lib,
  ...
}:

let
  graphEasy = pkgs.perlPackages.buildPerlPackage {
    pname = "Graph-Easy";
    version = "0.76";
    src = pkgs.fetchurl {
      url = "mirror://cpan/authors/id/S/SH/SHLOMIF/Graph-Easy-0.76.tar.gz";
      hash = "sha256-1KLBCuvvZjtZjqN/OqPjt1Ks8fu7lhIyw9vhFVAI0fo=";
    };
    propagatedBuildInputs = with pkgs.perlPackages; [
      Graph
    ];
    meta.mainProgram = "graph-easy";
  };

  homeDir = config.users.users.${config.system.primaryUser}.home;
  nixUserBin = "/etc/profiles/per-user/${config.system.primaryUser}/bin";
  syncengineStateDir = "${homeDir}/.local/state/com.codethread.syncengine";
  guiPath = lib.concatStringsSep ":" [
    "${homeDir}/.local/bin"
    "${homeDir}/.local/share/cargo/bin"
    "${homeDir}/.volta/bin"
    "${homeDir}/.bun/bin"
    "${homeDir}/.local/share/nvim/mason/bin"
    nixUserBin
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/opt/podman/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
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

  # Make xterm-kitty/tmux-256color terminfo available to nix-darwin activation
  # and sudo contexts while keeping kitty's native TERM=xterm-kitty.
  # enableAllTerminfo pulls in termite which fails to build on current Apple SDK.
  environment.systemPackages = with pkgs; [
    agent-browser
    kitty.terminfo # xterm-kitty
    ncurses # tmux-256color
    pngpaste
    volta
    yazi
    bitwarden-cli
    graphEasy
    flock
  ];

  fonts.packages = with pkgs; [
    fira-code
    victor-mono
    nerd-fonts.symbols-only
  ];

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

  # --- Shell ---
  # Register the Nix-managed Zsh as a valid login shell.
  environment.shells = [ pkgs.zsh ];

  launchd.user.agents.syncengine = {
    serviceConfig = {
      Label = "com.codethread.syncengine";
      ProgramArguments = [ "${homeDir}/.local/bin/syncengine" ];
      RunAtLoad = true;
      StandardOutPath = "${syncengineStateDir}/std.log";
      StandardErrorPath = "${syncengineStateDir}/std.log";
      EnvironmentVariables = {
        PATH = guiPath;
      };
    };
  };

  system.activationScripts.postActivation.text = lib.mkBefore ''
    /usr/bin/install -d -o ${config.system.primaryUser} -g staff ${syncengineStateDir}

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
