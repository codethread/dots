{ lib, pkgs, ... }:

# Shared NixOS system config imported by all NixOS hosts.
# Hardware and hostname live in each host's own directory.

{
  # --- Boot ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Nix ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-substitution-jobs = lib.mkDefault 32;
    http-connections = lib.mkDefault 50;
  };
  nix.gc = {
    automatic = true;
    dates = "Mon *-*-* 01:00:00";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnsupportedSystem = true; # e.g. discord, spotify on non-x86 Linux

  # --- Networking ---
  networking.networkmanager.enable = true;

  # --- SSH ---
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false; # key-based only
    settings.UseDns = false; # skip reverse DNS lookup on connecting clients
  };

  programs.ssh.startAgent = true;

  # --- Locale ---
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # Keyboard repeat: lower delay/interval means faster key repetition.
  services.xserver.autoRepeatDelay = 200;
  services.xserver.autoRepeatInterval = 25;

  # --- Shell ---
  environment.variables.EDITOR = "nvim";

  # Register nushell as a valid login shell (adds it to /etc/shells)
  environment.shells = [ pkgs.nushell ];

  # --- User ---
  users.users.codethread = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "podman" ];
    shell = pkgs.nushell;
    initialPassword = "changeme"; # change after first login with: passwd
  };

  # --- Containers ---
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Minimal system packages — everything else is via home-manager
  environment.systemPackages = with pkgs; [
    git   # needed to clone dotfiles on fresh install
    curl
    wget
    gnumake
    slirp4netns # rootless podman networking
    lsof
  ];

  system.stateVersion = "24.11";
}
