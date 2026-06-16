{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    ../desktop.nix
  ];

  networking.hostName = "homelab";

  # 8 cores / 32 GB RAM — push download parallelism hard
  nix.settings = {
    max-substitution-jobs = 128;
    http-connections = 128;
    download-buffer-size = 134217728; # 128 MiB per connection
  };

  # Expo Go (LAN) / Metro ports.
  networking.firewall.allowedTCPPorts = [
    443
    3001
    3888
    5555
    8081
    19000
    19001
    19002
  ];
  networking.firewall.allowedUDPPorts = [
    19000
    19001
    19002
  ];

  # Keep user systemd services running after logout (linger = true).
  users.users.codethread.linger = true;

  # Keyboard: remap Caps Lock to an additional Control key.
  services.xserver.xkb.options = "ctrl:nocaps";
  console.useXkbConfig = true;

  # Terminal brightness control (e.g. `brightnessctl set 5%-`).
  environment.systemPackages = with pkgs; [
    brightnessctl
    nssTools # certutil — needed by Caddy to install its root CA into the system trust store
    obs-studio
    resvg
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

  # TLS reverse proxy for cc-inspect so LAN clients get a secure context
  # (clipboard API, etc.). Caddy uses its own internal CA — install its root
  # cert on each client device once: trust /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
  services.caddy = {
    enable = true;
    virtualHosts."homelab.local" = {
      extraConfig = ''
        reverse_proxy localhost:5555
        tls internal
      '';
    };
  };

}
