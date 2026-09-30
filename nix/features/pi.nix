{
  pkgs,
  pkgsMaster ? null,
  ...
}:

let
  agentPkgSet = if pkgsMaster == null then pkgs else pkgsMaster;
  pi = agentPkgSet."llm-agents".pi.override { useBun = false; }; # bun doesn't bundle codemode

  piNvimTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/pi-nvim/-/pi-nvim-0.2.4.tgz";
    hash = "sha512-d03Lr+vIQp17QGrA5H9YQuv6dxKUxCQywUNVmhhsI4EGnX/aHBz9svoYtI4WRlnx2VA/BsUbjPcbJ20Q84+T0g==";
  };

  piNvim = pkgs.runCommand "pi-nvim-0.2.4" { nativeBuildInputs = [ pkgs.gnutar ]; } ''
    mkdir -p "$out"
    tar -xzf ${piNvimTarball} --strip-components=1 -C "$out"
  '';

  piGoalTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@narumitw/pi-goal/-/pi-goal-0.54.4.tgz";
    hash = "sha512-WqGGYnX5YBaEUlkC2Lh3sFHizJ6/hiGBijybOBv/7RRDZvpMdfygORIl5OHhzqSPekC9+z0ROxiCzPE6hS17jQ==";
  };

  piTuiKitTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@narumitw/pi-tui-kit/-/pi-tui-kit-0.59.0.tgz";
    hash = "sha512-KBbOcciJD+HVbeduUwBUiSy2AehMGYeOwiRPXvac5tcjuh3SDoQ+7qsNPt2s/ku6exJKZp0GYtAVsiu5ySddmA==";
  };

  grokMermaidTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/grok-mermaid/-/grok-mermaid-0.2.3.tgz";
    hash = "sha512-/4KopAbsjvuRP9MdPtlDjOHUmUVEohOX73JNcsWpzAtFxh+bq5+Dhb6gzvRieLDwIPQIR3/vy8V1NNTuz4Zsmg==";
  };

  highlightJsTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/highlight.js/-/highlight.js-11.12.0.tgz";
    hash = "sha512-nbfWpyRMcMrPMmDwJB+dhX/eiaPKtc2RB+0QZskqJ3WjRA/FDS0e9hZrx8EC/lbEv8gXy98FcDbNa/dspAaJMg==";
  };

  piGoal = pkgs.runCommand "pi-goal-0.54.4" { nativeBuildInputs = [ pkgs.gnutar ]; } ''
    mkdir -p "$out/node_modules/@narumitw/pi-tui-kit"
    mkdir -p "$out/node_modules/grok-mermaid"
    mkdir -p "$out/node_modules/highlight.js"

    tar -xzf ${piGoalTarball} --strip-components=1 -C "$out"
    tar -xzf ${piTuiKitTarball} --strip-components=1 -C "$out/node_modules/@narumitw/pi-tui-kit"
    tar -xzf ${grokMermaidTarball} --strip-components=1 -C "$out/node_modules/grok-mermaid"
    tar -xzf ${highlightJsTarball} --strip-components=1 -C "$out/node_modules/highlight.js"
  '';

in
{
  home.packages = [ pi ];

  home.file = {
    ".pi/agent/packages/pi-nvim".source = piNvim;
    ".pi/agent/packages/pi-goal".source = piGoal;
  };
}
