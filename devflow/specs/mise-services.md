# Mise-managed macOS services

## Ownership and setup

Native `mise bootstrap` prepares and applies user LaunchAgents. Use a durable checkout in a logged-in macOS GUI session, without sudo: generated jobs reference that checkout's absolute path.

| Owner              | Agents                                                       |
| ------------------ | ------------------------------------------------------------ |
| Dots, all profiles | syncengine, pitchfork                                        |
| Dots, dev only     | cc-notify, hourly/daily/weekly Git maintenance, backup-notes |
| Workfiles          | cc-notify, hourly/daily/weekly Git maintenance               |

Syncengine is declared in root `mise.toml`. The dev entrypoint `.mise/conf.d/services.dev.toml` links to `.mise/dev-services.toml`; `.miserc.toml` enables that environment-suffixed entrypoint. Workfiles owns its work-machine services in `.mise/conf.d/services.toml`, including its repository list and preparation hooks. It reuses the generic `~/.local/bin/git-maintenance` helper installed by dots. The existing `dev.mise.*` labels and schedules are preserved, so the ownership move does not introduce a second scheduler.

```nu
mise -E dev bootstrap --dry-run
mise -E dev bootstrap macos launchd-agents status
# On work machines, inspect work-owned agents from their owning checkout:
cd ~/pb/adam.hall/workfiles
make plan
make status
```

Dots' work-profile final hook clones workfiles when needed and runs its default `make`, after common dots setup finishes. Workfiles registers its project daemon definitions with Pitchfork during service preparation; registration does not start the approval task. Missing GitLab authentication warns and skips this handoff; errors from an available workfiles checkout fail visibly. Dots' dry run prints the handoff but does not recursively plan workfiles. This is a separate ordered bootstrap, not late preparation for dots-owned jobs.

Each owning bootstrap creates log directories and clones declared repos before its `boot/setup.sh` runs. That hook installs application dependencies, runs cc-notify's `make link-bin` to link its CLI into `~/.local/bin`, warns about missing cc-notify credential names without printing values, registers filtered Git maintenance, and checks syncengine dependencies. The later native dotfiles phase links gitwatch; LaunchAgents load afterwards. Tools are installed early in the post-packages hook because raw LaunchAgents precede mise's normal tools phase.

Keep credentials in cc-notify's local `.env`. Missing SSH access or failed dependency setup aborts before loading new agents. Missing credentials produce a bootstrap warning and fail cc-notify at runtime; general bootstrap and other agents continue. Inspect `launchctl print gui/UID/dev.mise.cc-notify` and `~/.local/state/com.codethread.cc-notify/std.log` after bootstrap. Add `PUSHOVER_CC_KEY` and `PUSHOVER_DEV_KEY` to the application's `.env` when ready; KeepAlive retries startup. Neither a dry run nor `loaded` proves application health. Direct `mise bootstrap macos launchd-agents apply` bypasses preparation; use it only when dependencies are already ready.

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

- Pitchfork supervisor stdout/stderr: `~/.local/state/com.codethread.pitchfork/std.log`; project daemon logs remain available through `mise daemons logs` in their owning checkout.
- cc-notify stdout/stderr: `~/.local/state/com.codethread.cc-notify/std.log`; application JSONL: checkout `.logs/cc-notify.jsonl`.
- Git maintenance: `~/.local/state/com.codethread.git-maintenance/{hourly,daily,weekly}.log`.
- Backup-notes: `~/.local/state/com.codethread.backup-notes/std.log`.
- Syncengine: `~/.local/state/com.codethread.syncengine/std.log` plus per-target logs.

## Service behavior

**Pitchfork:** dots owns `dev.mise.pitchfork`, a user LaunchAgent running the foreground `pitchfork supervisor run --boot` through the official `~/.local/bin/mise`. Common setup installs the pinned tool and global tool links before launchd loads it. It starts at login and restarts only on failure. Each project owns and registers its daemon definitions; registration persists across logins. Pitchfork 2.29.0 discovers registered cron jobs without `boot_start`, so workfiles' five-minute `reapprove` schedule resumes without an extra immediate approval run. `stopped` between cron runs is normal; inspect `mise daemons status reapprove --json` and logs from workfiles to see the last/next run.

Do not also run `pitchfork boot enable`: startup has one owner. Its `boot status` command checks Pitchfork's own service, not `dev.mise.pitchfork`; inspect this LaunchAgent instead. If a CLI-started supervisor is already running, the managed command exits successfully without taking it over, and does not restart-loop. The existing stack stays untouched until logout/reboot; for an immediate handoff, stop the existing supervisor only when its workloads can be interrupted, then start the managed agent. Do not use `--force` during bootstrap. Reconcile any separately installed `pitchfork.plist` before applying. The declared official mise executable must exist; older Homebrew-only installations need the documented installer migration first. After confirming managed startup works, `[settings.supervisor] auto_start = false` in Pitchfork's user config can prevent CLI-created replacements; bootstrap does not change this setting on an already-running stack.

**cc-notify (dev):** launchd starts the official mise executable at `~/.local/bin/mise` in the dots checkout with the explicit profile, then `mise exec -- bun run --cwd <cc-notify> src/main.ts`. Workfiles owns its equivalent work configuration. Starting mise in its checkout loads early `.miserc.toml` settings; `mise -C` from the application directory misses those early settings in mise 2026.9.15 and can load other profiles' fragments. Bun still selects the application's working directory and `.env`; no hidden foreground task or shell activation is needed. KeepAlive is unconditional.

**Syncengine:** an inline `/bin/bash` runner launches `gitwatch -r origin -R` for each entry in `~/sync` and for iCloud Notes when present. An empty directory starts no watchers. It starts at login/load without KeepAlive, using explicit user/Homebrew/coreutils/macOS paths. Git/SSH configuration stays user-owned. Check child gitwatch/fswatch processes and per-target logs; the loaded parent alone is insufficient. After updating gitwatch, boot out syncengine and wait for its children to exit before reapplying. Do not edit real repositories to test it: syncing commits and pushes automatically.

**Backup-notes (dev):** runs at load and every 900 seconds. Native Git stages the vault, commits only when needed with a UTC timestamp, then pulls with rebase and pushes. Failures notify once per failure streak through `~/.local/bin/cc-notify`; successful push clears the sentinel. Applying it immediately performs a real backup.

**Git maintenance:** each profile supplies a newline-separated repository list, supporting `~/` and spaces. Every run atomically rebuilds a private config, skipping absent/non-repositories; sets local `maintenance.strategy=incremental` and `maintenance.auto=false`; and leaves global Git config untouched. Native `/usr/bin/git` runs `for-each-repo --keep-going maintenance run --schedule=<frequency> --quiet`:

- Hourly: 01:53–23:53.
- Daily: Monday–Saturday, 00:53.
- Weekly: Sunday, 00:53.

Do not add a second scheduler with `git maintenance start`. Failed writes fail visibly, without using stale registrations.

## Verification

Validate all three profiles, inspect read-only LaunchAgent plans and generated plist paths/arguments, and syntax-check inline Bash. After an operator apply, check readiness, scheduled-job exit codes, watcher shutdown/startup, and an unchanged second apply. Applying from another checkout changes embedded paths and may reload jobs.
