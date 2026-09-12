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

  homebrew.brews = [
    "cocoapods" # Dependency manager for Cocoa projects
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
