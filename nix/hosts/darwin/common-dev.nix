{ ... }:

{
  imports = [ ./common.nix ];

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
    "wakatime.vscode-wakatime"
    "ms-playwright.playwright"
    "github.copilot-chat"
  ];
}
