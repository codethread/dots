{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Home Manager has programs.git.maintenance, but it writes configured paths
  # directly to maintenance.repo. Missing paths make for-each-repo fail. Git's
  # normal global config is also a tracked dotfile here, so this module keeps the
  # filtered repo list in a private state config used only by these launchd jobs.
  cfg = config.codethread.gitMaintenance;
  user = config.system.primaryUser;
  homeDir = config.users.users.${user}.home;
  stateDir = "${homeDir}/.local/state/com.codethread.git-maintenance";
  maintenanceConfig = "${stateDir}/config";
  git = lib.getExe pkgs.git;
  mkdir = lib.getExe' pkgs.coreutils "mkdir";
  mv = lib.getExe' pkgs.coreutils "mv";
  rm = lib.getExe' pkgs.coreutils "rm";

  repoArray = lib.concatMapStringsSep "\n" (repo: "    ${lib.escapeShellArg repo}") cfg.repositories;

  registerScript = pkgs.writeShellScript "codethread-git-maintenance-register" ''
        set -eu

        export HOME=${lib.escapeShellArg homeDir}

        repos=(
    ${repoArray}
        )

        expand_path() {
          local path="$1"
          case "$path" in
            "~")
              printf '%s\n' "$HOME"
              ;;
            "~/"*)
              printf '%s/%s\n' "$HOME" "''${path#~/}"
              ;;
            *)
              printf '%s\n' "$path"
              ;;
          esac
        }

        echo ">>> Configuring Git maintenance repositories"
        ${mkdir} -p ${lib.escapeShellArg stateDir}
        tmp_config="${maintenanceConfig}.tmp.$$"
        trap '${rm} -f "$tmp_config"' EXIT
        : > "$tmp_config"
        export GIT_CONFIG_GLOBAL="$tmp_config"
        ${git} config --global maintenance.strategy incremental
        ${git} config --global --unset-all maintenance.repo >/dev/null 2>&1 || true

        registered=0
        for repo_spec in "''${repos[@]}"; do
          repo="$(expand_path "$repo_spec")"

          if [ ! -d "$repo" ]; then
            echo ">>> Skipping Git maintenance for missing path: $repo"
            continue
          fi

          if ! ${git} -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
            echo ">>> Skipping Git maintenance for non-repo path: $repo"
            continue
          fi

          echo ">>> Registering Git maintenance for $repo"
          if ! ${git} -C "$repo" config maintenance.strategy incremental; then
            echo ">>> WARN: failed to set maintenance.strategy for $repo; continuing"
            continue
          fi
          if ! ${git} -C "$repo" config maintenance.auto false; then
            echo ">>> WARN: failed to set maintenance.auto for $repo; continuing"
            continue
          fi
          if ! ${git} config --global --add maintenance.repo "$repo"; then
            echo ">>> WARN: failed to add $repo to maintenance.repo; continuing"
            continue
          fi

          registered=$((registered + 1))
        done

        ${mv} -f "$tmp_config" ${lib.escapeShellArg maintenanceConfig}
        trap - EXIT

        echo ">>> Git maintenance registered $registered repo(s)"
  '';

  maintenanceRunner =
    frequency:
    pkgs.writeShellScript "codethread-git-maintenance-${frequency}" ''
      set -u
      export HOME=${lib.escapeShellArg homeDir}

      if ! ${registerScript}; then
        echo ">>> WARN: failed to refresh Git maintenance config; using existing config"
      fi

      export GIT_CONFIG_GLOBAL=${lib.escapeShellArg maintenanceConfig}

      exec ${git} for-each-repo \
        --config=maintenance.repo \
        --keep-going \
        maintenance run \
        --schedule=${frequency} \
        --quiet
    '';

  agentFor = frequency: calendar: {
    serviceConfig = {
      Label = "com.codethread.git-maintenance.${frequency}";
      ProgramArguments = [ "${maintenanceRunner frequency}" ];
      StartCalendarInterval = calendar;
      StandardOutPath = "${stateDir}/${frequency}.log";
      StandardErrorPath = "${stateDir}/${frequency}.log";
      EnvironmentVariables = {
        HOME = homeDir;
      };
    };
  };
in
{
  options.codethread.gitMaintenance.repositories = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [
      "~/dev/projects/notes/vault"
      "~/work/large-repo"
    ];
    description = ''
      Repository paths to maintain with Git's incremental background maintenance.

      Missing paths and non-Git directories are skipped during activation. Paths
      may use a leading ~/ prefix, which is expanded for the primary Darwin user.
    '';
  };

  config = lib.mkIf (cfg.repositories != [ ]) {
    launchd.user.agents = {
      git-maintenance-hourly = agentFor "hourly" (
        map (hour: {
          Hour = hour;
          Minute = 53;
        }) (lib.range 1 23)
      );
      git-maintenance-daily = agentFor "daily" (
        map (weekday: {
          Weekday = weekday;
          Hour = 0;
          Minute = 53;
        }) (lib.range 1 6)
      );
      git-maintenance-weekly = agentFor "weekly" [
        {
          Weekday = 0;
          Hour = 0;
          Minute = 53;
        }
      ];
    };

    system.activationScripts.gitMaintenance.text = ''
      /usr/bin/install -d -o ${lib.escapeShellArg user} -g staff ${lib.escapeShellArg stateDir}

      if ! /usr/bin/sudo \
        --user=${lib.escapeShellArg user} \
        --set-home \
        /usr/bin/env HOME=${lib.escapeShellArg homeDir} \
        ${registerScript}; then
        echo ">>> WARN: failed to configure Git maintenance; continuing"
      fi
    '';
  };
}
