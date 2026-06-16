{ pkgs, lib, ... }:

{
  # --- Hyprland (Wayland compositor) ---
  programs.hyprland = {
    enable = true;
    withUWSM = true; # recommended: proper session env/dbus setup via uwsm
  };

  # Display manager — tuigreet runs as system 'greeter' user (auto-created by greetd)
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${lib.getExe pkgs.tuigreet} --time --cmd 'uwsm start hyprland-uwsm.desktop'";
      user = "greeter";
    };
  };

  # --- Fonts (matches kitty.conf: Victor Mono + Nerd Symbols + darwin cask list) ---
  fonts.packages = with pkgs; [
    victor-mono
    nerd-fonts.symbols-only
    fira-code
  ];

  # --- Desktop packages ---
  environment.systemPackages = with pkgs; [
    kitty # terminal

    # Launcher (spotlight-like)
    rofi

    # Status bar
    waybar

    # Wallpaper (solid rose pine background)
    swaybg

    # Notifications
    mako

    # Theme
    rose-pine-gtk-theme
    rose-pine-icon-theme

    # Wayland utils
    wl-clipboard
    grim # screenshot
    slurp # screen area selector
  ];

  # Propagate GTK theme into sessions
  environment.sessionVariables = {
    GTK_THEME = "rose-pine-moon";
    # wlroots: no hardware cursor plane (safe for all NixOS hosts including bare metal)
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  # Required for Home Manager dconf.settings to work
  programs.dconf.enable = true;

  # Portal: lets apps query dark-mode preference via xdg-desktop-portal
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
