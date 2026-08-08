{
  pkgs,
  config,
  lib,
  ...
}:

let
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
  imports = [ ../../services/darwin-git-maintenance.nix ];

  nix.settings = {
    experimental-features = "nix-command flakes";
    accept-flake-config = true;
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
  nixpkgs.config.allowUnfree = true;

  # Make xterm-kitty/tmux-256color terminfo available to nix-darwin activation
  # and sudo contexts while keeping kitty's native TERM=xterm-kitty.
  # enableAllTerminfo pulls in termite which fails to build on current Apple SDK.
  environment.systemPackages = with pkgs; [
    kitty.terminfo # xterm-kitty
    ncurses # tmux-256color
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
  # Register nushell as a valid login shell.
  environment.shells = [ pkgs.nushell ];

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

  system.activationScripts.postActivation.text = ''
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

  # --- Homebrew ---
  # nix-darwin manages Homebrew for casks and App Store apps not in nixpkgs.
  # Homebrew must be pre-installed: https://brew.sh
  homebrew = {
    enable = true;
    onActivation = {
      # Keep Bundle-managed npm CLIs in the user-owned location on PATH.
      extraEnv.NPM_CONFIG_PREFIX = "${homeDir}/.local";
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall"; # remove packages not listed here (use "zap" only when stable)
    };
    taps = [
      {
        name = "nikitabobko/tap";
        trusted = true;
      } # aerospace
      {
        name = "morantron/tmux-fingers";
        trusted = true;
      } # tmux-fingers
      {
        name = "codethread/wktree";
        clone_target = "https://github.com/codethread/wktree";
        trusted = true;
      } # wktree
      {
        name = "codethread/chatty";
        clone_target = "https://github.com/codethread/Chatty.app";
        trusted = true;
      } # chatty
    ];
    brews = [
      "mas" # required for masApps to function
      "pam-reattach" # PAM module so Touch ID works inside tmux sudo prompts
      "morantron/tmux-fingers/tmux-fingers" # mouseless terminal interaction
      "codethread/wktree/wktree" # Deterministic git worktree manager
      "codethread/chatty/chatty" # Menu-bar dictation helper
      "ical-buddy" # Get events and tasks from the macOS calendar database
      "pngpaste" # Paste PNG into files
      "podman" # Container CLI on macOS; nixpkgs podman is Linux-only
      "podman-compose" # Compose wrapper for podman on macOS
      "volta" # JavaScript toolchain manager for reproducible environments
      "yazi" # Blazing fast terminal file manager written in Rust, based on async I/O
      "rsync" # Utility that provides fast incremental file transfer
      "graphviz" # provides dot for diagraph
      "node" # Runtime for user-owned global npm tools
    ];
    extraConfig = ''
      npm "@playwright/cli"
      npm "@bitwarden/cli"
    '';
    casks = [
      "kitty" # GPU-based terminal emulator
      "font-fira-code" # Fira Code font
      "font-victor-mono" # Victor Mono font
      "font-symbols-only-nerd-font" # Symbols Nerd Font (Symbols Only)
      "aerospace" # AeroSpace is an i3-like tiling window manager for macOS
      "alfred" # Application launcher and productivity software
      "spotify" # Music streaming service
      "todoist-app" # To-do list
      "obsidian" # Knowledge base that works on top of a local folder of plain text Markdown files
      "1password" # Password manager that keeps all passwords secure behind one password
      "google-chrome"
    ];
    # enable on boot load machine
    # bug requires login on every switch
    # masApps = {
    #   "DaisyDisk" = 411643860;  # Disk space analyzer
    # };
  };

  # Touch ID for sudo; requires pam-reattach brew for tmux compatibility.
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
