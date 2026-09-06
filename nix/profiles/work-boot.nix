{ pkgs, ... }:

# Work boot profile: enough shared dev tooling to install private workfiles.
# Used by: darwinConfigurations.work-boot and work-adamhall-boot

{
  imports = [
    ../features/common.nix
  ];

  home.packages = with pkgs; [
    glab
  ];
}
