{ pkgs, lib, ... }:

# x86_64-linux homelab machine profile.
# Uses shared common + nixos-common features and adds Google Chrome.

{
  imports = [
    ../features/common.nix
    ../features/nixos-common.nix
    (import ../services/repo-service.nix {
      name = "ai-task-cron";
      gitUrl = "git@github.com:codethread/notes.git";
      command = "{bun} scripts/automation/src/ai-task-cron.ts";
      devShell = "automation";
    })
    (import ../services/repo-service.nix {
      name = "ai-note-watcher";
      gitUrl = "git@github.com:codethread/notes.git";
      command = "{bun} scripts/automation/src/ai-note-watcher.ts";
      devShell = "automation";
    })
    (import ../services/repo-service.nix {
      name = "yt-playlist-watcher";
      gitUrl = "git@github.com:codethread/notes.git";
      command = "{bun} scripts/automation/src/yt-playlist-watcher.ts";
      devShell = "automation";
    })
    (import ../services/repo-service.nix {
      name = "cc-inspect";
      gitUrl = "git@github.com:codethread/cc-inspect.git";
      command = "{bun} --cwd packages/cc-inspect start";
      devShell = "default";
    })
    (import ../services/repo-service.nix {
      name = "cc-notify";
      gitUrl = "git@github.com:codethread/cc-notify.git";
      command = "{bun} start";
      devShell = "default";
    })
  ];

  # Chrome ships two .desktop files; both need --disable-gpu to prevent VM GPU crashes.
  xdg.desktopEntries.google-chrome = {
    name = "Google Chrome";
    exec = "${lib.getExe pkgs.google-chrome} --disable-gpu %U";
    icon = "google-chrome";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https" ];
  };
  xdg.desktopEntries."com.google.Chrome" = {
    name = "Google Chrome";
    exec = "${lib.getExe pkgs.google-chrome} --disable-gpu %U";
    icon = "google-chrome";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https" ];
  };

  ct.claude-code.enableNotify = true;

  # Repo-local managed services (see nix/CLAUDE.md "Adding a Service")
  services.ai-task-cron.enable = true;
  services.ai-task-cron.workingDirectory = "/home/codethread/dev/projects/notes";

  services.ai-note-watcher.enable = true;
  services.ai-note-watcher.workingDirectory = "/home/codethread/dev/projects/notes";

  services.yt-playlist-watcher.enable = true;
  services.yt-playlist-watcher.workingDirectory = "/home/codethread/dev/projects/notes";

  services.cc-inspect.enable = true;
  services.cc-inspect.workingDirectory = "/home/codethread/dev/projects/cc-inspect";

  services.cc-notify.enable = true;
  services.cc-notify.workingDirectory = "/home/codethread/dev/projects/cc-notify";

  home.packages = with pkgs; [
    chromium
    ffmpeg
    google-chrome
    python3
    spotify
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
