# Mise Infrastructure Specification

- Document ID: SPEC-006
- **Status:** Implemented
- **Last Updated:** 2026-10-10

## Ownership

Mise owns the Apple Silicon macOS workstation: packages, managed files, repositories, defaults, user settings, and LaunchAgents. Mise renders Claude settings, merges shared Codex settings, and links `home/` plus shared skills. Dotty links the remaining `config/`, `claude/` (except settings and skills), and `pi/` assets. Shells activate mise natively. The checkout requires mise 2026.10.4 or newer for native structured dotfile merges.

The official installer at `https://mise.run` owns `~/.local/bin/mise`; Homebrew does not manage mise. Update it with `mise self-update`. The shared shell environment puts `~/.local/bin` on PATH, and LaunchAgents use that stable executable path. Dots also provisions the shared Pitchfork supervisor at login; projects register their own daemon definitions during their bootstrap. Zsh caches `mise completion zsh` through its existing CLI-init helper.

## Configuration locations

There are two configuration scopes—project bootstrap and global tools—not four independent systems. The extra locations organize project fragments and reusable sources.

| Location | Loading and purpose |
| --- | --- |
| `mise.toml`, `mise.<profile>.toml` | Project entrypoints: mise loads the base and selected profile. The base owns shared bootstrap resources, hooks, and `llm:update`; profiles add machine-specific resources. `mise.work.toml` deliberately contains only `brew:glab` and the final workfiles handoff. |
| `.mise/conf.d/*.toml` | Reusable entrypoints only: `tools.toml` and `tools.dev.toml` symlink to global tool sources; `services.dev.toml` symlinks to the dev-only service source. Environment-suffixed entries load only for the selected environment with `env_conf_d` enabled. |
| `.mise/dev-services.toml` | Reusable dev-service source, not automatically discovered. The `.mise/conf.d/services.dev.toml` symlink loads its cc-notify and Git-maintenance declarations; workfiles declares the work equivalents in its own repository. |
| `config/mise/config.toml`, `config/mise/config.dev.toml` | Global tool sources. Dotty links them into `~/.config/mise`, so their tools are available outside dots. Project `tools*.toml` fragment symlinks reuse the same sources before global links exist. |
| `.miserc.toml` | Early discovery settings, not a package/tool list. Enables environment-suffixed fragments with `env_conf_d = true`. |

## Workfiles handoff

On work profiles, `mise.work.toml` passes the GitLab host, repository, and checkout to `boot/workfiles.sh` as its final hook. This is the narrow exception to the rule against final-phase preparation: all common dots phases have completed, then workfiles independently prepares its own resources and services before its LaunchAgents phase. Workfiles' default `make` assumes that common dots setup already exists.

If the checkout is absent and `glab` is not authenticated for GitLab, the handoff warns and skips without failing dots. An existing checkout is local input: the hook does not authenticate, pull, reset, or clean it; it trusts only that checkout and runs its default `make`, whose errors block visibly. `mise -E work bootstrap --dry-run` prints the final handoff but does not recursively plan workfiles; after the checkout exists, run `make plan` or `make status` from it separately.

Workfiles owns the moved work-specific packages, Vault and cargo-lambda global tools, `work_home`/`deals` dotty configuration, work VS Code extensions, cc-notify, and work Git-maintenance jobs. Dots retains the generic Git-maintenance helper and all-profile syncengine. The shared Claude template remains a generic base that optionally merges `~/.config/claude/settings-overlay.json`; workfiles renders that overlay and, after its dotfiles phase, rerenders dots' one shared `~/.claude/settings.json` with targeted `mise dot apply ~/.claude/settings.json`, not a whole dots bootstrap. Work plugins/marketplaces and Microsoft 365/Atlassian allowances live in the overlay rather than a duplicate complete template.

Runtime application ownership follows whole files, not individual work references. Mixed Pi, Git, Honeycomb/worktree, environment, and tmux settings stay in dots. The wholly work-specific Nushell `ct/config/hooks.nu` and `ct/onepassword.nu` modules live in workfiles' home tree and load through the existing optional `~/.work.nu` entrypoint. Work hooks append to the existing PWD hooks so mise activation is retained; common Nushell startup does not require either work module.

Root `mise.toml` owns shared bootstrap resources: host packages, VS Code extensions, the pinned Todoist repo, workstation directories/repos, Claude and Codex settings, macOS preferences, the login shell and sudo extension, and the all-profile syncengine and Pitchfork agents. Profile overlays contain machine-specific packages, variables, files, and agents.

Shared VS Code extensions are `vscode:*` entries in `[bootstrap.packages]`, backed by the [waynehoover/mise-vscode package plugin](https://github.com/waynehoover/mise-vscode) declared in `[bootstrap.plugins]`. The VS Code cask supplies the host application; `config/env/base.sh` includes its bundled `code` CLI on PATH. Mise installs missing extensions and reports their status; VS Code owns extension updates (the plugin does not support version pins). Removing a declaration does not uninstall an extension; pruning is explicit and limited to extensions mise installed. Work-specific extensions remain workfiles-owned.

Keep bootstrap resources project-local: global tool configuration loads in other repositories too. Symlinks reuse declarations without creating a second configuration scope or duplicating lists.

## Home and shared skills

Root `mise.toml` sets `dotfiles.root = "home"` and deploys that tree to `~` through `[dotfile_groups.home]` with `mode = "symlink-each"`. A separate `[dotfiles]` entry maps `home/.agents/skills/` a second time to `~/.claude/skills/`. The native group avoids the first-apply legacy scan of the entire home directory that an ungrouped `~` entry performs. Each source file gets a link; destination directories remain real directories. Claude’s `synced/`, `.trash/`, and other unmanaged neighbors stay local. Hive owns the live `~/.local/bin/qlock` launcher, so that path is excluded from the home mapping rather than replaced by the older dots helper.

The entries walk the source tree, including new files not yet in Git’s index. Existing linked-file edits are visible immediately; additions and removals need another apply. Mise records ownership in its state directory so deleted source files remove only their managed links. Destination-only files are neither removed nor imported into the source. Keep workfiles’ `work_home` targets disjoint from dots’ home files.

From the checkout, preview with `mise dot apply --dry-run ~ ~/.claude/skills`, then apply the same targets. `make link` runs the remaining Dotty projects and this targeted mise apply. Dotty’s editor hooks no longer deploy new home files; run `make link` after adding or removing them. Native bootstrap deploys both entries in its dotfiles phase before LaunchAgents.

## Codex settings

`templates/codex-config.toml` supplies the shared keys for the native `merge = true` edit at `~/.config/codex/config.toml/shared`. Mise renders the source with Tera first, so the Harnesses marketplace path uses the current user's `env.HOME`. Mise recursively merges tables and preserves target-only settings, comments, and untouched formatting. It replaces arrays wholesale, including `skills.config`; it does not merge skill records by path. Removed source keys remain in the target, and live edits do not sync back into the source. Keep durable shared changes in the source; machine-local keys can remain in the live file. Invalid TOML fails without overwriting the target.

Preview with `mise dot diff ~/.config/codex/config.toml/shared`, then apply that same target after reviewing. No overlay or dotty template cache is used. Removing dotty's template option leaves any old cache inert; do not delete live configuration as part of the migration.

## Commands

```nu
mise bootstrap --dry-run       # Preview without running hooks or installing
mise bootstrap                 # Apply the workstation
mise bootstrap status          # Inspect declarative state
mise bootstrap --update        # Also update declared repositories/package metadata
mise run llm:update             # Explicit agent CLI updates
mise self-update               # Update the mise executable
```

`make` delegates to `mise bootstrap --skip-dirty`; `make plan` previews the same policy, while `make update` remains strict about dirty repositories; `make help` lists setup, preview, status, update, linking, and build commands with profile selection. Zsh's `mise-packages`, `mise-services`, and `mise-dot-diff` inspect this checkout from any directory. Native subcommands also apply individual resources; narrow applies must select their own prerequisites, so use full bootstrap for initial setup.

Plain bootstrap clones missing repositories but does not pull unpinned existing branches. `--update` fast-forwards declared repositories; dirty checkouts, origin conflicts, and divergent history fail visibly. Resolve them rather than forcing a reset. Dependencies are installed from their committed lockfiles. No packages are pruned or upgraded implicitly.

## Bootstrap ordering

`boot/boot.sh` installs Homebrew and the official mise release at `~/.local/bin/mise`, clones dots, selects the profile, initializes the shared environment, and runs native bootstrap. The initial mise version matches the root `min_version`, avoiding the installer's default release-age delay; keep them in sync when raising the minimum. Existing binaries stay in place and update with `mise self-update`. It then checks Full Disk Access and syncs Neovim plugins. Existing machines use the same bootstrap from a durable checkout.

Native bootstrap installs package-manager plugins first, then applies built-in packages before managed files and repositories, followed by dotfiles, defaults, LaunchAgents, login shell, and tools. Plugin-managed packages (including VS Code extensions) apply after tools, so the host application is ready. Two repo-specific hooks fill the gaps:

1. **Post-packages:** install mise tools early, then run `boot/check-system.sh` before any managed PAM file is written. Raw LaunchAgents occur before mise's normal tools phase, so the early tool install is deliberate; the later native tools phase is an unchanged-state check.
2. **Post-repos:** `boot/setup.sh` installs missing agent CLIs and Playwright; builds Todoist/Honeycomb; links the remaining Dotty assets (including Pi); generates shell caches with `boot/shell.sh`; installs/builds Oven; installs service dependencies and prepares Git-maintenance registrations. Only then can the later native dotfiles and LaunchAgent phases run.

Agent CLI setup, Playwright, Todoist, and Oven installation/build failures print warnings and allow setup to continue. A setup-exit summary repeats these failures. VS Code extension failures instead fail visibly through native package convergence. Agent installers still refuse to overwrite custom launchers. Bootstrap does not run Oven tests, typechecking, automatic fixes, or documentation generation; `make build` remains the development verification path. System/PAM checks, dotfile conflicts, required shell dependencies, and service dependency preparation remain blocking.

Log directories and the cc-notify checkout are declarative resources. Secrets stay in cc-notify's local `.env`, not TOML or generated plists. Bootstrap warns about missing credential names without printing their values and continues. Missing credentials fail cc-notify at runtime without blocking other services; inspect its launchd state and logs after bootstrap. Home files and shared skills link, Claude settings render, and Codex settings merge in the native dotfiles phase; `/tmp/claude` is prepared in the files phase.

Hooks run on every selected bootstrap and stop on failure; completed phases are not rolled back. A dry run prints hooks but cannot prove their runtime success. `make` opts into `--skip-dirty`: it skips dirty repository convergence, not the later setup hook's installs/builds against those local checkouts. Direct `mise bootstrap` remains strict unless given the flag.

## System and user configuration

`/bin/zsh` is the login shell. `/etc/pam.d/sudo_local` is a regular `root:wheel` file, mode `0644`, with optional `pam_reattach` and sufficient `pam_tid`. The stock `/etc/pam.d/sudo` remains untouched. `boot/check-system.sh` requires macOS 14+, the stock include, installed `pam-reattach`, and no foreign sudo symlink. Keep those checks before manual file applies too.

User defaults are declarative, except the per-user screenshot path written by the post-defaults hook. That hook also relaunches Dock, Finder, and SystemUIServer. Native defaults status does not inspect the hook-owned screenshot path.

Dev alone manages `/etc/ssh/sshd_config.d/090-dots.conf`: public-key-only, no root login, `AllowUsers ct`. Remote Login remains a manual System Settings choice. Do not apply the dev overlay to another account.

## Profiles and shell environment

`config/env/base.sh` selects `personal` for `codethread`, `work` for work accounts, and `dev` otherwise. Existing `MISE_ENV` is preserved; `-E` overrides it, and `boot.sh -p` sets it explicitly. Work machines use `mise -E work bootstrap`.

Global tool config stays separate from project bootstrap resources. Bash, Zsh and Nushell use native activation; scripts use `mise exec` or `mise run`. See [shell environment](shell-environment.md) and [services](mise-services.md).

## Verification

Validate tasks in all three profiles, format TOML/Markdown, syntax-check bootstrap scripts, and run read-only native package/service plans. Compare effective tools and generated agent definitions after changing file layout. Full bootstrap, password/Touch ID authentication and service readiness require operator checks; never run backup/sync jobs against real repositories merely as a test.
