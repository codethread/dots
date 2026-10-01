{ pkgs, ... }:

# Heavyweight dev-only system concerns, layered on top of the shared macOS host
# config. Only things too large or too invasive to hand to a personal laptop
# belong here — JVM toolchains. The container runtime is owned by mise's dev,
# work, and work-boot package overlays. Shared system concerns live in ./common.nix.
# Imported by: hosts/darwin/millstrand.nix

{
  imports = [ ./common.nix ];

  environment.systemPackages = with pkgs; [
    clojure
    clj-kondo
    jdk
  ];

  environment.variables.JAVA_HOME = "${pkgs.jdk.home}";
}
