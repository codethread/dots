{ pkgs, ... }:

{
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
