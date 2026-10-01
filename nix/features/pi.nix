{
  pkgs,
  pkgsMaster ? null,
  ...
}:

let
  agentPkgSet = if pkgsMaster == null then pkgs else pkgsMaster;
  pi = agentPkgSet."llm-agents".pi.override { useBun = false; }; # bun doesn't bundle codemode
in
{
  home.packages = [ pi ];
  # Pi owns extension installation through npm sources in pi/agent/settings.json.
}
