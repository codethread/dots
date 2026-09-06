{
  pkgs,
  lib,
  config,
  ...
}:

let
  dirname = lib.getExe' pkgs.coreutils "dirname";
  git = lib.getExe pkgs.git;
  tmux = lib.getExe pkgs.tmux;
in
{
  home.activation.bootDotfiles = lib.hm.dag.entryAfter [ "installPackages" ] ''
    DOTFILES="''${DOTFILES:-$HOME/dev/dots}"
    if [ ! -d "$DOTFILES" ]; then
      echo ">>> Cloning dots..."
      mkdir -p "$(${dirname} "$DOTFILES")"
      ${git} clone --branch main \
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
    colorScheme = "dark";
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
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

  systemd.user.services.tmux-main =
    let
      script = pkgs.writeShellScript "tmux-ensure-main" ''
        if ! ${tmux} has-session -t main 2>/dev/null; then
          ${tmux} new-session -d -s main
        fi
      '';
    in
    {
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
