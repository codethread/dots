# Verification

Documentation-only edits need the documentation checks. Real-home applies, service operations, and host bootstrap require explicit user authorization.

## Documentation

```sh
qlock exec --lock /tmp/agent-cpu.lock -w 180 -- bun run fmt:check
```

Check local links and heading anchors, instruction symlinks, and protected files' byte equality.

## Oven

For Oven or root JavaScript workspace changes:

```sh
qlock exec --lock /tmp/agent-cpu.lock -w 180 -- mise run build
```

This gate installs frozen dependencies, tests, typechecks, applies fixes, and regenerates Oven documentation; review its diff.

## Neovim

For `config/nvim/lua/codethread/config/options.lua`, its filetype rules, or `tests/nvim/`:

```sh
mise run --skip-tools test:nvim-smoke
```

`--skip-tools` avoids unrelated tool installs. Requires `nvim`, `curl`, `shasum`, and GitHub access for the commit-pinned, digest-checked `mini.test` download. Disposable HOME/XDG/temp/log state and clean child Neovim isolate the selected options module. Coverage: module loading and Bun-shebang TypeScript detection; Lazy, plugins, full startup, and UI remain untested.

For every changed Lua file, substitute its absolute path:

```sh
file="$(pwd)/config/nvim/lua/path/to/changed.lua"
nvim --clean --headless -l /dev/stdin "$file" <<'EOF'
local _, err = loadfile(arg[1])
if err then io.stderr:write(err .. '\n'); os.exit(1) end
EOF
```

## Shell environment and workers

For shared environment changes:

```sh
for shell in sh bash zsh; do
  "$shell" -n config/env/base.sh
  "$shell" -n config/env/interactive.sh
done
```

No committed fixture covers profile/override inheritance or login/child startup. Git maintenance, backup, and sync workers can use temporary repositories and local bare remotes; fixed paths, live sockets, and network calls need separate isolation. Git maintenance and notes backup hardcode `/usr/bin/git`; an unaccepted Apple tools license blocks those fixtures.

## Tmux and TUI configuration

Tmux parsing requires a server. Use a private socket and noninteractive child:

```sh
(
  set -e
  state="$(mktemp -d "${TMPDIR:-/tmp}/dots-tmux.XXXXXX")"
  trap 'tmux -S "$state/tmux.sock" kill-server 2>/dev/null || true; rm -rf "$state"' EXIT
  mkdir -p "$state/home"
  HOME="$state/home" tmux -S "$state/tmux.sock" -f /dev/null new-session -d 'sleep 300'
  HOME="$state/home" tmux -S "$state/tmux.sock" source-file -n "$(pwd)/config/tmux/tmux.conf"
)
```

Layouts, plugins, terminal capabilities, and key interaction need a user session.

## Native links and settings

Inspect changed destinations or edit IDs (Codex shown). Read template functions before rendering: they may execute.

```sh
mise dot diff "$HOME/.config/codex/config.toml/shared"
mise dot status --json "$HOME/.config/codex/config.toml/shared"
```

For Oven entrypoint links, the existing fixture applies explicit command targets into a temporary home and tests dependency loading and CLI contracts:

```sh
(cd oven && bun test tests/native-links.test.ts)
```

Temporary-home group and structured-merge fixtures are feasible; neither has a committed broad suite.

## Provisioning and schedulers

For shared provisioning changes—packages/tools, host resources, repositories, or phase ordering—inspect every profile. If confined to one overlay, run only its profile:

```sh
for profile in dev personal work; do
  mise -E "$profile" tasks validate --errors-only
  mise -E "$profile" bootstrap packages apply --dry-run
  mise -E "$profile" bootstrap --dry-run
  mise -E "$profile" bootstrap status
done
```

For scheduler-only changes, select each affected `profile` and run:

```sh
mise -E "$profile" tasks validate --errors-only
mise -E "$profile" bootstrap --dry-run
mise -E "$profile" bootstrap status
```

Launchd environments, retries, schedules, and login persistence lack isolated integration coverage.

## Agent assets and external handoffs

Executable hooks use their owning tests; Oven hooks require the Oven gate. No repeatable integration fixture covers vendor installers, authentication, remote repositories, notifications, Botlake startup, or private workfiles.

For lake config or shared-extension changes, coordinate an authorized shared-lake restart, then inspect the loaded snapshot:

```sh
botlake lake restart
botlake lake info
```

## Themes and desktop integration

For theme worker logic:

```sh
(cd oven && bun test tests/theme.test.ts)
```

Kitty/Rex/Neovim visuals, desktop appearance, and live forwarding require a user session.

## Bootstrap gaps

Native dry-run prints hooks without executing them and does not recurse into workfiles. `boot/boot.sh`, `boot/setup.sh`, `boot/workfiles.sh`, and vendor integrations lack complete dry-run fixtures. Inspect an existing workfiles checkout separately with its `make plan` or `make status`.

Real bootstrap installs/builds external projects, loads services, can push backups, restarts desktop processes, starts Botlake, and may change Tailscale serving or invoke workfiles.

Use a user-approved disposable Mac/VM for cold installation, privileged/PAM convergence, service loading, and reboot persistence. Homebrew/package availability and macOS integration need a real Mac; Touch ID, TCC, clipboard, and interactive desktop/session behavior need user verification.
