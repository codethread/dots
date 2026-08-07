{ pkgs, config, ... }:

# Lightweight personal laptop profile: terminal, shell, ssh/git, and small CLI basics.
{
  imports = [
    ../features/darwin-common.nix
  ];

  home.stateVersion = "24.11";

  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  home.packages = with pkgs; [
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
