{
  boot ? false,
}:
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  environment.systemPackages = lib.optionals (!boot) (
    with pkgs;
    [
      pandoc
      jira-cli-go
    ]
  );

  system.activationScripts.workBootMessage = lib.mkIf boot {
    text = ''
      home="/Users/${config.system.primaryUser}"

      echo ">>> Work boot profile installed."
      echo ">>> Next: install/clone workfiles at $home/pb/adam.hall/workfiles"
      echo ">>> Then update nix/flake.nix so #work uses primaryUser '${config.system.primaryUser}', commit it, and run: make system work"
    '';
  };
}
