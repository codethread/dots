{ config, pkgs, lib, ... }:

{
  imports = [ ./common-dev.nix ];

  users.users.${config.system.primaryUser} = {
    home = "/Users/${config.system.primaryUser}";
    shell = pkgs.nushell;
  };

  system.activationScripts.nativeBitwardenCli.text = ''
    home="/Users/${config.system.primaryUser}"

    echo ">>> Syncing Bitwarden CLI"
    if ! /usr/bin/sudo -u ${config.system.primaryUser} /usr/bin/env \
      HOME="$home" \
      NPM_CONFIG_PREFIX="$home/.local" \
      ${lib.getExe pkgs.nativeAgentInstallBitwarden} --if-missing; then
      echo ">>> WARN: failed to sync Bitwarden CLI; continuing"
    fi
  '';

  environment.systemPackages = [ pkgs.pandoc ];

  homebrew.brews = [
    "cocoapods"    # Dependency manager for Cocoa projects
    "jira-cli"     # Feature-rich interactive Jira CLI
  ];

  homebrew.casks = [
    "figma"      # Collaborative team software
    "licecap"    # Animated screen capture application
    "logseq"     # Privacy-first, open-source platform for knowledge sharing and management
    "obs"        # Open-source software for live streaming and screen recording
    "proxyman"   # HTTP debugging proxy
  ];

  homebrew.vscode = [
    "rohit-gohri.format-code-action"
    "golang.go"
    "styled-components.vscode-styled-components"
    "stylelint.vscode-stylelint"
  ];
}
