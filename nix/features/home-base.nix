{ config, ... }:

{
  home.stateVersion = "24.11";
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
}
