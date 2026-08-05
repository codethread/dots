{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
  ccNotifyDir = "${homeDir}/dev/projects/cc-notify";
  ccNotifyStateDir = "${homeDir}/.local/state/com.codethread.cc-notify";
  ccNotifyRunner = pkgs.writeShellScript "cc-notify-run" ''
    set -euo pipefail

    export HOME=${lib.escapeShellArg homeDir}
    cd ${lib.escapeShellArg ccNotifyDir}
    exec ${lib.getExe pkgs.bun} run src/main.ts
  '';
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
in
{
  imports = [ ./common.nix ];

  environment.systemPackages = with pkgs; [
    clojure
    graphEasy
    jdk
    flock
  ];

  environment.variables.JAVA_HOME = "${pkgs.jdk.home}";

  launchd.user.agents.cc-notify = {
    serviceConfig = {
      Label = "com.codethread.cc-notify";
      ProgramArguments = [ "${ccNotifyRunner}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${ccNotifyStateDir}/std.log";
      StandardErrorPath = "${ccNotifyStateDir}/std.log";
    };
  };

  system.activationScripts.ccNotify.text = ''
    home=${lib.escapeShellArg homeDir}
    repo=${lib.escapeShellArg ccNotifyDir}

    /usr/bin/install -d -o ${lib.escapeShellArg config.system.primaryUser} -g staff \
      ${lib.escapeShellArg ccNotifyStateDir}

    if [ -d "$repo/.git" ]; then
      echo ">>> cc-notify: repo already present"
    elif /usr/bin/sudo -u ${lib.escapeShellArg config.system.primaryUser} -H /usr/bin/env \
      HOME="$home" \
      ${lib.getExe' pkgs.openssh "ssh"} -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 \
      | ${lib.getExe' pkgs.gnugrep "grep"} -q "successfully authenticated"; then
      /usr/bin/sudo -u ${lib.escapeShellArg config.system.primaryUser} -H /usr/bin/env \
        HOME="$home" \
        ${lib.getExe pkgs.git} clone git@github.com:codethread/cc-notify.git "$repo" \
        || echo ">>> WARN: failed to clone cc-notify; continuing"
    else
      echo ">>> Skipping cc-notify clone (no SSH auth to GitHub)"
    fi

    if [ -d "$repo/.git" ]; then
      if ! /usr/bin/sudo -u ${lib.escapeShellArg config.system.primaryUser} -H /usr/bin/env \
        HOME="$home" \
        ${lib.getExe pkgs.bun} install --frozen-lockfile --cwd "$repo"; then
        echo ">>> WARN: failed to install cc-notify dependencies; continuing"
      fi
    fi
  '';

  homebrew.casks = [
    "1password-cli" # Command-line interface for 1Password
    "google-chrome" # Web browser
    "ungoogled-chromium" # Google Chromium, sans integration with Google
    "visual-studio-code" # Open-source code editor
    "zed" # Multiplayer code editor
    "codex" # Native Codex CLI; avoids inheriting Volta's npm launcher state
  ];

  # shared extensions (work-specific ones live in common-work.nix)
  homebrew.vscode = [
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
    "ms-playwright.playwright"
  ];
}
