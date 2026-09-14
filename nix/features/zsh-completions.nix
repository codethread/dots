{
  config,
  lib,
  pkgs,
  darwinConfig ? null,
  ...
}:

{
  # Use the same Zsh for generation and interactive startup, including on NixOS.
  home.packages = [ pkgs.zsh ];

  home.activation.zshCompletions =
    lib.hm.dag.entryAfter
      [
        "dottyLink"
        "linkGeneration"
        "installPackages"
      ]
      ''
        # nix-darwin runs Home Manager after brew bundle. The host's mkBefore
        # postActivation also finishes formula upgrades before this hook runs.
        # /run/current-system still points to the OLD generation during Darwin
        # activation, so scan the incoming system path instead.
        run ${lib.getExe pkgs.zsh} ${./zsh-completions.zsh} \
          ${lib.escapeShellArg (
            if darwinConfig == null then "/run/current-system/sw" else toString darwinConfig.system.path
          )}
      '';
}
