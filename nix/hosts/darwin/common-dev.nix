{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  environment.systemPackages = [ pkgs.nativeNpmOpenspec ];

  system.activationScripts.nativeOpenspecCli.text = ''
    home="/Users/${config.system.primaryUser}"

    echo ">>> Syncing OpenSpec CLI"
    if ! /usr/bin/sudo -u ${config.system.primaryUser} /usr/bin/env \
      HOME="$home" \
      NPM_CONFIG_PREFIX="$home/.local" \
      ${pkgs.nativeNpmInstallOpenspec}/bin/native-npm-install-openspec --if-missing; then
      echo ">>> WARN: failed to sync OpenSpec CLI; continuing"
    fi
  '';

  # shared extensions (work-specific ones live in common-work.nix)
  homebrew.vscode = [
    # vim
    "cunbidun.flash-vscode"
    "haphazarddev.oil-code"
    "vscodevim.vim"

    # linting
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "biomejs.biome"

    # quality of life
    "davidsanders.search-under-cursor"
    "usernamehw.commands"
    "wraith13.unsaved-files-vscode"
    "formulahendry.auto-close-tag"
    "formulahendry.auto-rename-tag"

    # theme and ui
    "mvllow.rose-pine"
    "jgclark.vscode-todo-highlight"
    "kamikillerto.vscode-colorize"

    # lang
    "rust-lang.rust-analyzer"
    "bradlc.vscode-tailwindcss"

    # tools
    "ms-playwright.playwright"
  ];
}
