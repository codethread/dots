# Botlake operations

Homebrew owns `botlake` and `bl` through `codethread/botlake/botlake`. Mise/Pitchfork owns the single `botlake-supervisor` daemon and its login startup. **Do not enable the Homebrew service** alongside it.

Bootstrap's `pre-repos` hook runs Homebrew's own tap/install commands before preparing repository dependencies and registering daemons. This is the sole package installer: mise 2026.10.4's native package resolver misroutes the formula's cross-tap Bun dependency. `HOMEBREW_NO_INSTALL_UPGRADE=1` keeps upgrades explicit. Botlake therefore does not appear in native mise package status/upgrade; do not prune Homebrew packages through mise.

The supervisor, readiness check, lake startup hook, and dev/work UI use `/opt/homebrew/opt/botlake/bin`, not development-checkout binaries. Homebrew builds the tagged formula release, not the working source tree. The source checkout remains available for development, its lake, and Pi's identity plugin; bootstrap only installs its frozen Bun dependencies. Do not use the source checkout's `mise run install` to update the workstation CLI.

Core and extensions remain pinned in each lake's Bun workspace. A Homebrew CLI upgrade does not upgrade those packages.

## Inspect and start

Run mise commands from the durable dots checkout:

```sh
cd ~/dev/dots
mise daemons status botlake-supervisor
botlake status
botlake lake list
type -a botlake bl
```

Both CLIs on the ordinary shell PATH should resolve through Homebrew, without old `~/.local/bin` binaries or mise shims shadowing them. Daemon commands also use the stable Homebrew opt path explicitly, so upgrading the formula does not require changing their declaration.

```sh
cd ~/dev/dots
./boot/start-botlake.sh
```

This starts the managed supervisor and dots lake. It does not take over an externally managed supervisor. Dev/work additionally run `botlake-ui`, which depends on the supervisor and starts the Botlake source checkout's lake.

## Upgrade and restart

**A supervisor restart terminates all its managed processes, including agents, and clears its active lakes.** Arrange a quiet window first. A lake-only restart is different: use `botlake lake restart --workspace /absolute/workspace` for lake configuration changes, without replacing the supervisor.

For a CLI upgrade, use this Bash recipe in one shell. It records the currently active lakes and starts them again after the supervisor is replaced:

```bash
set -euo pipefail
cd ~/dev/dots
lakes="$(botlake lake list)"
brew upgrade codethread/botlake/botlake
mise daemons restart botlake-supervisor
printf '%s\n' "$lakes" | jq -r '.[].path' | while IFS= read -r workspace; do
  botlake lake start --workspace "$workspace"
done
botlake status
```

For a restart without an upgrade, omit the `brew upgrade` line. This restores lakes, not terminated agent sessions or other processes. If a lake fails to start, fix its reported error and retry its `botlake lake start --workspace /absolute/workspace` command; the saved `$lakes` value remains available in that shell.

On dev/work, refresh the UI after the supervisor handoff:

```sh
mise daemons restart botlake-ui
curl --fail http://127.0.0.1:4174/api/health
```

Use `mise daemons logs botlake-supervisor` (or `botlake-ui`) for service diagnostics. `brew services restart` is not the restart command for this setup.
