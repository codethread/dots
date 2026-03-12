{ pkgs, ... }:

{
  imports = [ ../common.nix ];

  system.primaryUser = "adam.hall";

  users.users."adam.hall" = {
    home = "/Users/adam.hall";
    shell = pkgs.nushell;
  };

  homebrew.casks = [
    "figma"
    "firefox@developer-edition"
    "licecap"
    "logseq"
    "obs"
    "proxyman"
  ];

  homebrew.vscode = [
    "rohit-gohri.format-code-action"
    "golang.go"
    "styled-components.vscode-styled-components"
    "stylelint.vscode-stylelint"
  ];
}
