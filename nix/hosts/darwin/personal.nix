{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  system.primaryUser = "codethread";

  users.users.codethread = {
    home = "/Users/codethread";
    shell = pkgs.nushell;
  };

  homebrew.casks = [
    "whatsapp" # Native desktop client for WhatsApp
    "discord" # Voice and text chat software
  ];
}
