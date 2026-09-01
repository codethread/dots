{ config, ... }:

{
  imports = [ ./common.nix ];

  system.activationScripts.workBootMessage.text = ''
    home="/Users/${config.system.primaryUser}"

    echo ">>> Work boot profile installed."
    echo ">>> Next: install/clone workfiles at $home/pb/adam.hall/workfiles"
    echo ">>> Then update nix/flake.nix so #work uses primaryUser '${config.system.primaryUser}', commit it, and run: make system work"
  '';
}
