{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    ../desktop.nix
  ];

  networking.hostName = "vm";

  # Keep user systemd services running after logout so tmux sessions persist.
  users.users.codethread.linger = true;

  # Software rendering required in a VM — no GPU passthrough
  environment.sessionVariables = {
    WLR_RENDERER_ALLOW_SOFTWARE = "1"; # wlroots: allow llvmpipe renderer
    LIBGL_ALWAYS_SOFTWARE = "1"; # Electron/GL apps: skip GPU process entirely
  };
}
