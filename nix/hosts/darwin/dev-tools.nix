{ pkgs, ... }:

# Heavyweight dev-only system concerns, layered on top of the shared macOS host
# config. Only things too large or too invasive to hand to a personal laptop
# belong here — JVM toolchains and the container runtime. Everything else lives
# in ./common.nix so dev, personal, and work stay in sync by default.
# Imported by: hosts/darwin/dev.nix, hosts/darwin/common-work.nix

{
  imports = [ ./common.nix ];

  environment.systemPackages = with pkgs; [
    clojure
    clj-kondo
    jdk
  ];

  environment.variables.JAVA_HOME = "${pkgs.jdk.home}";

  homebrew.brews = [
    "podman" # Homebrew tracks Podman and its macOS machine integration more closely
    "podman-compose" # Compose wrapper kept alongside Homebrew Podman
  ];

  homebrew.casks = [
    "terminal-browser"
  ];
}
