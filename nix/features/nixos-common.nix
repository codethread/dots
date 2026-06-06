{ pkgs, lib, config, ... }:

{
  home.activation.bootDotfiles = lib.hm.dag.entryAfter [ "installPackages" ] ''
    DOTFILES="''${DOTFILES:-$HOME/dev/dots}"
    if [ ! -d "$DOTFILES" ]; then
      echo ">>> Cloning dots..."
      mkdir -p "$(${pkgs.coreutils}/bin/dirname "$DOTFILES")"
      ${pkgs.git}/bin/git clone --branch main \
        https://github.com/codethread/dots.git "$DOTFILES"
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

}
