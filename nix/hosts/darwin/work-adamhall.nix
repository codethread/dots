{ config, ... }:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
in
{
  imports = [ ./common-work.nix ];

  system.primaryUser = "adamhall";

  codethread.gitMaintenance.repositories = [
    "${homeDir}/pb/apps/deals-light-ui"
  ];
}
