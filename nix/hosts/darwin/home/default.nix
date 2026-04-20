{ pkgs, ... }:

{
  imports = [ ../common.nix ];

  system.primaryUser = "codethread";

  users.users.codethread = {
    home = "/Users/codethread";
    shell = pkgs.nushell;
  };

  homebrew.casks = [
    "whatsapp"
    "discord"
  ];
}
