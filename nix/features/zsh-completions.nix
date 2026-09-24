{
  config,
  lib,
  pkgs,
  darwinConfig ? null,
  ...
}:

let
  isDarwin = darwinConfig != null;
  cacheZsh = lib.getExe pkgs.zsh;
  incomingSystem = if isDarwin then toString darwinConfig.system.path else "/run/current-system/sw";
in
{
  home.packages = lib.optionals (!isDarwin) [ pkgs.zsh ];

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
        run ${cacheZsh} ${./zsh-completions.zsh} \
          ${lib.escapeShellArg incomingSystem}
      '';
}
