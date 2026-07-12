{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rustup
    python311
    deno
    coreutils
    fswatch
    ast-grep
    ffmpeg
    yt-dlp
  ];
}
