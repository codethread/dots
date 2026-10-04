---
name: mise
description: >-
    Design, implement, or review mise configurations for development tools, environments, tasks, workstation bootstrap, Homebrew packages, dotfiles, macOS LaunchAgents, macOS/Linux profile layering, and container/CI usage. Use when adopting mise or debugging mise.toml.
---

# mise

Use mise as two related systems:

- `[tools]`, `[env]`, and `[tasks]` define project or user development environments.
- `mise bootstrap` converges workstation resources such as packages, files, repositories, dotfiles, shell setup, services, and macOS settings.

Do not imply that mise provides transactional rollback or complete operating-system management.

## Start from the required surface

```text
Need versioned CLI/runtime? --> [tools]
Need project command? ------> [tasks]
Need process environment? --> [env]
Need OS package/app? -------> [bootstrap.packages]
Need managed config file? --> [dotfiles] or [bootstrap.files]
Need machine convergence? --> mise bootstrap
Need macOS user service? --> [bootstrap.macos.launchd.agents]
```

Before editing, inspect the effective state:

```sh
mise --version
mise config
mise ls --current
mise doctor
```

Read the relevant vendored source before relying on remembered syntax. The checkout at `/Users/ct/dev/vendor/mise` is stable on this machine:

- [configuration](file:///Users/ct/dev/vendor/mise/docs/configuration.md)
- [configuration environments](file:///Users/ct/dev/vendor/mise/docs/configuration/environments.md)
- [dev tools](file:///Users/ct/dev/vendor/mise/docs/dev-tools/index.md)
- [lockfiles](file:///Users/ct/dev/vendor/mise/docs/dev-tools/mise-lock.md)
- [environments](file:///Users/ct/dev/vendor/mise/docs/environments/index.md)
- [tasks](file:///Users/ct/dev/vendor/mise/docs/tasks/index.md)
- [bootstrap](file:///Users/ct/dev/vendor/mise/docs/bootstrap.md)
- [macOS LaunchAgents](file:///Users/ct/dev/vendor/mise/docs/bootstrap/launchd.md)
- [user services](file:///Users/ct/dev/vendor/mise/docs/bootstrap/services.md)
- [dotfiles](file:///Users/ct/dev/vendor/mise/docs/dotfiles.md)
- [bootstrap packages](file:///Users/ct/dev/vendor/mise/docs/bootstrap/packages/index.md)
- [Homebrew packages](file:///Users/ct/dev/vendor/mise/docs/bootstrap/packages/brew.md)
- [Docker cookbook](file:///Users/ct/dev/vendor/mise/docs/mise-cookbook/docker.md)
- [trust](file:///Users/ct/dev/vendor/mise/docs/cli/trust.md)

Use <https://mise.jdx.dev/> when the vendored checkout may be stale. The config schema is <https://mise.jdx.dev/schema/mise.json>.

## Compose configuration deliberately

Prefer a checked-in TOML config. Add a hard `min_version` when syntax or behavior requires it.

```toml
min_version = "2026.9.0"

[tools]
node = "24"
bun = "latest"

[env]
NODE_ENV = "development"

[tasks.verify]
description = "Verify the managed environment"
run = "node --version && bun --version"
```

Use exact versions plus a committed `mise.lock` when reproducibility matters. Enable lockfile creation with `[settings] lockfile = true`, generate it with `mise lock`, and install with `mise install --locked`. A lockfile can still require network access and credentials.

Use the normal hierarchy rather than duplicating whole profiles:

- `~/.config/mise/config.toml`: shared user baseline.
- `~/.config/mise/config.personal.toml`, `config.work.toml`, `config.dev.toml`: global environment overlays.
- project `mise.toml`: repository baseline.
- project `mise.<env>.toml`: project overlay.
- `mise.local.toml` and `mise.<env>.local.toml`: uncommitted machine overrides.

For modular project configuration, use `.mise/conf.d/*.toml`: mise automatically loads these full-schema fragments, while root `mise.toml` and its profile overlays remain available. Prefer plain hyphenated names such as `cc-notify.toml`; environment-suffixed fragment names require the separate `env_conf_d` opt-in during its rollout. `config_root` for recognized project fragments remains the project root; `config_source` identifies the actual file. Keep an agent's full declaration in one fragment because duplicate agent names replace whole declarations. After splitting, verify `mise config`, task metadata, and unchanged generated agent state before applying.

Select overlays explicitly with `mise -E work …`, `MISE_ENV=work`, or a reviewed `.miserc.toml`. Multiple environments are ordered; the last wins. Run `mise -E work config` to verify the loaded files. Do not depend on automatic platform files unless `.miserc.toml` explicitly sets `auto_env = true`; the feature is currently disabled by default and in rollout.

Use `os` filters where that section supports them, or platform environment files such as `mise.macos.toml` and `mise.linux.toml` with `auto_env` explicitly configured. Do not assume every table accepts `os`.

Idiomatic files such as `.nvmrc` are disabled by default. Enable only the tools intended to read them; prefer explicit `mise.toml` declarations for a mise-owned setup.

## Choose the correct installation mechanism

| Requirement | Default choice | Notes |
| --- | --- | --- |
| Node or Bun | Core `node` / `bun` tool | Prefer over Homebrew for version switching. |
| npm CLI | `"npm:<package>"` in `[tools]` | Declare Node when the installed executable needs it. Scoped names must be quoted. |
| Standalone binary | Registry shorthand, then `aqua:`, then `github:` | Check with `mise registry <tool>` and `mise ls-remote <tool>`. |
| Homebrew formula/cask | `"brew:<formula>"` / `"brew-cask:<cask>"` in `[bootstrap.packages]` | Machine package, not a shimmed versioned tool. |
| Application dependency | Ecosystem manifest and package manager | Do not use the npm backend for project libraries. |

Do not introduce `ubi:`; it is deprecated. Avoid new asdf/vfox plugins when a curated or release backend exists.

The npm backend uses embedded aube by default. Review lifecycle-script or reputation failures rather than silently switching installers. Approve only the named build or dependency after inspection. Read [npm backend](file:///Users/ct/dev/vendor/mise/docs/dev-tools/backends/npm.md) for `allow_builds`, `allow_low_downloads`, and locking behavior.

Homebrew bootstrap installs directly into `/opt/homebrew` on Apple Silicon macOS and `/home/linuxbrew/.linuxbrew` on Linux; it does not require or invoke `brew` for `homebrew/core`. Add the prefix's `bin` directory to `PATH`. Use `[tools]` instead when per-project switching is the goal. Linux cask support is limited mostly to fonts; mark macOS-only casks with `os = ["macos"]`.

## Bootstrap workstations safely

Bootstrap is ordered convergence, not a transaction. Earlier phases remain applied if a later phase fails. Hooks and the `bootstrap` task run on every apply and must be repeatable.

For an existing machine:

```sh
mise trust
mise bootstrap --dry-run
mise bootstrap status --missing
mise bootstrap plan --detailed-exitcode
mise bootstrap --only packages,dotfiles,tools --dry-run
```

Review the plan, then apply the same narrowed selection without `--dry-run`. Do not use `--force-dotfiles`, package pruning, or broad `--yes` until the exact ownership and removal scope is understood. Pruning is subsystem-specific.

Use declarative resources when mise can inspect their state. Reserve `[tasks.bootstrap]` and hooks for setup that has no declarative representation. Dotfile conflicts should fail visibly; do not overwrite them by default.

For a repository bootstrap, use `mise bootstrap --from <url>`. Use `--adopt <url>` only when the repository is intended to become the global mise configuration or tracked-history source. Review remote configuration before trusting it.

## Deploy macOS services

For macOS-only services, prefer `[bootstrap.macos.launchd.agents]` when calendar scheduling, explicit arguments, or log paths matter. mise creates native launchd jobs; no extra supervisor or shell activation is needed. `[bootstrap.services]` with `scope = "user"` is another option, but do not declare the same name in both tables.

Read [macOS service deployment](references/macos-services.md) before migrating or applying jobs. It covers the verified bootstrap-order trap, stable executable/config paths, credentials, old-service handoff, and health checks. The crucial ordering: **prepare tools, checkout, dependencies, and log directories before applying raw LaunchAgents**. A final bootstrap task runs too late.

## Use noninteractive execution in automation

Use activation only in interactive shell startup:

```sh
eval "$(mise activate zsh)"
```

Use `mise exec -- <command>` or `mise run <task>` in scripts, containers, editors, and CI. Prefer the explicit `mise run` spelling in documentation so task names cannot be confused with future CLI commands.

For conventional OCI builds, follow the [Docker cookbook](file:///Users/ct/dev/vendor/mise/docs/mise-cookbook/docker.md):

1. Install mise into an explicit shared directory.
2. Copy `mise.toml`, `mise.lock`, and install-time inputs before the rest of the source for layer caching.
3. Run `mise install --locked` when a lockfile is committed.
4. Put mise shims on `PATH`, but use `mise exec` in `RUN`, `CMD`, and CI.
5. Use `mise install --system` when a runtime-mounted home directory would hide image-built installs.
6. Exclude credentials and dotenv files from the build context.

`mise oci` is experimental, Linux-host/target-architecture constrained, and not the default for a portable proof of concept.

## Verify observable behavior

Validate syntax and task metadata before expensive installation when possible:

```sh
mise config
mise tasks validate --errors-only
mise lock --dry-run
mise install
mise ls --installed
mise exec -- <tool> --version
```

For bootstrap work, also run the relevant `status`, `--dry-run`, and post-apply verification commands. Invoke a direct bootstrap `--dry-run` for read-only planning: wrapping it in `mise run` can install declared tools before the task executes. For services, inspect process/application health as well as loaded definitions, then verify an unchanged second apply does not restart the process. In containers, build with the requested engine and execute every promised CLI, not merely `mise ls`.

Fail loudly on malformed config, missing required tools, unreviewed trust decisions, and unsupported platform packages. For a proof of concept, do not add retries, fallback installers, or broad exception handling; report the concrete limitation instead.

## Keep these distinctions visible

- Activation changes an interactive shell; `exec` scopes one child process.
- `[tools]` installs versioned development tools; `[bootstrap.packages]` installs host packages.
- A version request such as `"24"` is not an exact pin; the lockfile records resolution.
- `mise trust --all` is a security decision, not a routine fix for automation.
- Secrets placed in config or resolved OCI image environment are inspectable; inject secrets at runtime.
- `mise bootstrap --dry-run` does not prove an apply will be transactional or that external downloads will succeed.
