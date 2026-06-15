{ pkgs, config, lib, ... }:

let
  homeDir = "/Users/${config.system.primaryUser}";
  git = lib.getExe pkgs.git;
  date = lib.getExe' pkgs.coreutils "date";
  backupNotesStateDir = "${homeDir}/.local/state/com.codethread.backup-notes";
  backupNotesScript = pkgs.writeShellScript "backup-notes" ''
    set -Eeuo pipefail

    sentinel="${backupNotesStateDir}/failure-notified"

    notify_failure() {
      local exit_code="$?"
      trap - ERR

      if [ ! -e "$sentinel" ]; then
        {
          echo "backup-notes failed with exit code $exit_code."
          echo
          echo "Repository: ${homeDir}/dev/projects/notes/vault"
          echo
          ${git} -C "${homeDir}/dev/projects/notes/vault" status --short --branch || true
        } | "${homeDir}/.local/bin/cc-notify" "Notes git backup failed" || true
        : > "$sentinel"
      fi

      exit "$exit_code"
    }

    trap notify_failure ERR

    cd "${homeDir}/dev/projects/notes/vault"

    ${git} add -A
    if ! ${git} diff --cached --quiet; then
      ${git} commit -m "auto: $(${date} -u +%Y-%m-%dT%H:%M:%SZ)"
    fi

    ${git} pull --rebase
    ${git} push

    rm -f "$sentinel"
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
    "discord"               # Voice and text chat software
  ];
}
