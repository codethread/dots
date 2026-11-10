---
name: mise
description: >-
    Design, implement, or review mise configurations for development tools, environments, tasks, workstation bootstrap, Homebrew packages, dotfiles, macOS LaunchAgents, macOS/Linux profile layering, and container/CI usage. Use when adopting mise or debugging mise.toml.
---

# mise

Use mise's native surfaces before adding scripts:

```text
Versioned CLI/runtime? --> [tools]
Project command? ------> [tasks]
Process environment? --> [env]
Host package/app? -----> [bootstrap.packages]
User-owned config? ----> [dotfiles] / [dotfile_groups]
Privileged file? ------> [bootstrap.files]
Background process? ---> [bootstrap.services] or platform service
Machine convergence? --> mise bootstrap
```

Mise bootstrap is ordered convergence, not a transaction or a complete operating-system manager.

## Establish the version and effective config

Run from the project directory so early `.miserc.toml` discovery settings apply:

```sh
mise --version
mise config
mise ls --current
mise doctor
mise tasks validate --errors-only
```

Treat the installed CLI's `--help` and behavior as version-specific evidence. This repository currently requires mise 2026.10.4+. The local checkout at `/Users/ct/dev/vendor/mise` is useful source material only after checking its `Cargo.toml` version and revision; it may be older or newer than the installed binary.

Prefer current primary sources:

- [configuration and hierarchy](https://mise.jdx.dev/configuration.html)
- [config environments](https://mise.jdx.dev/configuration/environments.html)
- [tasks](https://mise.jdx.dev/tasks/)
- [bootstrap and run order](https://mise.jdx.dev/bootstrap.html)
- [dotfiles](https://mise.jdx.dev/dotfiles.html)
- [dotfile groups](https://mise.jdx.dev/dotfiles/groups.html)
- [dotfile edits](https://mise.jdx.dev/dotfiles/edits.html)
- [packages](https://mise.jdx.dev/bootstrap/packages/)
- [npm backend](https://mise.jdx.dev/dev-tools/backends/npm.html)
- [user services](https://mise.jdx.dev/bootstrap/services.html)
- [macOS LaunchAgents](https://mise.jdx.dev/bootstrap/launchd.html)
- [schema](https://mise.jdx.dev/schema/mise.json)
- [releases](https://github.com/jdx/mise/releases)

Current website documentation can describe releases newer than the installed binary. Confirm materially important syntax against the installed CLI or a disposable config before requiring it.

## Compose config deliberately

Use checked-in TOML and set `min_version` to the oldest release actually needed by the config:

```toml
min_version = "2026.10.4"

[tools]
node = "24"

[env]
NODE_ENV = "development"

[tasks.verify]
run = "node --version"
```

Use exact versions plus a committed `mise.lock` when reproducibility matters. A request such as `node = "24"` is a moving prefix; the lockfile records its resolution. Validate locked installs with `mise install --locked`.

### Discovery and profiles

Mise combines system config, global config, parent project config, and the nearest project config; later and nearer files win according to the documented hierarchy. Use:

- `mise.toml` for the shared project baseline.
- `mise.<env>.toml` for a selected project environment.
- `mise.local.toml` and `mise.<env>.local.toml` for uncommitted overrides.
- `~/.config/mise/config.toml` and `config.<env>.toml` for global equivalents.
- `mise/conf.d/*.toml`, `.mise/conf.d/*.toml`, or `.config/mise/conf.d/*.toml` for full-schema fragments.

Select environments with `mise -E work …`, `MISE_ENV=work`, or `.miserc.toml`. With several environments, later names win among files of the same kind; local files still outrank shared environment files. Verify with `mise -E work config`.

Discovery settings such as `env`, `auto_env`, and `env_conf_d` must be in `.miserc.toml` or the process environment because `mise.toml` loads too late. In 2026.10.4, platform environments and environment-suffixed `conf.d` fragments remain opt-in. Prefer hyphenated fragment names; dotted fragment names are in a staged migration.

A single-file `conf.d/*.toml` fragment keeps the surrounding project's `config_root`. A `conf.d/<name>/mise.toml` folder fragment is its own config root. Relative sources, task directories, and `{{ config_root }}` follow that distinction.

Layering is section-specific, not a recursive TOML merge. Tool and environment values merge by their documented keys; tasks, portable services, and LaunchAgents with the same name are documented as higher-precedence replacements of the declaration. Check the installed release's documentation or effective output for other named sections, including experimental daemons, before relying on replacement or field-wise merge behavior.

## Choose native ownership

| Requirement | Native owner | Guidance |
| --- | --- | --- |
| Node, Bun, Python, or another versioned runtime | `[tools]` | Prefer core/registry backends over Homebrew when version switching matters. |
| Ordinary user CLI published to npm | `"npm:<package>"` in `[tools]` | Appropriate for tools such as Playwright when mise should own the version; add Node when the CLI needs it at runtime. |
| CLI with an official vendor installer/updater | repository bootstrap integration | Preserve the declared vendor owner rather than replacing it with `npm:` merely because the implementation uses Node. In this repository, `mise-llm` owns Claude, Codex, Pi, and Pi-Bolt installation and updates. |
| Project library | ecosystem manifest | Keep application dependencies in `package.json`, not the mise npm backend. |
| Host formula or cask | `[bootstrap.packages]` | Use `brew:` / `brew-cask:` for machine packages. |
| User config tree | `[dotfiles]` or `[dotfile_groups]` | Prefer native links, copies, templates, groups, manifests, and edits. |
| Cross-platform user process | `[bootstrap.services]` | Set `scope = "user"`; use `requires_tools = true` when it invokes `[tools]`. |
| macOS-specific schedule or launchd feature | `[bootstrap.macos.launchd.agents]` | Use native argument vectors and launchd fields. |

The npm backend uses embedded aube by default and does not need npm or Node to install a package, but most Node CLIs still need Node to execute. Use it only where mise is the selected owner. Preserve official vendor installers where the repository assigns them ownership; do not infer ownership from the package ecosystem. Review and narrowly approve supply-chain failures with `allow_builds`, `allow_low_downloads`, `allow_exotic_deps`, or `trust_policy_excludes` only after inspecting the named package/version.

## Use native dotfile deployment

For a few explicit targets, use `[dotfiles]`. For a source tree with selectable machine/profile sets, use `[dotfile_groups]` and select groups with `[bootstrap].dotfile_groups`.

```toml
[dotfile_groups.config]
root = "config"
target = "~/.config"
mode = "symlink-each"
manifest = "git"

[bootstrap]
dotfile_groups = ["config"]
```

Key semantics verified in 2026.10.4:

- `symlink` links one target to one source; `symlink-each` walks a directory and manages entries beneath an existing target tree.
- Directory `copy` is additive; `symlink-each` reconciles links it recorded while preserving unmanaged neighbors.
- `manifest = "git"` uses `git ls-files` from a directory source and is valid with directory `copy` or `symlink-each`. Only indexed paths are selected; `exclude` filters them further.
- Glob sources require corresponding target wildcards so each source maps uniquely. Installed 2026.10.4 maps captures positionally and can change the suffix: `source = "scripts/*.ts"` with target `"~/.local/bin/*"` deploys extensionless names.
- Removing an ordinary declaration does not remove its deployed path. Run `mise dot unapply` while it is still declared. Group orphans can be removed with reviewed `mise dot apply --prune`.
- Existing conflicting real paths block symlink deployment unless `--force` is explicitly used. Copy and template entries can replace changed content without `--force`.

Preview and inspect with:

```sh
mise dot diff
mise dot apply --dry-run
mise dot status --json
```

Do not introduce a custom linker, manifest walker, or profile-switch cleanup when groups, Git manifests, and native reconciliation express the ownership.

### Structured edits

On installed 2026.10.4, use a merge edit when mise owns keys inside application-written JSON, TOML, or YAML:

```toml
[dotfiles."~/.config/codex/config.toml/shared"]
source = "templates/codex-config.toml"
merge = true
```

The final path segment is the edit id, not part of the target path. In 2026.10.4, object/table keys merge recursively, target-only keys remain, and arrays from the source replace the target array wholesale. Removing a key from the source does not delete that target key. Edits are one-way deployment; application changes do not sync back to the source. `mise dot status --json` reports them under `edits`.

Installed 2026.10.4 accepts only `merge = true`; it rejects `merge = "missing"`, JSONC targets, INI targets, and the newer `format` override. Those capabilities appear in newer website documentation/schema and require a coordinated minimum-version upgrade plus disposable verification before use. On 2026.10.4, use a whole-file copy/template when the entire file is owned, or another native edit form when the format supports it. Preview the target with `mise dot diff <target-or-edit>` before apply.

## Preserve bootstrap ordering

Read `mise bootstrap --help` and the [documented run order](https://mise.jdx.dev/bootstrap.html#how-it-runs) before moving setup between phases. In 2026.10.4 the important sequence is:

1. pre-package files and `pre-packages`
2. built-in packages; `post-packages` runs here when no package-plugin package is active
3. ordinary files and services not requiring tools
4. repositories and dotfiles
5. shell/defaults/LaunchAgents/user settings
6. `pre-tools`, tools, `post-tools`
7. plugin packages; when any are active, installed 2026.10.4 defers `post-packages` until after them; then services with `requires_tools = true`
8. `bootstrap` task and `final` hook

Hooks and the bootstrap task run on every bootstrap; make them repeatable. Earlier changes remain when a later phase fails.

Use declarative resources when mise can inspect their state. Place each dependency in the earliest native phase that satisfies its consumer: pre-package files for package prerequisites, repositories before dotfiles, declarative directories before services, and `requires_tools = true` for portable user services that invoke `[tools]`. A final `bootstrap` task is too late to prepare a raw LaunchAgent because LaunchAgents load before tools and the task. Remove custom preparation hooks when native resources or correctly ordered services make them redundant.

For this repository, retain the PAM/system prerequisite checks because they protect privileged file convergence, not because they are existing hooks. Re-evaluate every other preparation hook against the phase graph and replace stopgaps with native resources where the observable ordering remains correct.

## Deploy services

Read [macOS service deployment](references/macos-services.md) before changing service ownership. Launchd jobs receive a minimal environment, not interactive shell activation. Use durable absolute executable paths, explicit environment, and a durable checkout/config root.

Prefer `[bootstrap.services]` for one foreground command across platforms. Prefer raw LaunchAgents for calendar schedules, queue directories, launch events, process type, or explicit launchd controls. A name cannot appear in both because both own `dev.mise.<name>`.

Deleting a declaration leaves the installed user service or LaunchAgent in place. Remove it explicitly with `mise bootstrap services remove <name>` or keep a portable user service declaration with `state = "absent"` for a managed retirement.

## Validate without accidental host mutation

Use direct read-only commands rather than wrapping them in a task that may auto-install tools:

```sh
mise tasks validate --errors-only
mise bootstrap --dry-run
mise bootstrap status
mise bootstrap plan --detailed-exitcode
mise dot diff
mise dot status --json
```

`bootstrap plan` covers declarative resources only; it does not cover dotfiles, repos, shell activation, macOS defaults, LaunchAgents, tools, hooks, or the bootstrap task. Use the full dry run for those. To verify phase placement on a specific release, inspect the ordered headings from that installed binary's `mise bootstrap --dry-run`; do not promote newer website wording to installed-version evidence. Dotfile templates and some bootstrap file templates can execute trusted template functions during status/diff; read the source before treating those commands as inert.

For automation and services, use `mise exec -- <command>` or `mise run <task>`. Reserve `eval "$(mise activate …)"` for interactive shell startup.

Fail visibly on malformed config, missing required tools, unsupported packages, or unreviewed trust decisions. Do not hide a native limitation behind fallback installers, compatibility wrappers, or custom deployment state.
