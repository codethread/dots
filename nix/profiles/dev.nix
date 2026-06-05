{ pkgs, ... }:

# Dev profile: common packages + personal extras not needed at work.
# Used by: darwinConfigurations.dev

{
  imports = [
    ../features/common.nix
    ../features/darwin-common.nix
  ];

  home.packages = with pkgs; [
    qmk
    luarocks
    entr
  ];
}
