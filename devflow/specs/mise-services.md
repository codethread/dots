# Mise-managed macOS services

## Ownership and setup

Native `mise bootstrap` prepares and applies user LaunchAgents. Use a durable checkout in a logged-in macOS GUI session, without sudo: generated jobs reference that checkout's absolute path.

| Profile  | Agents                                         |
| -------- | ---------------------------------------------- |
| All      | syncengine                                     |
| dev/work | cc-notify, hourly/daily/weekly Git maintenance |
| dev only | backup-notes                                   |

Syncengine is declared in root `mise.toml`. The dev/work entrypoints `.mise/conf.d/services.dev.toml` and `.mise/conf.d/services.work.toml` are symlinks to `.mise/dev-work-services.toml`; that reusable source is not automatically loaded. `.miserc.toml` enables the environment-suffixed entrypoints, so personal excludes these services. Root profile overlays supply maintenance repositories and dev's backup job. Each complete agent declaration has one source.

```nu
mise -E work bootstrap --dry-run
mise -E work bootstrap
mise -E work bootstrap macos launchd-agents status
```

Bootstrap creates log directories and clones declared repos before `boot/setup.sh` runs. That hook installs application dependencies, checks cc-notify credential names without printing values, registers filtered Git maintenance, and checks syncengine dependencies. The later native dotfiles phase links gitwatch; LaunchAgents load afterwards. Tools are installed early in the post-packages hook because raw LaunchAgents precede mise's normal tools phase.

Keep credentials in cc-notify's local `.env`. Missing SSH access, credentials, or failed setup aborts before loading new agents. Direct `mise bootstrap macos launchd-agents apply` bypasses preparation; use it only when prerequisites are already ready. Neither a dry run nor `loaded` proves application health.

## Inspection and lifecycle

```nu
mise bootstrap macos launchd-agents status --missing
let domain = $"gui/(id -u | str trim)"
launchctl print $"($domain)/dev.mise.cc-notify"
let port = (open --raw ~/.local/state/cc-notify/port | str trim)
http get $"http://127.0.0.1:($port)/health"
```

An unchanged apply preserves the running PID. To restart cc-notify after changing its source or Bun, boot out `dev.mise.cc-notify`, wait for its process to exit and port sentinel to disappear, then apply the native LaunchAgent declarations. Wait for the new port file before probing health; do not send real notifications merely to test readiness.

For a scheduled maintenance run, use `launchctl kickstart gui/UID/dev.mise.git-maintenance-hourly`. Scheduled jobs are normally idle; inspect their last exit code and logs. Deleting a declaration does not prune an installed job: explicitly boot out its label and remove only its matching plist.

Logs:

- cc-notify stdout/stderr: `~/.local/state/com.codethread.cc-notify/std.log`; application JSONL: checkout `.logs/cc-notify.jsonl`.
- Git maintenance: `~/.local/state/com.codethread.git-maintenance/{hourly,daily,weekly}.log`.
- Backup-notes: `~/.local/state/com.codethread.backup-notes/std.log`.
- Syncengine: `~/.local/state/com.codethread.syncengine/std.log` plus per-target logs.

## Service behavior

**cc-notify:** launchd invokes Homebrew's stable mise path with the dots profile, then `mise exec -- bun run --cwd <cc-notify> src/main.ts`. Bun selects the application's working directory and `.env`; no hidden foreground task or shell activation is needed. KeepAlive is unconditional.

**Syncengine:** an inline `/bin/bash` runner launches `gitwatch -r origin -R` for each entry in `~/sync` and for iCloud Notes when present. An empty directory starts no watchers. It starts at login/load without KeepAlive, using explicit user/Homebrew/coreutils/macOS paths. Git/SSH configuration stays user-owned. Check child gitwatch/fswatch processes and per-target logs; the loaded parent alone is insufficient. After updating gitwatch, boot out syncengine and wait for its children to exit before reapplying. Do not edit real repositories to test it: syncing commits and pushes automatically.

**Backup-notes (dev):** runs at load and every 900 seconds. Native Git stages the vault, commits only when needed with a UTC timestamp, then pulls with rebase and pushes. Failures notify once per failure streak through `~/.local/bin/cc-notify`; successful push clears the sentinel. Applying it immediately performs a real backup.

**Git maintenance:** each profile supplies a newline-separated repository list, supporting `~/` and spaces. Every run atomically rebuilds a private config, skipping absent/non-repositories; sets local `maintenance.strategy=incremental` and `maintenance.auto=false`; and leaves global Git config untouched. Native `/usr/bin/git` runs `for-each-repo --keep-going maintenance run --schedule=<frequency> --quiet`:

- Hourly: 01:53–23:53.
- Daily: Monday–Saturday, 00:53.
- Weekly: Sunday, 00:53.

Do not add a second scheduler with `git maintenance start`. Failed writes fail visibly, without using stale registrations.

## Verification

Validate all three profiles, inspect read-only LaunchAgent plans and generated plist paths/arguments, and syntax-check inline Bash. After an operator apply, check readiness, scheduled-job exit codes, watcher shutdown/startup, and an unchanged second apply. Applying from another checkout changes embedded paths and may reload jobs.
