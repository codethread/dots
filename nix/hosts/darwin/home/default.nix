{ pkgs, ... }:

{
  imports = [ ../common.nix ];

  system.primaryUser = "ct";

  users.users.ct = {
    home = "/Users/ct";
    shell = pkgs.nushell;
  };

  homebrew.casks = [
    "whatsapp"
    "discord"
  ];
}
