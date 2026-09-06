{
  pkgs,
  pkgsMaster ? pkgs,
  ...
}:

# Lightweight personal laptop profile: terminal, shell, ssh/git, and small CLI basics.
let
  llmAgents = pkgsMaster."llm-agents";
in
{
  imports = [
    ../features/home-base.nix
    ../features/pi.nix
  ];

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
