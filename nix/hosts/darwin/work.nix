{
  boot ? false,
}:
{
  config,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  # Full-work packages (pandoc, jira-cli) are owned by mise.work.toml.
  system.activationScripts.workBootMessage = lib.mkIf boot {
    text = ''
      home="/Users/${config.system.primaryUser}"

      echo ">>> Work boot profile installed."
      echo ">>> Next: install/clone workfiles at $home/pb/adam.hall/workfiles"
      echo ">>> Then update nix/flake.nix so #work uses primaryUser '${config.system.primaryUser}', commit it, and run: make system work"
    '';
  };
}
