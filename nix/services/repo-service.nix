# Generic systemd service builder for repo-local long-running processes.
# Each call defines one service that:
#   1. Clones the repo via a home-manager activation hook (SSH-gated, graceful fallback)
#   2. Runs the command directly under systemd (no tmux wrapper)
#
# Logs: journalctl --user -u <name>
# Control: systemctl --user status/start/stop/restart <name>
{ name, gitUrl, command, extraPackages ? (_pkgs: []) }:

{ config, lib, pkgs, ... }:
let
  cfg = config.services.${name};
  cmd = builtins.replaceStrings [ "{bun}" "{dir}" ] [
    "${pkgs.bun}/bin/bun"
    cfg.workingDirectory
  ] command;
  path = lib.makeBinPath ([ pkgs.bun pkgs.gnumake pkgs.coreutils ] ++ (extraPackages pkgs));
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
      elif ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | ${pkgs.gnugrep}/bin/grep -q "successfully authenticated"; then
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "${cfg.workingDirectory}")"
        if ! ${pkgs.openssh}/bin/ssh-keygen -F github.com >/dev/null 2>&1; then
          ${pkgs.openssh}/bin/ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
        fi
        echo ">>> Cloning ${name}..."
        if ! ${pkgs.git}/bin/git clone "${gitUrl}" "${cfg.workingDirectory}"; then
          echo ">>> WARN: failed to clone ${name}; continuing"
        fi
      else
        echo ">>> Skipping ${name} clone (no SSH auth to GitHub)"
      fi
    '';

    home.activation."restart-${name}" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -n "''${DRY_RUN:-}" ]; then
        echo "Would restart ${name}.service"
      elif ${pkgs.systemd}/bin/systemctl --user --quiet is-enabled "${name}.service" 2>/dev/null; then
        echo ">>> Restarting ${name}.service"
        ${pkgs.systemd}/bin/systemctl --user restart "${name}.service" || true
      fi
    '';

    systemd.user.services."${name}" = {
      Unit = {
        Description = "Service: ${name}";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = cmd;
        WorkingDirectory = cfg.workingDirectory;
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = "PATH=${path}:$PATH";
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
