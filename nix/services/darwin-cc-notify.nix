{
  config,
  pkgs,
  lib,
  ...
}:

let
  username = config.system.primaryUser;
  homeDir = config.users.users.${username}.home;
  repoDir = "${homeDir}/dev/projects/cc-notify";
  stateDir = "${homeDir}/.local/state/com.codethread.cc-notify";
  runner = pkgs.writeShellScript "cc-notify-run" ''
    set -euo pipefail

    export HOME=${lib.escapeShellArg homeDir}
    cd ${lib.escapeShellArg repoDir}
    exec ${lib.getExe pkgs.bun} run src/main.ts
  '';
in
{
  launchd.user.agents.cc-notify = {
    serviceConfig = {
      Label = "com.codethread.cc-notify";
      ProgramArguments = [ "${runner}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${stateDir}/std.log";
      StandardErrorPath = "${stateDir}/std.log";
    };
  };

  system.activationScripts.ccNotify.text = ''
    home=${lib.escapeShellArg homeDir}
    repo=${lib.escapeShellArg repoDir}

    /usr/bin/install -d -o ${lib.escapeShellArg username} -g staff \
      ${lib.escapeShellArg stateDir}

    if [ -d "$repo/.git" ]; then
      echo ">>> cc-notify: repo already present"
    elif /usr/bin/sudo -u ${lib.escapeShellArg username} -H /usr/bin/env \
      HOME="$home" \
      ${lib.getExe' pkgs.openssh "ssh"} -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 \
      | ${lib.getExe' pkgs.gnugrep "grep"} -q "successfully authenticated"; then
      /usr/bin/sudo -u ${lib.escapeShellArg username} -H /usr/bin/env \
        HOME="$home" \
        ${lib.getExe pkgs.git} clone git@github.com:codethread/cc-notify.git "$repo" \
        || echo ">>> WARN: failed to clone cc-notify; continuing"
    else
      echo ">>> Skipping cc-notify clone (no SSH auth to GitHub)"
    fi

    if [ -d "$repo/.git" ]; then
      if ! /usr/bin/sudo -u ${lib.escapeShellArg username} -H /usr/bin/env \
        HOME="$home" \
        ${lib.getExe pkgs.bun} install --frozen-lockfile --cwd "$repo"; then
        echo ">>> WARN: failed to install cc-notify dependencies; continuing"
      fi
    fi
  '';
}
