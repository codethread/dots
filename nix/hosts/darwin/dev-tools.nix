{ pkgs, ... }:

let
  graphEasy = pkgs.perlPackages.buildPerlPackage {
    pname = "Graph-Easy";
    version = "0.76";
    src = pkgs.fetchurl {
      url = "mirror://cpan/authors/id/S/SH/SHLOMIF/Graph-Easy-0.76.tar.gz";
      hash = "sha256-1KLBCuvvZjtZjqN/OqPjt1Ks8fu7lhIyw9vhFVAI0fo=";
    };
    propagatedBuildInputs = with pkgs.perlPackages; [
      Graph
    ];
    meta.mainProgram = "graph-easy";
  };
in
{
  imports = [ ./common.nix ];

  environment.systemPackages = with pkgs; [
    clojure
    clj-kondo
    graphEasy
    jdk
    flock
  ];

  environment.variables.JAVA_HOME = "${pkgs.jdk.home}";

  homebrew.brews = [
    "imagemagick" # image maker
  ];

  homebrew.casks = [
    "1password-cli" # Command-line interface for 1Password
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
    # "github.copilot-chat"
  ];
}
