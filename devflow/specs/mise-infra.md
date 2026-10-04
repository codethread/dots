# Mise Infrastructure Specification

- Document ID: SPEC-006
- **Status:** Implemented
- **Last Updated:** 2026-10-04

## Ownership

Mise owns the Apple Silicon macOS workstation: packages, managed files, repositories, defaults, user settings, and LaunchAgents. Dotty links repository assets and renders the structured Codex template. Shells activate mise natively.

## Configuration locations

There are two configuration scopes—project bootstrap and global tools—not four independent systems. The extra locations organize project fragments and reusable sources.

| Location | Loading and purpose |
| --- | --- |
| `mise.toml`, `mise.<profile>.toml` | Project entrypoints: mise loads the base and selected profile. The base owns shared bootstrap resources, hooks, and `llm:update`; profiles add machine-specific packages, variables, and resources. |
| `.mise/conf.d/*.toml` | Reusable entrypoints only: `tools.toml`, `tools.dev.toml`, and `tools.work.toml` symlink to global tool sources; `services.dev.toml` and `services.work.toml` symlink to the shared dev/work service source. Environment-suffixed entries load only for the selected environment with `env_conf_d` enabled. |
| `.mise/dev-work-services.toml` | Reusable service source, not automatically discovered. The `.mise/conf.d/services.dev.toml` and `.mise/conf.d/services.work.toml` symlinks load its cc-notify and Git-maintenance declarations; personal does not. |
| `config/mise/config*.toml` | Global tool sources. Dotty links them into `~/.config/mise`, so their tools are available outside dots. Project `tools*.toml` fragment symlinks reuse the same sources before global links exist. |
| `.miserc.toml` | Early discovery settings, not a package/tool list. Enables environment-suffixed fragments with `env_conf_d = true`. |

Root `mise.toml` owns shared bootstrap resources: host packages, VS Code extensions, the pinned Todoist repo, workstation directories/repos, Claude settings, macOS preferences, the login shell and sudo extension, and the all-profile syncengine agent. Profile overlays contain machine-specific packages, variables, files, and agents.

Keep bootstrap resources project-local: global tool configuration loads in other repositories too. Symlinks reuse declarations without creating a second configuration scope or duplicating lists.

## Commands

```nu
mise bootstrap --dry-run       # Preview without running hooks or installing
mise bootstrap                 # Apply the workstation
mise bootstrap status          # Inspect declarative state
mise bootstrap --update        # Also update declared repositories/package metadata
mise run llm:update             # Explicit agent CLI updates
```

`make` delegates to `mise bootstrap`; `make build` verifies/builds Oven. Native subcommands inspect or apply individual resources, for example `mise bootstrap packages status`, `mise dot diff`, or `mise bootstrap macos launchd-agents status`. Narrow applies must select their own prerequisites; use full bootstrap for initial setup.

Plain bootstrap clones missing repositories but does not pull unpinned existing branches. `--update` fast-forwards declared repositories; dirty checkouts, origin conflicts, and divergent history fail visibly. Resolve them rather than forcing a reset. Dependencies are installed from their committed lockfiles. No packages are pruned or upgraded implicitly.

## Bootstrap ordering

`boot/boot.sh` installs Homebrew and mise, clones dots, selects the profile, initializes the shared environment, and runs native bootstrap. It then checks Full Disk Access and syncs Neovim plugins. Existing machines use the same bootstrap from a durable checkout.

Native bootstrap applies packages before managed files and repositories, then dotfiles, defaults, LaunchAgents, login shell, and tools. Two repo-specific hooks fill the gaps:

1. **Post-packages:** install mise tools early, then run `boot/check-system.sh` before any managed PAM file is written. Raw LaunchAgents occur before mise's normal tools phase, so the early tool install is deliberate; the later native tools phase is an unchanged-state check.
2. **Post-repos:** `boot/setup.sh` installs missing agent CLIs, Playwright and VS Code extensions; builds Todoist/Honeycomb; links Pi and dotfiles; generates shell caches with `boot/shell.sh`; verifies/builds Oven; prepares credentials and Git-maintenance registrations. Only then can the later native dotfiles and LaunchAgent phases run.

Log directories and the cc-notify checkout are declarative resources. Secrets stay in cc-notify's local `.env`, not TOML or generated plists. Missing credentials abort before service loading. Claude settings render in the native dotfiles phase; `/tmp/claude` is prepared in the files phase.

Hooks run on every selected bootstrap and stop on failure; completed phases are not rolled back. A dry run prints hooks but cannot prove their runtime success. `--skip-dirty` is an explicit opt-in: it skips repository convergence, not the later setup hook's installs/builds.

## System and user configuration

`/bin/zsh` is the login shell. `/etc/pam.d/sudo_local` is a regular `root:wheel` file, mode `0644`, with optional `pam_reattach` and sufficient `pam_tid`. The stock `/etc/pam.d/sudo` remains untouched. `boot/check-system.sh` requires macOS 14+, the stock include, installed `pam-reattach`, and no foreign sudo symlink. Keep those checks before manual file applies too.

User defaults are declarative, except the per-user screenshot path written by the post-defaults hook. That hook also relaunches Dock, Finder, and SystemUIServer. Native defaults status does not inspect the hook-owned screenshot path.

Dev alone manages `/etc/ssh/sshd_config.d/090-dots.conf`: public-key-only, no root login, `AllowUsers ct`. Remote Login remains a manual System Settings choice. Do not apply the dev overlay to another account.

## Profiles and shell environment

`config/env/base.sh` selects `personal` for `codethread`, `work` for work accounts, and `dev` otherwise. Existing `MISE_ENV` is preserved; `-E` overrides it, and `boot.sh -p` sets it explicitly. Work machines use `mise -E work bootstrap`.

Global tool config stays separate from project bootstrap resources. Bash, Zsh and Nushell use native activation; scripts use `mise exec` or `mise run`. See [shell environment](shell-environment.md) and [services](mise-services.md).

## Verification

Validate tasks in all three profiles, format TOML/Markdown, syntax-check bootstrap scripts, and run read-only native package/service plans. Compare effective tools and generated agent definitions after changing file layout. Full bootstrap, password/Touch ID authentication and service readiness require operator checks; never run backup/sync jobs against real repositories merely as a test.
