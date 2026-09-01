{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rustup
    python311
    coreutils
    fswatch
    ffmpeg
  ];
}
