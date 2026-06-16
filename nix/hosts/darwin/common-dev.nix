{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  environment.systemPackages = [ pkgs.nativeNpmOpenspec ];

  system.activationScripts.nativeOpenspecCli.text = ''
    home="/Users/${config.system.primaryUser}"

    echo ">>> Syncing OpenSpec CLI"
    if ! /usr/bin/sudo -u ${config.system.primaryUser} /usr/bin/env \
      HOME="$home" \
      NPM_CONFIG_PREFIX="$home/.local" \
      ${lib.getExe' pkgs.nativeNpmInstallOpenspec "native-npm-install-openspec"} --if-missing; then
      echo ">>> WARN: failed to sync OpenSpec CLI; continuing"
    fi
  '';

  homebrew.casks = [
    "1password-cli" # Command-line interface for 1Password
    "google-chrome" # Web browser
    "ungoogled-chromium" # Google Chromium, sans integration with Google
    "visual-studio-code" # Open-source code editor
    "zed" # Multiplayer code editor
  ];

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
