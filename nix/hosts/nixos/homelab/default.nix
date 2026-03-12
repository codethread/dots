{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    ../desktop.nix
  ];

  networking.hostName = "homelab";

  # Expo Go (LAN) / Metro ports + desktop WebRTC stream ports.
  networking.firewall.allowedTCPPorts = [ 3001 5555 8081 8889 19000 19001 19002 ];
  networking.firewall.allowedUDPPorts = [ 8189 19000 19001 19002 ];

  # Keep user systemd services running after logout so tmux sessions persist.
  users.users.codethread.linger = true;

  # Keyboard: remap Caps Lock to an additional Control key.
  services.xserver.xkb.options = "ctrl:nocaps";
  console.useXkbConfig = true;

  # Terminal brightness control (e.g. `brightnessctl set 5%-`).
  environment.systemPackages = with pkgs; [
    brightnessctl
    obs-studio
  ];
  users.users.codethread.extraGroups = [ "video" ];

  # Laptop behavior: keep running when lid is closed.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Advertise hostname on LAN as homelab.local for mDNS clients (e.g. macOS).
  services.avahi = {
    enable = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Bootstrap mode: allow password SSH login from trusted LAN clients.
  # Remove this once key-based auth is in place.
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

  # Prefer wired if available; fall back to Pi-Fi.
  networking.networkmanager.ensureProfiles = {
    profiles = {
      "Wired" = {
        connection = {
          id = "Wired";
          type = "ethernet";
          autoconnect = true;
          autoconnect-priority = 100;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };

      "pie-fi" = {
        connection = {
          id = "pie-fi";
          type = "wifi";
          autoconnect = true;
          autoconnect-priority = 10;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "pie-fi";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$PIFI_PSK";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };

    # Local secrets file (not in git) for envsubst.
    environmentFiles = [
      "/etc/codethread/nm.env"
    ];
  };

  # Low-latency desktop streaming via OBS -> mediamtx -> WebRTC.
  # View on iOS Safari: http://<host-ip>:8889/live/desktop
  services.mediamtx = {
    enable = true;
    settings = {
      # Loopback-only: OBS connects locally, no reason to expose RTMP on the network
      rtmpAddress = "127.0.0.1:1935";
      webrtcAddress = ":8889";
      # Accept any published stream without pre-registration
      paths.all_others = {};
    };
  };
}
