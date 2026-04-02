# Generic tmux-session service builder.
# Each call defines one service that clones a repo (if missing) and runs a command in a tmux session.
{ name, gitUrl, command }:

{ config, lib, pkgs, ... }:
let
  cfg = config.services.${name};
in {
  options.services.${name} = {
    enable = lib.mkEnableOption "tmux service: ${name}";
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

    systemd.user.services."tmux-${name}" = let
      cmd = builtins.replaceStrings [ "{bun}" "{dir}" ] [
        "${pkgs.bun}/bin/bun"
        cfg.workingDirectory
      ] command;
      script = pkgs.writeShellScript "tmux-ensure-${name}" ''
        if ! ${pkgs.tmux}/bin/tmux has-session -t ${name} 2>/dev/null; then
          ${pkgs.tmux}/bin/tmux new-session -d -s ${name} \
            -c "${cfg.workingDirectory}" \
            "${cmd}"
        fi
      '';
    in {
      Unit = {
        Description = "tmux session: ${name}";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${script}";
        RemainAfterExit = true;
        KillMode = "none";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
