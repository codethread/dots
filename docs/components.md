# Component ownership

This repository converges a macOS workstation from one durable checkout. Linux is a portability target for configuration and command logic, not a supported full workstation bootstrap: Homebrew applications, launchd, preferences, PAM, TCC, and application registration remain macOS integration boundaries.

## Profiles and work ownership

[`config/env/base.sh`](../config/env/base.sh) selects the default mise profile from account identity: `codethread` selects `personal`, recognized work accounts select `work`, and other accounts select `dev`. An existing `MISE_ENV` is preserved, and `mise -E …` is the explicit per-command override.

[`mise.toml`](../mise.toml) is the shared baseline. [`mise.personal.toml`](../mise.personal.toml) adds personal applications without development services. [`mise.dev.toml`](../mise.dev.toml) adds public-project development services and an SSH policy restricted to user `ct`; enabling macOS Remote Login remains manual. [`mise.work.toml`](../mise.work.toml) adds only the GitLab prerequisite and final handoff to [`boot/workfiles.sh`](../boot/workfiles.sh).

Shared dots retains any file mixing personal and work behavior. Workfiles owns only wholly work-specific files, overlays, tools, and services. An existing workfiles checkout is trusted local input and is never pulled, reset, or cleaned; a missing checkout without GitLab authentication is skipped visibly rather than producing a partial setup.

## Convergence and deployed files

Mise owns ordered convergence, not a transaction: successful early phases remain applied after a later failure. Run it from a durable checkout because registered jobs embed that path. The [`.mise/conf.d/`](../.mise/conf.d/) links expose shared tools and selected service fragments before the equivalent global links exist.

[`boot/setup.sh`](../boot/setup.sh) runs after repositories and tools are available but before dotfiles and LaunchAgents load. That order lets external projects prepare their own builds, links, and daemon registrations before consumers start; moving the work into the final bootstrap task would be too late.

The `home` group follows the source filesystem and may deploy untracked entries. The `config`, `claude`, and `pi` groups use Git manifests, so only indexed files deploy; stage additions before `mise run link`. Existing symlinked-file edits are immediate, while additions, removals, and renames require another link apply. Before deleting or renaming an ordinary wildcard Oven command, unapply its old target while the declaration still exists.

Claude and Codex settings have different merge contracts:

- [`templates/claude-settings.json.tera`](../templates/claude-settings.json.tera) renders the whole owned `~/.claude/settings.json`. A workfiles overlay can override other objects and keys, but permission lists are unioned and deduplicated: they can add permissions, not revoke base permissions. Malformed overlays fail.
- [`templates/codex-config.toml`](../templates/codex-config.toml) uses mise's native structured merge to own selected keys while preserving target-only keys. Source arrays replace target arrays, and removing a source key does not remove the existing target key.

Real destination directories preserve application-owned credentials, sessions, synchronized content, and metadata around the deployed files.

## Tools and external owners

[`oven/`](../oven/) owns tested Bun/TypeScript commands; its generated [`README.md`](../oven/README.md) is the CLI reference. Small standalone commands stay in [`home/.local/bin/`](../home/.local/bin/). Public Oven commands require both the wildcard source declaration and an explicit `tasks.link` target.

Claude, Codex, Pi, and Pi-Bolt remain vendor-installed CLIs. [`home/.local/bin/mise-llm`](../home/.local/bin/mise-llm) invokes their official installers and refuses to replace foreign launchers; mise owns their supporting runtimes rather than substituting an ecosystem package owner.

Provisioning a checkout does not transfer source ownership. The pinned Todoist fork preserves its API contract, while the agents, Botlake, Botlake UI, cc-notify, and workfiles repositories own their internal builds and behavior. Dots owns only their workstation preparation, linking, profile selection, and scheduling boundaries.

The local Botlake package has relative `file:` dependencies that require the normal sibling layout of dots and `~/dev/projects/botlake`; moving either checkout breaks dependency resolution. Linked dots worktrees share the same lake and database. After lake configuration or shared-extension changes, restart the lake and use `botlake lake info` to confirm the loaded extension snapshot.

## Shell, editor, and terminal boundaries

[`config/env/base.sh`](../config/env/base.sh) owns the stable login environment and baseline `PATH`; [`config/env/interactive.sh`](../config/env/interactive.sh) owns human-facing interactive additions. A login shell intentionally rebuilds the baseline, while a non-login child preserves the active project environment.

The full and minimal Neovim configurations are independent editor surfaces. Their Lua behavior is portable, but plugin restoration, clipboard behavior, terminal integration, and macOS application effects are separate integration concerns.

Rex and tmux are distinct session managers and do not share session state. Their declarative bindings live here, while each application owns its mutable state in its configured location; do not generalize that location to every application.

The [`theme` command](../oven/bin/theme.ts) resolves mode and family from the caller, applies the caller first, then sends an explicit mode and family only to a selected remote host. The receiving `--host` action never forwards. Failures retain already-applied local changes; retry with an explicit mode rather than `toggle`. Rex is never auto-started, and no selected target means local-only application.

Rex palettes mirror the customized Kitty palettes rather than stock presets. Attribution and upstream terms remain in [`LICENSE-rose-pine`](../config/rex/themes/LICENSE-rose-pine) and [`LICENSE-tokyonight`](../config/rex/themes/LICENSE-tokyonight).

## Workers, schedulers, and host effects

Pitchfork supervises Botlake, the optional Botlake UI, and scheduled Codex usage refresh. Launchd starts the single durable Pitchfork supervisor; duplicate LaunchAgents would create competing owners. Native LaunchAgents remain for syncengine, notes backup, cc-notify, and Git maintenance where login startup, calendar scheduling, or launchd restart policy is required. Their environments are explicit and do not inherit interactive shell activation.

Worker logic can run against fixture repositories, private sockets, and fake endpoints without loading production schedules. `HOME` and XDG isolation do not contain fixed `/tmp` paths, live sockets, absolute macOS paths, or network effects.

PAM/Touch ID, login-shell changes, SSH server policy, macOS defaults, Tailscale routing, application registration, and TCC permissions are host effects. Read-only plans can be checked locally; clean privileged convergence needs a disposable Mac, and actual Touch ID or session experience needs physical verification.
