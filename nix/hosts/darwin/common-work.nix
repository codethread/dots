{ pkgs, ... }:

{
  imports = [
    ./millstrand.nix
  ];

  environment.systemPackages = with pkgs; [
    pandoc
    jira-cli-go
  ];
}
