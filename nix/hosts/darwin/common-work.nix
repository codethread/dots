{ pkgs, ... }:

{
  imports = [
    ./dev-tools.nix
    ../../services/darwin-cc-notify.nix
  ];

  environment.systemPackages = with pkgs; [
    pandoc
    jira-cli-go
  ];

  homebrew.taps = [
    {
      name = "codethread/millstrand";
      clone_target = "https://github.com/codethread/millstrand";
      trusted = true;
    }
  ];

  homebrew.brews = [
    "cocoapods" # Dependency manager for Cocoa projects
    "beads"
    "codethread/millstrand/millstrand" # GOAT
  ];

  homebrew.casks = [
    "figma" # Collaborative team software
    "licecap" # Animated screen capture application
    "logseq" # Privacy-first, open-source platform for knowledge sharing and management
    "obs" # Open-source software for live streaming and screen recording
    "proxyman" # HTTP debugging proxy
  ];

  homebrew.vscode = [
    "rohit-gohri.format-code-action"
    "golang.go"
    "styled-components.vscode-styled-components"
    "stylelint.vscode-stylelint"
  ];
}
