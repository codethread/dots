# Generic systemd service builder for repo-local long-running processes.
# Each call defines one service that:
#   1. Clones the repo via a home-manager activation hook (SSH-gated, graceful fallback)
#   2. Runs the command directly under systemd (no tmux wrapper)
#
# Logs: journalctl --user -u <name>
# Control: systemctl --user status/start/stop/restart <name>
{ name, gitUrl, command, extraPackages ? (_pkgs: []), devShell ? null }:

{ config, lib, pkgs, ... }:
let
  cfg = config.services.${name};
  bun = lib.getExe pkgs.bun;
  dirname = lib.getExe' pkgs.coreutils "dirname";
  mkdir = lib.getExe' pkgs.coreutils "mkdir";
  git = lib.getExe pkgs.git;
  grep = lib.getExe' pkgs.gnugrep "grep";
  openssh = lib.getExe' pkgs.openssh "ssh";
  sshKeygen = lib.getExe' pkgs.openssh "ssh-keygen";
  sshKeyscan = lib.getExe' pkgs.openssh "ssh-keyscan";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  nixCmd = lib.getExe pkgs.nix;

  cmd = builtins.replaceStrings [ "{bun}" "{dir}" ] [
    bun
    cfg.workingDirectory
  ] command;
  runtimePath = lib.concatStringsSep ":" ([
    (lib.makeBinPath ([
      pkgs.bash
      pkgs.bun
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.gnumake
      pkgs.gnugrep
      pkgs.gnused
      pkgs.nix
    ] ++ (extraPackages pkgs)))
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.bun/bin"
    "${config.home.homeDirectory}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
    "/nix/var/nix/profiles/default/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/nix/profile/bin"
  ]);
  commandRunner = pkgs.writeShellScript "${name}-command" ''
    set -euo pipefail
    ${if devShell == null
      then "export PATH='${runtimePath}':\"$PATH\""
      else "export PATH=\"$PATH:${runtimePath}\""}
    cd '${cfg.workingDirectory}'
    exec ${cmd}
  '';
  serviceRunner =
    if devShell == null
    then commandRunner
    else pkgs.writeShellScript "${name}-run" ''
      set -euo pipefail
      export PATH='${runtimePath}':"$PATH"
      cd '${cfg.workingDirectory}'
      exec ${nixCmd} --extra-experimental-features 'nix-command flakes' \
        develop '${cfg.workingDirectory}#${devShell}' \
        --command '${commandRunner}'
    '';
in {
  options.services.${name} = {
    enable = lib.mkEnableOption "managed service: ${name}";
    workingDirectory = lib.mkOption {
      type = lib.types.str;
      description = "Local checkout path for ${name}";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation."clone-${name}" = lib.hm.dag.entryAfter [ "installPackages" ] ''
      if [ -d "${cfg.workingDirectory}/.git" ]; then
        $VERBOSE_ECHO ">>> ${name}: repo already present"
      elif ${openssh} -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | ${grep} -q "successfully authenticated"; then
        ${mkdir} -p "$(${dirname} "${cfg.workingDirectory}")"
        if ! ${sshKeygen} -F github.com >/dev/null 2>&1; then
          ${sshKeyscan} github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
        fi
        echo ">>> Cloning ${name}..."
        if ! ${git} clone "${gitUrl}" "${cfg.workingDirectory}"; then
          echo ">>> WARN: failed to clone ${name}; continuing"
        fi
      else
        echo ">>> Skipping ${name} clone (no SSH auth to GitHub)"
      fi
    '';

    home.activation."restart-${name}" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -n "''${DRY_RUN:-}" ]; then
        echo "Would restart ${name}.service"
      elif ${systemctl} --user --quiet is-enabled "${name}.service" 2>/dev/null; then
        echo ">>> Restarting ${name}.service"
        ${systemctl} --user restart "${name}.service" || true
      fi
    '';

    systemd.user.services."${name}" = {
      Unit = {
        Description = "Service: ${name}";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = serviceRunner;
        WorkingDirectory = cfg.workingDirectory;
        Restart = "on-failure";
        RestartSec = "5s";
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
