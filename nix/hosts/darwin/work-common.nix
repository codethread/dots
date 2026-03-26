{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  users.users.${config.system.primaryUser} = {
    home = "/Users/${config.system.primaryUser}";
    shell = pkgs.nushell;
  };

  homebrew.brews = [
    "cocoapods"
	"jira-cli"
  ];

  homebrew.casks = [
    "figma"
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
    "anthropic.claude-code"
  ];
}
