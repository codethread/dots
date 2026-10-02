# Mise-managed macOS services

## Scope and ownership

The project mise configuration owns five shared dev/work user LaunchAgents: syncengine, cc-notify, and hourly/daily/weekly Git maintenance, plus a dev-only backup-notes agent. macOS launchd supervises them; mise renders and applies their definitions. Service declarations are deliberately project-scoped: they require no shell activation or extra supervisor and are not part of the global mise tool configuration.

- `mise.toml`: pinned tools and shared prepare/apply/status tasks.
- `.mise/conf.d/cc-notify.toml`: foreground cc-notify task and its LaunchAgent.
- `.mise/conf.d/git-maintenance.toml`: hourly/daily/weekly maintenance LaunchAgents.
- `.mise/conf.d/syncengine.toml`: syncengine LaunchAgent, inline Bash watcher, and standalone prepare/apply/status tasks, available on every macOS profile. There is no separate syncengine executable.
- `mise.dev.toml`: backup-notes with its inline Bash runner, notes vault maintenance and cc-notify, alongside shared syncengine.
- `mise.work.toml`: deals-light-ui maintenance and cc-notify, alongside shared syncengine.
- Personal and work-boot machines apply only syncengine using `syncengine:apply`. The full `services:*` workflow requires `dev` or `work` explicitly; a missing overlay cannot render the other services' required profile variables.
- mise also owns macOS host packages: `.mise/conf.d/packages.toml` plus the profile overlays (`mise.dev.toml`, `mise.work.toml`, `mise.personal.toml`, `mise.work-boot.toml`). `packages:apply` installs versioned tools and those packages, builds the pinned Todoist fork, then installs user-prefix `@playwright/cli` and the profile's VS Code extensions; `packages:status` reports host state. Applying packages never prunes or upgrades; formula upgrades are explicit via `mise bootstrap packages upgrade --manager brew`.
- `boot/boot.sh` installs Homebrew and then mise (`brew install mise`); the stable service executable is `/opt/homebrew/bin/mise`, not a Nix-store path. Nix no longer declares or upgrades Homebrew packages. This matches the repository's Apple Silicon hosts.
- mise provides pinned Bun 1.4.2 through `[tools]` for cc-notify. Other user runtimes are also mise-owned through `config/mise/`; remaining Darwin system packages are separate.
- Git maintenance uses macOS `/usr/bin/git` (Command Line Tools required).

mise discovers the `.mise/conf.d/*.toml` fragments automatically; no include directive or experimental setting is needed. Keep each complete agent declaration in one fragment: duplicate names replace the entire declaration, not individual fields. For these recognized project fragments, `config_root` remains the repository root, so moving declarations does not change generated executable paths. The root profile overlays still supply the shared variables.

Apply from the durable canonical checkout, not a disposable worktree: generated jobs reference that checkout's absolute path. Applying from another checkout replaces those paths. Do not delete or move the active checkout without applying again from its replacement.

## First-time setup

From the repository root, after `boot.sh` installed Homebrew and mise (`brew install mise`):

```nu
mise trust
mise -E dev config
mise -E dev tasks
mise -E dev install
mise -E dev run services:prepare
mise -E dev bootstrap macos launchd-agents apply --dry-run
mise -E dev run services:apply
mise -E dev run services:status
```

Use `work` instead of `dev` on the full work profile. First run `packages:apply` and `repositories:apply` (or the full `workstation:apply`) to provision gitwatch, its symlink, Git, fswatch, and coreutils. Preparation verifies syncengine's dependencies using its launchd PATH, clones cc-notify if absent, installs its frozen Bun dependencies, checks required credential names without printing values, creates state/log directories, and refreshes filtered Git registrations. The credentials remain in cc-notify's local `.env`; they are not copied into tracked TOML or plists. Missing SSH access, credentials, or failed setup stops the apply before any new agent is loaded.

The `services:apply` task runs preparation first. Do **not** substitute bare `mise bootstrap`: its raw LaunchAgents phase precedes tool installation and the final bootstrap task. The direct dry-run command above does not install tools; `mise run` tasks may install their declared tools before executing.

For personal/work-boot machines, or to migrate only syncengine on dev/work:

```nu
mise -E personal run syncengine:prepare
with-env { MISE_OVERRIDE_CONFIG_FILENAMES: ($env.PWD | path join ".mise/conf.d/syncengine.toml") } {
    mise -E personal bootstrap macos launchd-agents apply --dry-run
}
# After retiring the old Nix agent (see below):
mise -E personal run syncengine:apply
mise -E personal run syncengine:status
```

Replace `personal` with the intended profile. The standalone apply/status tasks select only the syncengine project fragment via `MISE_OVERRIDE_CONFIG_FILENAMES`, so they do not apply cc-notify or Git maintenance or require their profile variables/credentials. Global mise configuration still loads normally.

These are per-user agents: apply in a logged-in macOS GUI session, without sudo. They run while that user is logged in, not as boot-time system daemons.

Host packages are separate from services: `boot.sh` applies them with `mise -C "$DOTFILES" -E <mise-profile> run packages:apply` before the Nix switch. Preview host package changes with `mise -E dev bootstrap packages apply --dry-run`; applying packages never prunes or upgrades existing packages, so upgrade formulae explicitly with `mise -E dev bootstrap packages upgrade --manager brew`.

## Moving an existing Nix installation

1. Prepare the mise services and preview their definitions.
2. Run `make system` with this updated checkout. It keeps the Homebrew-installed mise and removes the old Nix-owned service definitions.
3. Confirm the old syncengine process and its gitwatch/fswatch children have exited before starting the replacement; launchd shutdown is asynchronous.
4. Run `mise -E dev run services:apply` (or `work`), or `mise -E <profile> run syncengine:apply` for syncengine alone. Both paths refuse to apply while the old Nix syncengine agent is still loaded.
5. Check syncengine's watcher processes and logs; for the full service set also check cc-notify's health and the three maintenance jobs. On dev, also confirm `com.codethread.backup-notes` is unloaded before applying its replacement, `dev.mise.backup-notes`; `services:apply` refuses to proceed while the old label is loaded.

The old Nix job references the removed standalone syncengine script. Complete this handoff before the next login/restart; an already-running old process is not replaced by editing the repository. Its obsolete `~/.local/bin/syncengine` symlink can be removed after the handoff.

When a system switch must wait for sudo authentication, the user jobs can be cut over separately after successful preparation. Disable **and** unload the old labels, preserving their plist files until the next Nix switch:

```nu
let domain = $"gui/(id -u | str trim)"
for label in [
    com.codethread.backup-notes # dev only
    com.codethread.syncengine
    com.codethread.cc-notify
    com.codethread.git-maintenance.hourly
    com.codethread.git-maintenance.daily
    com.codethread.git-maintenance.weekly
] {
    launchctl disable $"($domain)/($label)"
    if (do { launchctl print $"($domain)/($label)" } | complete).exit_code == 0 {
        launchctl bootout $"($domain)/($label)"
    }
}
# Wait for the old syncengine/gitwatch/fswatch processes to exit before applying.
```

Then run `mise -E dev run services:apply`. For a syncengine-only cutover, disable/unload only `com.codethread.syncengine`, wait for its children to exit, and run `mise -E <profile> run syncengine:apply`.

The disabled state persists across login/reboot. Still run `make system` afterwards to retire the old system generation's ownership; rebuilding an old configuration can re-enable its agents. Do not remove the old plist files before that switch: the old generation could notice missing files and recreate/re-enable them on activation.

## Operation

Inspect configuration state:

```nu
mise -E dev run services:status
mise -E dev bootstrap macos launchd-agents status --missing
```

`loaded` means launchd has the definition, not necessarily that the application is healthy. Scheduled Git jobs normally sit idle. Check the actual service and HTTP endpoint:

```nu
let domain = $"gui/(id -u | str trim)"
launchctl print $"($domain)/dev.mise.cc-notify"
let port = (open --raw ~/.local/state/cc-notify/port | str trim)
http get $"http://127.0.0.1:($port)/health"
```

Restart cc-notify after changing its source or upgrading Bun (an unchanged plist is not restarted by apply):

```nu
let domain = $"gui/(id -u | str trim)"
launchctl bootout $"($domain)/dev.mise.cc-notify"
```

Shutdown is asynchronous: wait for the old Bun process to exit and its port sentinel to disappear, then run `mise -E dev run services:apply`. Startup is asynchronous too; check the health endpoint once the new port sentinel appears rather than treating `loaded` as ready.

To run a scheduled maintenance job immediately:

```nu
let domain = $"gui/(id -u | str trim)"
launchctl kickstart $"($domain)/dev.mise.git-maintenance-hourly"
```

Logs retain the existing locations:

- cc-notify stdout/stderr: `~/.local/state/com.codethread.cc-notify/std.log`; application JSONL: cc-notify checkout `.logs/cc-notify.jsonl`.
- Git maintenance: `~/.local/state/com.codethread.git-maintenance/{hourly,daily,weekly}.log`.
- Backup-notes (dev): `~/.local/state/com.codethread.backup-notes/std.log`.
- Syncengine: `~/.local/state/com.codethread.syncengine/std.log` and per-target `<name>.log` files (`notes.log` for iCloud Notes).

Syncengine runs `/bin/bash -c` with the watcher body embedded in its generated plist; it does not invoke mise or a repository script at runtime. It still runs `gitwatch -r origin -R` for each entry in `~/sync` and for the iCloud Notes directory when present. It starts at login/load without KeepAlive, matching the old Nix policy. Its explicit PATH uses user scripts, Homebrew/coreutils, and macOS tools, with no Nix-store or Nix-profile paths. Git/SSH configuration and credentials remain user-owned. Logs are created before launchd opens stdout/stderr.

Inspect `launchctl print $"($domain)/dev.mise.syncengine"`, its child gitwatch/fswatch processes, and per-target logs; a loaded parent alone does not prove all watchers are healthy. Do not edit real repositories merely to test syncing: it commits and pushes automatically. Changing the inline watcher changes the plist, so `syncengine:apply` reloads it. After changing gitwatch alone, boot out `dev.mise.syncengine`, wait for its children to exit, then run `syncengine:apply`. An unchanged second apply should retain its PID.

The cc-notify job invokes a foreground mise task with the application's working directory, so Bun and Effect load its existing `.env`. `keep_alive = true` matches the previous unconditional restart policy. Login jobs do not depend on interactive shell PATH setup.

## Notes backup policy (dev only)

`backup-notes` runs at login/load and every 900 seconds. Its inline `/bin/bash` runner uses macOS Git and date, stages all vault changes, commits only when needed with a UTC timestamp, then pulls with rebase and pushes. Git/SSH configuration and credentials remain user-owned; applying the agent immediately runs a real backup.

`services:prepare` creates its state/log directory before launchd opens the log. Failures notify through `~/.local/bin/cc-notify` once per failure streak; the existing `failure-notified` sentinel is retained across migration and cleared after a successful push. Editing the runner changes the plist, so the next apply reloads it. Check `launchctl print` for `dev.mise.backup-notes`, its last exit code, and the log; idle between backups is normal. Do not run it against the real vault merely to validate the migration.

## Git maintenance policy

Each profile's `git_maintenance_repositories` is a newline-separated list; leading `~/` is supported and spaces in paths are preserved. Every run rebuilds a private state config atomically, skipping missing paths and non-repositories. Local repositories receive `maintenance.strategy=incremental` and `maintenance.auto=false`. The tracked global Git config is never rewritten. Failed writes fail the run visibly rather than falling back to stale registrations.

The schedule is unchanged:

- Hourly: 01:53 through 23:53.
- Daily: Monday through Saturday at 00:53.
- Weekly: Sunday at 00:53.

Each job runs `git for-each-repo --keep-going maintenance run --schedule=<frequency> --quiet`. There is no second Git-owned scheduler; do not also run `git maintenance start` for these repositories.

## Removal and verification

Deleting a declaration does not remove its installed agent. Remove the declaration, explicitly `launchctl bootout` its `gui/<uid>/dev.mise.<name>` target, and delete only its corresponding plist from `~/Library/LaunchAgents`.

Validation: `mise -E <profile> tasks validate --errors-only` for dev/work/personal/work-boot, `mise fmt --check`, Bash syntax checks, isolated temporary-repository maintenance checks, syncengine preparation and old-agent refusal checks, and `plutil -lint` on generated plists. After apply, check HTTP health, successful maintenance exit codes, no loaded old labels, and an unchanged second apply. Nix changes also require the normal flake build and `nix-smoke` checks; `nrs-check` was removed with Nix-owned Homebrew, so validate package changes with `mise bootstrap packages apply --dry-run` and `mise run packages:status`.
