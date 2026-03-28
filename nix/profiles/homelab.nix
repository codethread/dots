{ pkgs, ... }:

# x86_64-linux homelab machine profile.
# Uses shared common + nixos-common features and adds Google Chrome.

{
  imports = [
    ../features/common.nix
    ../features/nixos-common.nix
  ];

  # Chrome ships two .desktop files; both need --disable-gpu to prevent VM GPU crashes.
  xdg.desktopEntries.google-chrome = {
    name = "Google Chrome";
    exec = "${pkgs.google-chrome}/bin/google-chrome-stable --disable-gpu %U";
    icon = "google-chrome";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https" ];
  };
  xdg.desktopEntries."com.google.Chrome" = {
    name = "Google Chrome";
    exec = "${pkgs.google-chrome}/bin/google-chrome-stable --disable-gpu %U";
    icon = "google-chrome";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https" ];
  };

  xdg.desktopEntries.obsidian = {
    name = "Obsidian";
    exec = "${pkgs.obsidian}/bin/obsidian %u";
    icon = "obsidian";
    categories = [ "Office" ];
    mimeType = [ "x-scheme-handler/obsidian" ];
  };

  ct.claude-code.enableNotify = true;

  home.packages = with pkgs; [
    chromium
    ffmpeg
    google-chrome
    spotify
    obsidian
    todoist-electron
  ];

  # OBS streaming profile — pairs with host mediamtx config in hosts/nixos/homelab/default.nix.
  # OBS will overwrite these on GUI save; treat as initial seed.
  xdg.configFile = {
    # Advanced output mode required for streamEncoder.json to be respected.
    "obs-studio/basic/profiles/Untitled/basic.ini" = {
      force = true;
      text = ''
        [General]
        Name=Untitled

        [Output]
        Mode=Advanced

        [AdvOut]
        ApplyServiceSettings=true
        UseRescale=false
        TrackIndex=1
        Encoder=obs_x264
        RecType=Standard
        RecFilePath=/home/codethread
        RecFormat2=hybrid_mp4
        RecUseRescale=false
        RecTracks=1
        RecEncoder=none

        [Video]
        BaseCX=1920
        BaseCY=1080
        OutputCX=1280
        OutputCY=720
        FPSType=0
        FPSCommon=30
        FPSInt=30
        FPSNum=30
        FPSDen=1
        ScaleType=bicubic
        ColorFormat=NV12
        ColorSpace=709
        ColorRange=Partial

        [Audio]
        MonitoringDeviceId=default
        MonitoringDeviceName=Default
        SampleRate=48000
        ChannelSetup=Stereo
      '';
    };

    "obs-studio/basic/profiles/Untitled/service.json" = {
      force = true;
      text = builtins.toJSON {
        type = "rtmp_custom";
        settings = {
          server = "rtmp://127.0.0.1/live";
          key = "desktop";
          use_auth = false;
          bwtest = false;
        };
      };
    };
    # baseline + zerolatency + explicit bframes=0: WebRTC rejects streams with B-frames.
    # x264opts overrides encoder defaults regardless of output mode (Simple or Advanced).
    "obs-studio/basic/profiles/Untitled/streamEncoder.json" = {
      force = true;
      text = builtins.toJSON {
        rate_control = "CBR";
        bitrate = 2500;
        profile = "baseline";
        tune = "zerolatency";
        x264opts = "bframes=0";
      };
    };
  };
}
