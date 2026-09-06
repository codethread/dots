{ pkgs, ... }:

# Dev profile: common packages + personal extras not needed at work.
# Used by: darwinConfigurations.dev

{
  imports = [
    ../features/common.nix
  ];

  home.packages = with pkgs; [
    qmk
    dos2unix # qmk dep
    luarocks
    entr
  ];
}
