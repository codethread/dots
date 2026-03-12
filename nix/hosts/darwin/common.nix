{ pkgs, config, lib, ... }:

let
  homeDir = "/Users/${config.system.primaryUser}";
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
in {
  nix.settings.experimental-features = "nix-command flakes";
  nixpkgs.config.allowUnfree = true;

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
  # has no dedicated option.
  system.defaults.CustomUserPreferences = {
    "com.apple.universalaccess" = {
      reduceMotion = true;
    };
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
      FXPreferredViewStyle = "Flwv";
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
      "spans-displays" = true;
    };
  };

  # --- Shell ---
  # Register nushell as a valid login shell.
  environment.shells = [ pkgs.nushell ];

  launchd.user.envVariables = {
    DOTFILES = "${homeDir}/PersonalConfigs";
    EDITOR = "nvim";
    SHELL = "${pkgs.nushell}/bin/nu";
    XDG_CONFIG_HOME = "${homeDir}/.config";
    XDG_DATA_HOME = "${homeDir}/.local/share";
    XDG_STATE_HOME = "${homeDir}/.local/state";
    XDG_CACHE_HOME = "${homeDir}/.local/cache";
    ZDOTDIR = "${homeDir}/.config/zsh";
    VOLTA_HOME = "${homeDir}/.volta";
    CARGO_HOME = "${homeDir}/.local/share/cargo";
    CARGO_BIN = "${homeDir}/.local/share/cargo/bin";
    CODEX_HOME = "${homeDir}/.config/codex";
    PATH = guiPath;
  };

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
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall"; # remove packages not listed here (use "zap" only when stable)
    };
    taps = [
      "nikitabobko/tap"          # aerospace
      "morantron/tmux-fingers"
    ];
    brews = [
      "mas"           # required for masApps to function
      "pam-reattach"  # PAM module so Touch ID works inside tmux sudo prompts
      "morantron/tmux-fingers/tmux-fingers"
      "ical-buddy"
      "volta"
    ];
    casks = [
      "aerospace"
      "obsidian"
      "1password"
      "1password-cli"
      "alfred"
      "google-chrome"
      "kitty"
      "ghostty"
      "visual-studio-code"
      "cursor"
      "spotify"
      "zed"
      "ticktick"
      "todoist-app"
      "font-fira-code"
      "font-victor-mono"
      "font-symbols-only-nerd-font"
    ];
    masApps = {
      "DaisyDisk" = 411643860;
      "Magnet" = 441258766;
      "Spokenly" = 6740315592;
    };
    # shared extensions (work-specific ones live in hosts/darwin/work/)
    vscode = [
      # vim
      "cunbidun.flash-vscode"
      "haphazarddev.oil-code"
      "vscodevim.vim"
      # format
      "dbaeumer.vscode-eslint"
      "esbenp.prettier-vscode"
      # quality of life
      "davidsanders.search-under-cursor"
      "jgclark.vscode-todo-highlight"
      "kamikillerto.vscode-colorize"
      "usernamehw.commands"
      "wraith13.unsaved-files-vscode"
      "formulahendry.auto-close-tag"
      "formulahendry.auto-rename-tag"
      # theme
      "mvllow.rose-pine"
      # tools
      "wakatime.vscode-wakatime"
      "rust-lang.rust-analyzer"
      "bradlc.vscode-tailwindcss"
      "ms-playwright.playwright"
      "biomejs.biome"
    ];
  };

  # Touch ID for sudo; requires pam-reattach brew for tmux compatibility.
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
