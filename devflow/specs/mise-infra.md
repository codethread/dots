# Mise Infrastructure Specification

- Document ID: SPEC-006
- **Status:** Implemented
- **Last Updated:** 2026-11-08

## Ownership

Mise owns the Apple Silicon macOS workstation: packages, managed files, repositories, defaults, user settings, and LaunchAgents. Mise renders Claude settings, merges shared Codex settings, and deploys all `home/`, `config/`, `claude/`, `pi/`, and shared-skill links through native dotfile groups and entries. Shells activate mise natively. The checkout requires mise 2026.10.4 or newer for native structured dotfile merges.

The root Bun workspace contains only `oven`. The `.botlake/` lake package is independent: its dependencies resolve from the bootstrap-managed Botlake checkout and shared `ct-config`, and bootstrap installs them with `bun install --cwd .botlake` after preparing Botlake's source and CLIs.

The official installer at `https://mise.run` owns `~/.local/bin/mise`; Homebrew does not manage mise. Update it with `mise self-update`. The shared shell environment puts `~/.local/bin` on PATH, and LaunchAgents use that stable executable path. Dots also provisions the shared Pitchfork supervisor at login; projects register their own daemon definitions during their bootstrap. Interactive Zsh evaluates `mise completion zsh` directly so in-place mise updates take effect on the next shell.

## Configuration locations

There are two configuration scopes—project bootstrap and global tools—not four independent systems. The extra locations organize project fragments and reusable sources.

| Location | Loading and purpose |
| --- | --- |
| `mise.toml`, `mise.<profile>.toml` | Project entrypoints: mise loads the base and selected profile. The base owns shared bootstrap resources, hooks, repository tasks (`default`, `link`, `build`), and explicit maintenance tasks (`llm:update`, `brew:cleanup`); profiles add machine-specific resources. `mise.work.toml` deliberately contains only `brew:glab` and the final workfiles handoff. |
| `.mise/conf.d/*.toml` | Reusable entrypoints only: `tools.toml` and `tools.dev.toml` symlink to global tool sources; `services.dev.toml` symlinks to the dev-only service source; `botlake-ui.dev.toml` and `botlake-ui.work.toml` symlink to the shared UI source. Environment-suffixed entries load only for the selected environment with `env_conf_d` enabled. |
| `.mise/dev-services.toml` | Reusable dev-service source, not automatically discovered. The `.mise/conf.d/services.dev.toml` symlink loads its cc-notify and Git-maintenance declarations; workfiles declares the work equivalents in its own repository. |
| `.mise/botlake-ui.toml` | Shared dev/work Botlake UI daemon and setup flag, loaded only through its environment-suffixed symlinks. The Botlake supervisor and both clone resources remain in root `mise.toml`. |
| `config/mise/config.toml`, `config/mise/config.dev.toml` | Global tool sources. Mise links them into `~/.config/mise`, so their tools are available outside dots. Project `tools*.toml` fragment symlinks reuse the same sources before global links exist. |
| `.miserc.toml` | Early discovery settings, not a package/tool list. Enables environment-suffixed fragments with `env_conf_d = true`. |

## Workfiles handoff

On work profiles, `mise.work.toml` passes the GitLab host, repository, and checkout to `boot/workfiles.sh` as its final hook. This is the narrow exception to the rule against final-phase preparation: all common dots phases have completed, then workfiles independently prepares its own resources and services before its LaunchAgents phase. Workfiles' default `make` assumes that common dots setup already exists.

If the checkout is absent and `glab` is not authenticated for GitLab, the handoff warns and skips without failing dots. An existing checkout is local input: the hook does not authenticate, pull, reset, or clean it; it trusts only that checkout and runs its default `make`, whose errors block visibly. `mise -E work bootstrap --dry-run` prints the final handoff but does not recursively plan workfiles; after the checkout exists, run `make plan` or `make status` from it separately.

Workfiles owns the moved work-specific packages, Vault and cargo-lambda global tools, native work dotfile groups, work VS Code extensions, cc-notify, and work Git-maintenance jobs. Dots retains the generic Git-maintenance helper and all-profile syncengine. The shared Claude template remains a generic base that optionally merges `~/.config/claude/settings-overlay.json`; workfiles renders that overlay and, after its dotfiles phase, rerenders dots' one shared `~/.claude/settings.json` with targeted `mise dot apply ~/.claude/settings.json`, not a whole dots bootstrap. Work plugins/marketplaces and Microsoft 365/Atlassian allowances live in the overlay rather than a duplicate complete template.

Runtime application ownership follows whole files, not individual work references. Mixed Pi, Git, wktree, environment, and tmux settings stay in dots. The wholly work-specific Nushell `ct/config/hooks.nu` and `ct/onepassword.nu` modules live in workfiles' home tree and load through the existing optional `~/.work.nu` entrypoint. Work hooks append to the existing PWD hooks so mise activation is retained; common Nushell startup does not require either work module.

Root `mise.toml` owns shared bootstrap resources: host packages, VS Code extensions, the pinned Todoist repo, workstation directories/repos, Claude and Codex settings, macOS preferences, the login shell and sudo extension, and the all-profile syncengine and Pitchfork agents. Profile overlays contain machine-specific packages, variables, files, and agents.

Shared VS Code extensions are `vscode:*` entries in `[bootstrap.packages]`, backed by the [waynehoover/mise-vscode package plugin](https://github.com/waynehoover/mise-vscode) declared in `[bootstrap.plugins]`. The VS Code cask supplies the host application; `config/env/base.sh` includes its bundled `code` CLI on PATH. Mise installs missing extensions and reports their status; VS Code owns extension updates (the plugin does not support version pins). Removing a declaration does not uninstall an extension; pruning is explicit and limited to extensions mise installed. Work-specific extensions remain workfiles-owned.

Keep bootstrap resources project-local: global tool configuration loads in other repositories too. Symlinks reuse declarations without creating a second configuration scope or duplicating lists.

## Dotfile deployment

Root `mise.toml` sets `dotfiles.root = "."` and declares four native groups with `mode = "symlink-each"`:

| Group | Source | Destination | Selection |
| --- | --- | --- | --- |
| `home` | `home/` | `~` | Every source file, including untracked additions |
| `config` | `config/` | `~/.config` | Git-indexed files, excluding underscore-prefixed trees, `.gitignore`, and `README.md` |
| `claude` | `claude/` | `~/.claude` | Same selection, also excluding `settings.json`, `settings.local.json`, and `skills/` |
| `pi` | `pi/` | `~/.pi` | Same selection as `config` |

A separate `[dotfiles]` entry maps `home/.agents/skills/` to `~/.claude/skills/`. Each source file gets a link; destination directories remain real directories. Claude’s `synced/`, `.trash/`, and other unmanaged neighbors stay local. Mise records ownership in its state directory so deleted source files remove only their managed links. Destination-only files are neither removed nor imported into the source. Workfiles owns its own native dotfile groups; keep their target files disjoint from dots’ files.

After adding, renaming, or deleting files, run `mise run link` from the durable checkout. Stage new files in `config/`, `claude/`, and `pi/` with `git add` first: their `manifest = "git"` selection uses the index. Edits to existing linked files are visible immediately. Editor saves do not apply new links. The task applies all link targets without rerendering Claude settings or merging Codex settings, and refuses real-file conflicts. Preview its exact operations with `mise dot apply --dry-run ~ ~/.config ~/.claude ~/.pi ~/.claude/skills ~/.local/bin/pi ~/.local/bin/gitwatch`. Full bootstrap deploys these links in its native dotfiles phase before LaunchAgents.

## Codex settings

`templates/codex-config.toml` supplies the shared keys for the native `merge = true` edit at `~/.config/codex/config.toml/shared`. Mise renders the source with Tera first, so the Harnesses marketplace path uses the current user's `env.HOME`. Mise recursively merges tables and preserves target-only settings, comments, and untouched formatting. It replaces arrays wholesale, including `skills.config`; it does not merge skill records by path. Removed source keys remain in the target, and live edits do not sync back into the source. Keep durable shared changes in the source; machine-local keys can remain in the live file. Invalid TOML fails without overwriting the target.

Preview with `mise dot diff ~/.config/codex/config.toml/shared`, then apply that same target after reviewing.

## Commands

```nu
mise tasks                     # List repository tasks
mise run                       # Apply setup, skipping dirty repos
mise bootstrap --skip-dirty --dry-run # Preview the same setup without hooks/installing
mise bootstrap                 # Apply the workstation, rejecting dirty repos
mise bootstrap status          # Inspect declarative state
mise bootstrap packages status # Inspect effective managed-package state
mise bootstrap --update        # Also update declared repositories/package metadata
mise run link                  # Apply all repository-managed symlinks
mise run build                 # Run Oven's full development verification
mise run llm:update            # Explicit agent CLI updates
mise run brew:cleanup --dry-run # Preview Homebrew cleanup
mise run brew:cleanup          # Remove old Homebrew versions and stale downloads
mise self-update               # Update the mise executable
```

`mise run` executes the root default task, which delegates to `mise bootstrap --skip-dirty`. Preview the same policy with native `mise bootstrap --skip-dirty --dry-run`; `mise bootstrap --update` remains strict about dirty repositories. `mise tasks` lists repository workflows; `mise bootstrap --help` lists native convergence commands. Preview/status use native commands rather than task wrappers so they cannot install task tools first. The `build` task changes into Oven before starting its `mise run verify`, preserving early config discovery. Zsh's `mise-packages`, `mise-services`, and `mise-dot-diff` inspect this checkout from any directory. Native subcommands also apply individual resources; narrow applies must select their own prerequisites, so use full bootstrap for initial setup.

`mise bootstrap packages status` evaluates the active mise profile and reports whether its declared packages are in the desired state. It is not an inventory of installed-but-unmanaged packages; auditing unmanaged Homebrew formulae, casks, or editor extensions is a separate operation.

Plain bootstrap clones missing repositories but does not pull unpinned existing branches. `--update` fast-forwards declared repositories; dirty checkouts, origin conflicts, and divergent history fail visibly. Resolve them rather than forcing a reset. Dependencies are installed from their committed lockfiles. No packages are pruned or upgraded implicitly. `brew:cleanup` explicitly runs `brew cleanup` and forwards arguments to Homebrew; it requires the real `brew` executable and never runs during bootstrap. Cleanup removes old formula versions and stale downloads, not packages missing from the mise configuration. It does not clear mise's separate download cache or run `brew autoremove`.

## Bootstrap ordering

`boot/boot.sh` installs Homebrew and the official mise release at `~/.local/bin/mise`, clones dots, selects the profile, initializes the shared environment, and runs native bootstrap. The initial mise version matches the root `min_version`, avoiding the installer's default release-age delay; keep them in sync when raising the minimum. Existing binaries stay in place and update with `mise self-update`. It then checks Full Disk Access and syncs Neovim plugins. Existing machines use the same bootstrap from a durable checkout.

Native bootstrap installs package-manager plugins first, then applies built-in packages before managed files and repositories, followed by dotfiles, defaults, LaunchAgents, login shell, and tools. Plugin-managed packages (including VS Code extensions) apply after tools, so the host application is ready. Three repo-specific hooks fill the gaps:

1. **Post-packages:** install mise tools early, then run `boot/check-system.sh` before any managed PAM file is written. Raw LaunchAgents occur before mise's normal tools phase, so the early tool install is deliberate; the later native tools phase is an unchanged-state check.
2. **Post-repos:** `boot/setup.sh` installs missing agent CLIs and Playwright; builds Todoist; generates shell caches with `boot/shell.sh`; installs/builds Oven; installs service dependencies and prepares Git-maintenance registrations. It prepares Botlake's source checkout and installs its Go CLIs into `~/.local/bin`, then installs the dots lake's Bun dependencies with `bun install --cwd .botlake`; dev/work also installs the UI's dependencies and builds it. It registers dots-owned daemons with Pitchfork without starting them. Only then can the later native dotfiles and LaunchAgent phases run.
3. **Post-tools:** `boot/start-botlake.sh` starts the dots lake after native LaunchAgents load. It starts the mise-managed `botlake-supervisor` when needed and leaves an externally owned supervisor running, without stopping, restarting, or adopting it. Registration alone does not start that supervisor in an already-running Pitchfork; `boot_start` still handles subsequent logins.

Agent CLI setup, Playwright, Todoist, and Oven installation/build failures print warnings and allow setup to continue. A setup-exit summary repeats these failures. VS Code extension failures instead fail visibly through native package convergence. Agent installers still refuse to overwrite custom launchers. Bootstrap does not run Oven tests, typechecking, automatic fixes, or documentation generation; `mise run build` remains the development verification path. System/PAM checks, dotfile conflicts, required shell dependencies, and service dependency preparation remain blocking.

Log directories and the cc-notify checkout are declarative resources. Secrets stay in cc-notify's local `.env`, not TOML or generated plists. Bootstrap warns about missing credential names without printing their values and continues. Missing credentials fail cc-notify at runtime without blocking other services; inspect its launchd state and logs after bootstrap. All asset, home, and shared-skill files link, Claude settings render, and Codex settings merge in the native dotfiles phase; `/tmp/claude` is prepared in the files phase.

Hooks run on every selected bootstrap and stop on failure; completed phases are not rolled back. A dry run prints hooks but cannot prove their runtime success. `mise run` opts into `--skip-dirty`: it skips dirty repository convergence, not the later setup hook's installs/builds against those local checkouts. Direct `mise bootstrap` remains strict unless given the flag.

## System and user configuration

`/bin/zsh` is the login shell. `/etc/pam.d/sudo_local` is a regular `root:wheel` file, mode `0644`, with optional `pam_reattach` and sufficient `pam_tid`. The stock `/etc/pam.d/sudo` remains untouched. `boot/check-system.sh` requires macOS 14+, the stock include, installed `pam-reattach`, and no foreign sudo symlink. Keep those checks before manual file applies too.

User defaults are declarative, except the per-user screenshot path written by the post-defaults hook. That hook also relaunches Dock, Finder, and SystemUIServer. Native defaults status does not inspect the hook-owned screenshot path.

Dev alone manages `/etc/ssh/sshd_config.d/090-dots.conf`: public-key-only, no root login, `AllowUsers ct`. Remote Login remains a manual System Settings choice. Do not apply the dev overlay to another account.

## Profiles and shell environment

`config/env/base.sh` selects `personal` for `codethread`, `work` for work accounts, and `dev` otherwise. Existing `MISE_ENV` is preserved; `-E` overrides it, and `boot.sh -p` sets it explicitly. Work machines use `mise -E work bootstrap`.

Global tool config stays separate from project bootstrap resources. Bash, Zsh and Nushell use native activation; scripts use `mise exec` or `mise run`. See [shell environment](shell-environment.md) and [services](mise-services.md).

## Verification

Validate tasks in all three profiles, format TOML/Markdown, syntax-check bootstrap scripts, and run read-only native package/service plans. Compare effective tools and generated agent definitions after changing file layout. Full bootstrap, password/Touch ID authentication and service readiness require operator checks; never run backup/sync jobs against real repositories merely as a test.
