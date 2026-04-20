{ pkgs, lib, config, ... }:

{
  home.activation.bootDotfiles = lib.hm.dag.entryAfter [ "installPackages" ] ''
    DOTFILES="$HOME/PersonalConfigs"
    if [ ! -d "$DOTFILES" ]; then
      echo ">>> Cloning PersonalConfigs..."
      ${pkgs.git}/bin/git clone --branch main \
        https://github.com/codethread/PersonalConfigs.git "$DOTFILES"
    fi
  '';

  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.local
  '';

  home.packages = with pkgs; [
    kitty
    yazi
    libnotify
  ];

  programs.rofi = {
    enable = true;
    theme = "purple";
  };

  # Dark mode: GTK
  gtk = {
    enable = true;
    theme = {
      name = "rose-pine-moon";
      package = pkgs.rose-pine-gtk-theme;
    };
    gtk4.theme = null;
    iconTheme = {
      name = "rose-pine-moon";
      package = pkgs.rose-pine-icon-theme;
    };
  };

  # Dark mode: Qt
  qt = {
    enable = true;
    style.name = "adwaita-dark";
  };

  # Dark mode: freedesktop color-scheme preference (GTK4/libadwaita/Electron apps)
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  systemd.user.services.tmux-main = let
    script = pkgs.writeShellScript "tmux-ensure-main" ''
      if ! ${pkgs.tmux}/bin/tmux has-session -t main 2>/dev/null; then
        ${pkgs.tmux}/bin/tmux new-session -d -s main
      fi
    '';
  in {
    Unit = {
      Description = "Ensure tmux session main exists";
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

  systemd.user.services.backup-notes = let
    git = "${pkgs.git}/bin/git";
    backupScript = pkgs.writeShellScript "backup-notes" ''
      set -euo pipefail
      cd $HOME/dev/projects/notes/vault
      ${git} add -A
      STASH_BEFORE=$(${git} rev-parse --verify refs/stash 2>/dev/null || echo "none")
      ${git} stash push -m "backup-notes-auto"
      STASH_AFTER=$(${git} rev-parse --verify refs/stash 2>/dev/null || echo "none")
      ${git} pull --rebase
      if [ "$STASH_BEFORE" != "$STASH_AFTER" ]; then
        ${git} stash pop
      fi
      ${git} add -A
      if ! ${git} diff --cached --quiet; then
        ${git} commit -m "auto: $(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
      fi
      ${git} push
    '';
  in {
    Unit.Description = "Git backup for notes vault";
    Service = {
      Type = "oneshot";
      ExecStart = "${backupScript}";
      ExecStopPost = "${pkgs.bash}/bin/bash -c 'if [ \"$SERVICE_RESULT\" != \"success\" ] && [ -n \"$WAYLAND_DISPLAY\" ]; then ${pkgs.libnotify}/bin/notify-send --urgency=critical \"Notes backup failed\" \"Check: journalctl --user -u backup-notes\"; fi'";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.user.timers.backup-notes = {
    Unit.Description = "Hourly git backup for notes vault";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
