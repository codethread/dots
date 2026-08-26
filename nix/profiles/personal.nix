{
  pkgs,
  pkgsMaster ? pkgs,
  config,
  ...
}:

# Lightweight personal laptop profile: terminal, shell, ssh/git, and small CLI basics.
let
  llmAgents = pkgsMaster."llm-agents";
in
{
  imports = [
    ../features/darwin-common.nix
    ../features/pi.nix
  ];

  home.stateVersion = "24.11";

  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  home.packages = with pkgs; [
    llmAgents.claude-code
    llmAgents.codex
    nushell
    openssh
    git
    gh
    neovim
    tmux
    atuin
    starship
    vivid
    fzf
    fd
    ripgrep
    jq
    tree
    lazygit
  ];
}
