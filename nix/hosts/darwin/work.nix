{ config, ... }:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
in
{
  imports = [ ./common-work.nix ];

  system.primaryUser = "adam.hall";

  codethread.gitMaintenance.repositories = [
    "${homeDir}/pb/app/deals-light-ui"
  ];
}
