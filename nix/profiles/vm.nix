{ pkgs, lib, ... }:

# aarch64-linux VM profile (Apple Silicon host).
# Uses shared common + nixos-common features and adds Chromium.

{
  imports = [
    ../features/common.nix
    ../features/nixos-common.nix
  ];

  # chromium-browser is the .desktop filename installed by pkgs.chromium.
  xdg.desktopEntries.chromium-browser = {
    name = "Chromium";
    exec = "${lib.getExe pkgs.chromium} --disable-gpu %U";
    icon = "chromium";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https" ];
  };

  home.packages = [ pkgs.chromium ];
}
