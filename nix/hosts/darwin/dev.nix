{ ... }:

{
  imports = [
    ./common.nix
  ];

  services.openssh = {
    enable = true;
    extraConfig = ''
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      AllowUsers ct
    '';
  };
}
