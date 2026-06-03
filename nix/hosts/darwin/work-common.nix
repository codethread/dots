{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

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
      ${pkgs.nativeAgentInstallBitwarden}/bin/native-agent-install-bitwarden --if-missing; then
      echo ">>> WARN: failed to sync Bitwarden CLI; continuing"
    fi
  '';

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
