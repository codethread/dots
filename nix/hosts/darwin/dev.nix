{
  pkgs,
  config,
  lib,
  ...
}:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
  git = lib.getExe pkgs.git;
  date = lib.getExe' pkgs.coreutils "date";
  backupNotesStateDir = "${homeDir}/.local/state/com.codethread.backup-notes";
  highCpuStateDir = "${homeDir}/.local/state/com.codethread.high-cpu-watch";
  highCpuWatchScript = pkgs.writeShellScript "high-cpu-watch" ''
    set -Eeuo pipefail

    threshold=95
    samples_required=10
    state_file="${highCpuStateDir}/state.tsv"
    next_state="${highCpuStateDir}/state.tsv.next"
    candidates="${highCpuStateDir}/candidates.tsv"

    /bin/mkdir -p "${highCpuStateDir}"
    /usr/bin/touch "$state_file"

    # macOS ps reports %CPU per process, where 100 is one fully saturated core.
    /bin/ps -axo pid=,pcpu=,comm= \
      | /usr/bin/awk -v threshold="$threshold" '$2 + 0 >= threshold { print $1 "\t" int($2) "\t" $3 }' \
      > "$candidates"

    : > "$next_state"
    while IFS=$'\t' read -r pid cpu comm; do
      previous=$(/usr/bin/awk -F '\t' -v pid="$pid" '$1 == pid { print; exit }' "$state_file")
      if [ -n "$previous" ]; then
        count=$(printf '%s\n' "$previous" | /usr/bin/awk -F '\t' '{ print $2 }')
        alerted=$(printf '%s\n' "$previous" | /usr/bin/awk -F '\t' '{ print $3 }')
      else
        count=0
        alerted=0
      fi
      count=$((count + 1))
      printf '%s\t%s\t%s\t%s\t%s\n' "$pid" "$count" "$alerted" "$cpu" "$comm" >> "$next_state"
    done < "$candidates"

    mv "$next_state" "$state_file"

    while IFS=$'\t' read -r pid count alerted cpu comm; do
      if [ "$count" -ge "$samples_required" ] && [ "$alerted" -eq 0 ]; then
        {
          echo "Process has been at or above ${toString 95}% CPU for ${toString 10} consecutive minutes."
          echo
          echo "PID: $pid"
          echo "CPU: $cpu%"
          echo "Command: $comm"
          echo
          /bin/ps -p "$pid" -o pid=,ppid=,etime=,pcpu=,pmem=,command= || true
        } | "${homeDir}/.local/bin/cc-notify" "High CPU: $comm" || true

        /usr/bin/awk -F '\t' -v pid="$pid" 'BEGIN { OFS = FS } $1 == pid { $3 = 1 } { print }' "$state_file" > "$next_state"
        mv "$next_state" "$state_file"
      fi
    done < "$state_file"
  '';
  backupNotesScript = pkgs.writeShellScript "backup-notes" ''
    set -Eeuo pipefail

    sentinel="${backupNotesStateDir}/failure-notified"

    notify_failure() {
      local exit_code="$?"
      trap - ERR

      if [ ! -e "$sentinel" ]; then
        {
          echo "backup-notes failed with exit code $exit_code."
          echo
          echo "Repository: ${homeDir}/dev/projects/notes/vault"
          echo
          ${git} -C "${homeDir}/dev/projects/notes/vault" status --short --branch || true
        } | "${homeDir}/.local/bin/cc-notify" "Notes git backup failed" || true
        : > "$sentinel"
      fi

      exit "$exit_code"
    }

    trap notify_failure ERR

    cd "${homeDir}/dev/projects/notes/vault"

    ${git} add -A
    if ! ${git} diff --cached --quiet; then
      ${git} commit -m "auto: $(${date} -u +%Y-%m-%dT%H:%M:%SZ)"
    fi

    ${git} pull --rebase
    ${git} push

    rm -f "$sentinel"
  '';
in
{
  imports = [
    ./dev-tools.nix
    ../../services/darwin-cc-notify.nix
  ];

  services.openssh = {
    enable = true;
    extraConfig = ''
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      AllowUsers ct
    '';
  };

  codethread.gitMaintenance.repositories = [
    "${homeDir}/dev/projects/notes/vault"
  ];

  launchd.user.agents = {
    backup-notes = {
      serviceConfig = {
        Label = "com.codethread.backup-notes";
        ProgramArguments = [ "${backupNotesScript}" ];
        RunAtLoad = true;
        StartInterval = 900;
        StandardOutPath = "${backupNotesStateDir}/std.log";
        StandardErrorPath = "${backupNotesStateDir}/std.log";
      };
    };

    high-cpu-watch = {
      serviceConfig = {
        Label = "com.codethread.high-cpu-watch";
        ProgramArguments = [ "${highCpuWatchScript}" ];
        RunAtLoad = true;
        StartInterval = 60;
        StandardOutPath = "${highCpuStateDir}/std.log";
        StandardErrorPath = "${highCpuStateDir}/std.log";
      };
    };
  };

  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -o ${config.system.primaryUser} -g staff ${backupNotesStateDir}
    /usr/bin/install -d -o ${config.system.primaryUser} -g staff ${highCpuStateDir}
  '';
}
