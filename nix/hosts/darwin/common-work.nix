{ pkgs, ... }:

{
  imports = [
    ./dev-tools.nix
    ../../services/darwin-cc-notify.nix
  ];

  environment.systemPackages = [ pkgs.pandoc ];

  homebrew.taps = [
    {
      name = "codethread/millstrand";
      clone_target = "https://github.com/codethread/millstrand";
      trusted = true;
    }
  ];

  homebrew.brews = [
    "cocoapods" # Dependency manager for Cocoa projects
    "jira-cli" # Feature-rich interactive Jira CLI
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
