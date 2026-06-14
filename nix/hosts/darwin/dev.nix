{ pkgs, config, lib, ... }:

let
  homeDir = "/Users/${config.system.primaryUser}";
  git = lib.getExe pkgs.git;
  date = lib.getExe' pkgs.coreutils "date";
  backupNotesStateDir = "${homeDir}/.local/state/com.codethread.backup-notes";
  backupNotesScript = pkgs.writeShellScript "backup-notes" ''
    set -euo pipefail

    cd "${homeDir}/dev/projects/notes/vault"

    ${git} add -A
    if ! ${git} diff --cached --quiet; then
      ${git} commit -m "auto: $(${date} -u +%Y-%m-%dT%H:%M:%SZ)"
    fi

    ${git} pull --rebase
    ${git} push
  '';
in {
  imports = [ ./common-dev.nix ];

  system.primaryUser = "ct";

  users.users.ct = {
    home = "/Users/ct";
    shell = pkgs.nushell;
  };

  services.openssh = {
    enable = true;
    extraConfig = ''
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      AllowUsers ct
    '';
  };

  launchd.user.agents.backup-notes = {
    serviceConfig = {
      Label = "com.codethread.backup-notes";
      ProgramArguments = [ "${backupNotesScript}" ];
      RunAtLoad = true;
      StartInterval = 900;
      StandardOutPath = "${backupNotesStateDir}/std.log";
      StandardErrorPath = "${backupNotesStateDir}/std.log";
    };
  };

  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -o ${config.system.primaryUser} -g staff ${backupNotesStateDir}
  '';

  homebrew.casks = [
    "aerospace"             # AeroSpace is an i3-like tiling window manager for macOS
    "obsidian"              # Knowledge base that works on top of a local folder of plain text Markdown files
    "1password"             # Password manager that keeps all passwords secure behind one password
    "1password-cli"         # Command-line interface for 1Password
    "alfred"                # Application launcher and productivity software
    "google-chrome"         # Web browser
    "ungoogled-chromium"    # Google Chromium, sans integration with Google
    "visual-studio-code"    # Open-source code editor
    "ghostty"               # Terminal emulator that uses platform-native UI and GPU acceleration
    "spotify"               # Music streaming service
    "todoist-app"           # To-do list
    "zed"                   # Multiplayer code editor
    "whatsapp"              # Native desktop client for WhatsApp
    "discord"               # Voice and text chat software
  ];
}
