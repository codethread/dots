# Mise-managed macOS services

## Scope and ownership

The project mise configuration owns four user LaunchAgents: cc-notify and hourly/daily/weekly Git maintenance. macOS launchd supervises them; mise renders and applies their definitions. This is deliberately project-scoped, with no shell activation, global mise config, or extra supervisor.

- `mise.toml`: pinned tools and shared prepare/apply/status tasks.
- `.mise/conf.d/cc-notify.toml`: foreground cc-notify task and its LaunchAgent.
- `.mise/conf.d/git-maintenance.toml`: hourly/daily/weekly maintenance LaunchAgents.
- `mise.dev.toml`: notes vault maintenance and cc-notify.
- `mise.work.toml`: deals-light-ui maintenance and cc-notify.
- Personal and work-boot machines do not apply these services. Select `dev` or `work` explicitly; a missing overlay cannot render the required profile variables.
- mise also owns macOS host packages: `.mise/conf.d/packages.toml` plus the profile overlays (`mise.dev.toml`, `mise.work.toml`, `mise.personal.toml`, `mise.work-boot.toml`). `packages:apply` installs those packages, then user-prefix `@playwright/cli` and the profile's VS Code extensions; `packages:status` reports host state. Applying packages never prunes or upgrades; formula upgrades are explicit via `mise bootstrap packages upgrade --manager brew`.
- `boot/boot.sh` installs Homebrew and then mise (`brew install mise`); the stable service executable is `/opt/homebrew/bin/mise`, not a Nix-store path. Nix no longer declares or upgrades Homebrew packages. This matches the repository's Apple Silicon hosts.
- mise provides pinned Bun 1.4.2 through `[tools]` for cc-notify. Other Nix-managed runtimes are unchanged.
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

Use `work` instead of `dev` on the full work profile. Preparation clones cc-notify if absent, installs its frozen Bun dependencies, checks required credential names without printing values, creates state/log directories, and refreshes filtered Git registrations. The credentials remain in cc-notify's local `.env`; they are not copied into tracked TOML or plists. Missing SSH access, credentials, or failed setup stops the apply before any new agent is loaded.

The `services:apply` task runs preparation first. Do **not** substitute bare `mise bootstrap`: its raw LaunchAgents phase precedes tool installation and the final bootstrap task. The direct dry-run command above does not install tools; `mise run` tasks may install their declared tools before executing.

These are per-user agents: apply in a logged-in macOS GUI session, without sudo. They run while that user is logged in, not as boot-time system daemons.

Host packages are separate from services: `boot.sh` applies them with `mise -C "$DOTFILES" -E <mise-profile> run packages:apply` before the Nix switch. Preview host package changes with `mise -E dev bootstrap packages apply --dry-run`; applying packages never prunes or upgrades existing packages, so upgrade formulae explicitly with `mise -E dev bootstrap packages upgrade --manager brew`.

## Moving an existing Nix installation

1. Prepare the mise services and preview their definitions.
2. Run `make system` with this updated checkout. It keeps the Homebrew-installed mise and removes the old Nix-owned service definitions.
3. Run `mise -E dev run services:apply` (or `work`). The task refuses to apply while any old agent is still loaded.
4. Check cc-notify's health and the three maintenance jobs.

When a system switch must wait for sudo authentication, the user jobs can be cut over separately after successful preparation. Disable **and** unload the old labels, preserving their plist files until the next Nix switch:

```nu
let domain = $"gui/(id -u | str trim)"
for label in [
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
mise -E dev run services:apply
```

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

The cc-notify job invokes a foreground mise task with the application's working directory, so Bun and Effect load its existing `.env`. `keep_alive = true` matches the previous unconditional restart policy. Login jobs do not depend on interactive shell PATH setup.

## Git maintenance policy

Each profile's `git_maintenance_repositories` is a newline-separated list; leading `~/` is supported and spaces in paths are preserved. Every run rebuilds a private state config atomically, skipping missing paths and non-repositories. Local repositories receive `maintenance.strategy=incremental` and `maintenance.auto=false`. The tracked global Git config is never rewritten. Failed writes fail the run visibly rather than falling back to stale registrations.

The schedule is unchanged:

- Hourly: 01:53 through 23:53.
- Daily: Monday through Saturday at 00:53.
- Weekly: Sunday at 00:53.

Each job runs `git for-each-repo --keep-going maintenance run --schedule=<frequency> --quiet`. There is no second Git-owned scheduler; do not also run `git maintenance start` for these repositories.

## Removal and verification

Deleting a declaration does not remove its installed agent. Remove the declaration, explicitly `launchctl bootout` its `gui/<uid>/dev.mise.<name>` target, and delete only its corresponding plist from `~/Library/LaunchAgents`.

Validation: `mise -E dev tasks validate --errors-only`, `mise -E work tasks validate --errors-only`, `mise fmt --check`, Bash syntax checks, isolated temporary-repository maintenance checks, and `plutil -lint` on generated plists. After apply, check HTTP health, successful maintenance exit codes, no loaded old labels, and an unchanged second apply. Nix changes also require the normal flake build and `nix-smoke` checks; `nrs-check` was removed with Nix-owned Homebrew, so validate package changes with `mise bootstrap packages apply --dry-run` and `mise run packages:status`.
