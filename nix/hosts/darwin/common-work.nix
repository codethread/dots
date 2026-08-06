{ ... }:

{
  imports = [ ./common-dev.nix ];

  users.users.${config.system.primaryUser} = {
    home = "/Users/${config.system.primaryUser}";
    shell = pkgs.nushell;
  };

  environment.systemPackages = [ pkgs.pandoc ];

  homebrew.brews = [
    "cocoapods" # Dependency manager for Cocoa projects
    "jira-cli" # Feature-rich interactive Jira CLI
    "beads"
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
