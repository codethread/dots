# Verification

Run checks for the component that changed. Record native or user integration gaps instead of treating a neighboring suite as evidence.

## Documentation

Install the locked root workspace once when `node_modules` is absent or `bun.lock` changed:

```sh
bun install --frozen-lockfile
```

After changing Markdown anywhere, including root or nested `AGENTS.md`, run the locked read-only formatter check:

```sh
qlock exec --lock /tmp/agent-cpu.lock -w 600 -- bun run fmt:check
```

This checks formatting without rewriting the immutable root README. Review links and commands against source because formatting cannot prove them.

## Oven

After changing `oven/`, its tests, or the root JavaScript workspace, run:

```sh
qlock exec --lock /tmp/agent-cpu.lock -w 600 -- mise run build
```

This full gate installs frozen workspace dependencies, runs tests and type checks, applies Oven fixes, and synchronizes generated docs. Review the resulting diff because the gate is intentionally mutating.

## Neovim

After changing `config/nvim/lua/codethread/config/options.lua`, its filetype rules, or `tests/nvim/`, run:

```sh
mise run --skip-tools test:nvim-smoke
```

The required `--skip-tools` prevents focused execution from installing unrelated discovered mise tools. The task requires `nvim`, `curl`, `shasum`, and network access to GitHub; it downloads the commit-pinned `mini.test`, verifies its digest, and removes it with the disposable test state.

The smoke isolates `HOME`, every XDG root, `TMPDIR`, and `NVIM_LOG_FILE`; supplies explicit runtime paths; starts child Neovim with `--clean`; loads only the selected options module; and proves the Bun-shebang TypeScript contract. Successful module loading fails on configuration errors. Lazy, plugins, interactive UI, and full production startup remain untested.

Parse every changed Lua file through an absolute path without loading user configuration:

```sh
file="$(pwd)/config/nvim/lua/path/to/changed.lua"
nvim --clean --headless -l /dev/stdin "$file" <<'EOF'
local _, err = loadfile(arg[1])
if err then io.stderr:write(err .. '\n'); os.exit(1) end
EOF
```

This proves syntax only. No broad isolated Neovim suite exists.

## Shell environment and helpers

Parse each changed shell file with its actual interpreter:

```sh
bash -n "$(pwd)/boot/changed.sh"
zsh -n "$(pwd)/home/.local/bin/changed-zsh-helper"
```

Shared `config/env/*.sh` files declare POSIX sh, Bash, and Zsh compatibility, so parse and source each changed file under all three shells with a temporary `HOME` and the fixture environment it requires:

```sh
sh -n "$(pwd)/config/env/base.sh"
bash -n "$(pwd)/config/env/base.sh"
zsh -n "$(pwd)/config/env/base.sh"
```

Parsing proves syntax, not startup semantics. No committed broad fixture covers interactive startup or shell workers for Git maintenance, backup, and sync. Exercise those workers with temporary repositories and local bare remotes before involving a scheduler; only real endpoints and service loads require operator timing. `git-maintenance` and notes backup hardcode `/usr/bin/git`, bypassing the declared Homebrew Git; an unaccepted Apple developer-tools license can therefore stop their fixture before worker logic runs.

## Tmux and TUI configuration

`tmux source-file -n` still requires a server. Create a disposable private server with no user config, parse on its explicit socket, and clean it on success or failure:

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

The noninteractive session avoids starting a live user shell or loading user plugins. Use an application's own validation command for other checked-in TUI configs. Layout behavior, terminal capabilities, plugin loading, and key interaction still require a user session.

## Native links and settings

After changing link declarations, templates, or managed settings, run read-only inspection:

```sh
mise tasks validate --errors-only
mise dot diff
mise dot status --json
mise bootstrap --dry-run
mise bootstrap status
```

For Oven entrypoint links, run the existing temporary-home native apply fixture:

```sh
cd oven
mise exec -- bun test tests/native-links.test.ts
```

That test proves extensionless links, dependency loading, and CLI contracts through a real `mise dot apply` isolated from the real home. Similar temporary-home group and structured-merge fixtures are possible, but no broad native-links/settings suite exists yet. Template evaluation can execute trusted template functions; applying to the real home or reloading applications requires explicit operator authorization.

## Agent assets and external handoffs

After changing Claude, Codex, Pi, hook, or agent-facing assets, run the Markdown check and the owning executable test where one exists; Oven hook implementations are covered by `mise run build`. Confirm configured symlink counterparts resolve with `test -e <path>` rather than assuming discovery from a filename.

There is no repeatable fixture for vendor installers, authentication, remote repositories, notification delivery, Botlake startup, or the private workfiles handoff. Validate their local syntax/configuration first, then require user-approved native integration with real credentials and services.

After changing `.botlake/` configuration, deliberately schedule the shared active-lake restart when other users will not be disrupted, then inspect the loaded snapshot:

```sh
botlake lake restart
botlake lake info
```

These commands affect the machine-shared active lake rather than an isolated repository process; documentation review does not require running them.

## Themes and desktop integration

Theme worker logic and temporary state behavior are covered by the focused Oven test:

```sh
cd oven
mise exec -- bun test tests/theme.test.ts
```

This does not prove Kitty, Rex, Neovim, macOS appearance, or desktop reloads. Visual results and live application forwarding require a user session; Dock, Finder, and SystemUIServer restarts belong only to an authorized native bootstrap.

## Worker logic and schedulers

Run the owning Oven test for a changed worker implemented there, or `mise run build` when several workers or shared modules changed. For declarative daemon, cron, or LaunchAgent changes, run:

```sh
mise tasks validate --errors-only
mise bootstrap --dry-run
mise bootstrap status
```

These commands prove parsing and reported convergence only. They do not execute workers, advance schedules, load services, inspect login persistence, or prove retries and environment under launchd; those require a focused foreground invocation where supported and user-approved native service verification otherwise.

## Packages and profiles

After changing package declarations, profile overlays, tools, or bootstrap ordering, validate each affected profile without applying it:

For shared mise configuration or tool changes, run every profile:

```sh
for profile in dev personal work; do
  mise -E "$profile" tasks validate --errors-only
  mise -E "$profile" bootstrap packages apply --dry-run
  mise -E "$profile" bootstrap --dry-run
  mise -E "$profile" bootstrap status
done
```

For a change isolated to one profile overlay, run the same sequence only for that profile. Package availability, Homebrew behavior, privileged files, and profile-specific external integrations require a real Mac; this guide makes no Linux execution claim.

## Mise and bootstrap

Native dry-run previews phases but prints hooks instead of executing them, and it does not recursively plan workfiles. Full bootstrap is intended to be rerunnable but remains side-effectful: `boot/setup.sh` performs external installs and builds, raw services load later, sync and notes jobs can push backups, defaults restart desktop processes, post-tools can start Botlake, and profile final hooks can change Tailscale serving or invoke workfiles.

Current verification gaps:

- `boot/boot.sh`, `boot/setup.sh`, `boot/workfiles.sh`, and vendor integrations have no complete dry-run fixture.
- An existing workfiles checkout must be inspected with its own `make plan` or `make status`; dots dry-run does not recurse into it.
- Service load, PAM convergence, cold installation, reboot behavior, and real desktop effects need a user-approved Mac. Reserve a macOS VM for privileged or cold-install/reboot proof.
