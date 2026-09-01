{ config, ... }:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
in
{
  imports = [ ./common-work.nix ];

  codethread.gitMaintenance.repositories = [
    "${homeDir}/pb/app/deals-light-ui"
  ];
}
