{ pkgs, ... }:

{
  imports = [ ../common.nix ];

  system.primaryUser = "adamhall";

  users.users.adamhall = {
    home = "/Users/adamhall";
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
