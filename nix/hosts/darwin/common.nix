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
  nix.settings = {
    experimental-features = "nix-command flakes";
    accept-flake-config = true;
  };
  nixpkgs.config.allowUnfree = true;

  # Make xterm-kitty/tmux-256color terminfo available to nix-darwin activation
  # and sudo contexts while keeping kitty's native TERM=xterm-kitty.
  environment.enableAllTerminfo = true;

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
      "pngpaste"
      "volta"
	  "yazi"
	  "rsync"
    ];
    casks = [
      "aerospace"
      "obsidian"
      "1password"
      "1password-cli"
      "alfred"
      "google-chrome"
	  "ungoogled-chromium"
      "kitty"
      "visual-studio-code"
      "ghostty"
      "spotify"
      "todoist-app"
      "font-fira-code"
      "font-victor-mono"
      "font-symbols-only-nerd-font"
    ];
	# enable on boot load machine
	# bug requires login on every switch
    # masApps = {
    #   "DaisyDisk" = 411643860;
    #   "Spokenly" = 6740315592;
    # };
    # shared extensions (work-specific ones live in hosts/darwin/work/)
    vscode = [
      # vim
      "cunbidun.flash-vscode"
      "haphazarddev.oil-code"
      "vscodevim.vim"

      # linting
      "dbaeumer.vscode-eslint"
      "esbenp.prettier-vscode"
      "biomejs.biome"

      # quality of life
      "davidsanders.search-under-cursor"
      "usernamehw.commands"
      "wraith13.unsaved-files-vscode"
      "formulahendry.auto-close-tag"
      "formulahendry.auto-rename-tag"

      # theme and ui
      "mvllow.rose-pine"
      "jgclark.vscode-todo-highlight"
      "kamikillerto.vscode-colorize"

      # lang
      "rust-lang.rust-analyzer"
      "bradlc.vscode-tailwindcss"

      # tools
      "wakatime.vscode-wakatime"
      "ms-playwright.playwright"
      "github.copilot-chat"
    ];
  };

  # Touch ID for sudo; requires pam-reattach brew for tmux compatibility.
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
