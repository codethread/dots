# Dotfiles Monorepo

## Bootstrap Flow

New machine → `boot/boot.sh`: install Homebrew/mise, clone dots, initialize the shared environment, run `mise bootstrap`, then check Full Disk Access and sync Neovim plugins. Existing machine → `mise run` (skips dirty repos) or strict `mise bootstrap`. Preview with `mise bootstrap --dry-run`; inspect with `mise bootstrap status`. `MISE_ENV` selects the machine profile, `-E` overrides it, and `boot.sh -p` sets it explicitly.

Mise itself comes from the official `https://mise.run` installer at `~/.local/bin/mise` and updates with `mise self-update`. Do not add it to Homebrew packages. Shells and LaunchAgents use this stable user-owned executable.

`llm:update` and `brew:cleanup` are explicit maintenance tasks. Preview Homebrew cleanup with `mise run brew:cleanup --dry-run`; cleanup is never part of bootstrap. `mise.toml` owns shared bootstrap resources and hooks; `mise.<profile>.toml` holds machine differences. `.mise/conf.d/` is reserved for reusable entrypoints: `tools.toml` and `tools.dev.toml` symlink to global `config/mise/` sources, while `services.dev.toml` symlinks to `.mise/dev-services.toml`, a source not loaded directly. `.miserc.toml` enables environment-suffixed entrypoints. Global tools are linked by dotty into `~/.config/mise` and reused by project tool fragments before those links exist. Keep bootstrap resources project-local, not in global tool config.

Start mise from the checkout (change directory before launching it) so its early `.miserc.toml` discovery settings load. Do not rely on `mise -C` when invoking dots from outside the checkout; service entrypoints must set their working directory before starting mise too.

Load the mise skill before changing bootstrap. Root hooks install tools early, check sudo prerequisites, and run `boot/setup.sh` after repository provisioning, before native LaunchAgents load. Do not move preparation into a final bootstrap task: that runs too late. The workfiles handoff is the narrow exception: it starts after common dots phases, and workfiles independently prepares its own resources and services before its LaunchAgents phase. Full bootstrap is the safe setup path; native subsystem applies require already-prepared dependencies. See `devflow/specs/mise-infra.md` and `devflow/specs/mise-services.md`. Apply from a durable checkout: jobs embed its path.

On work profiles, `mise.work.toml` owns only `brew:glab` and a final `boot/workfiles.sh` handoff with the GitLab host, repository, and checkout. Workfiles owns work-specific bootstrap resources and assumes common dots setup. If its checkout is absent and `glab` is not authenticated for GitLab, the handoff warns and skips without failing dots. An existing checkout is local input: the hook does not authenticate, pull, reset, or clean it; it trusts that checkout only and runs its default `make`, whose errors block bootstrap visibly. `mise -E work bootstrap --dry-run` prints this final handoff but does not recursively plan workfiles; after the checkout exists, run `make plan` or `make status` from it separately.

Runtime application ownership is per file: mixed personal/shared and work configuration stays in dots, even when it references workfiles. Move only wholly work-specific files; do not split shared configs just to remove work references. Workfiles owns the Nushell work hooks and 1Password helpers, loaded through the existing optional `~/.work.nu` entrypoint; its hooks append to shared/mise hooks.

## Directories

- **boot/** - System setup scripts. Go here to bootstrap a new machine.
- **claude/** - Global Claude Code configurations and agent documentation. Go here for multi-agent specs and hooks.
- **config/** - Application dotfiles (vim, kitty, nushell, etc). Go here to modify tool configurations.
- **home/** - Mise links this tree into `~` with `symlink-each`; it also links `home/.agents/skills/` into `~/.claude/skills/`, preserving Claude-owned metadata. Dotty owns only `config/`, `claude/` (except settings and skills), and `pi/`.
- **oven/** - TypeScript/Bun workspace for CLI tools. Go here for active development.
- **devflow/** - Planning workspace. Root specs live in `devflow/specs/`; RFCs in `devflow/rfcs/`; active feature work in `devflow/feat/`.
- **pdx/** - pandoras-box configs (pithos) for personal machines

### Root mise tasks

Run `mise tasks` for available tasks. Plain `mise run` runs `mise bootstrap --skip-dirty`; `mise run build` changes into Oven and runs its `verify` task. Use native `mise bootstrap --skip-dirty --dry-run`, `mise bootstrap status`, and `mise bootstrap --update` for preview, state, and updates; preview/status avoid task-time tool installation.

## Tool Development Workflow

### JavaScript workspace

The root `package.json` explicitly includes `oven` as its Bun workspace member. Run `bun install --frozen-lockfile` from the repository root to install both packages using the single root `bun.lock`. Keep dependency declarations in their owning package; do not add nested lockfiles or package-manager pins. Application configuration manifests under `config/` and the independent `.botlake/` lake package are not workspace members. Bun is both the package manager and Oven's runtime/test runner; pnpm remains available for other repositories, not for installing dots.

### Development Hierarchy

Nushell tooling is deprecated. Choose between two forms for new utilities:

1. **Standalone Zsh helper** (usually no more than 200 lines)
    - Location: `home/.local/bin/`
    - Use for simple command composition and tools needed on PATH.
    - Add a `:module:` description and `-h` or `--help` output.
    - `mise run link` links executables into `~/.local/bin/`.

2. **TypeScript/Bun in Oven**
    - Use for complex logic, dependencies, async control, shared code, or behavior that needs tests.
    - Declare entrypoints in `oven/bin/manifest.json`.
    - `mise run build` builds the declared tools into `~/.local/bin/` and runs the development checks.

### Script Evolution Path

Start with a small Zsh helper and move it into `oven/` when it exceeds this scope or needs TypeScript. Keep shell scripts simple and self-explanatory. Do not add standalone shell test suites or harnesses: if the logic needs tests, implement and test it in Oven. Verify shell changes with syntax checks and focused smoke checks.

## Claude Code integrations

This repo defines Claude Code configurations such as commands and agents at `claude/`. These include hooks, commands and agents, and the `claude/README.md` gives a comprehensive overview of all aspects, including the dependencies on any scripts from the `oven` module.

## Botlake

`.botlake/package.json` selects the shared `ct-config` from the bootstrap-managed Botlake checkout. Install lake dependencies with `bun install --cwd .botlake`; start it with `botlake lake start` after the workstation supervisor is running. Linked worktrees share the main checkout's lake and local database. Restart the lake after configuration changes; `botlake lake info` reports the loaded extension snapshot.

Track implementation with `bl` Work operations. Run `bl prime work` before tracking and `bl prime agent` before delegating; use command help for unfamiliar operations. Preserve caller identity, existing assignments and human decisions. Importing historical context does not authorize execution or reassignment. Use `wktree` for worktree lifecycle operations.

Keep `core.hooksPath = .githooks`: bootstrap sets it, or run `git config --local core.hooksPath .githooks` when configuring a checkout directly. The pre-commit hook formats staged Markdown and Nushell files.

## Verification

### Mise

Validate the mise configuration and task graph without applying host changes:

```bash
mise -E dev tasks validate --errors-only
mise -E dev bootstrap packages apply --dry-run
mise -E dev bootstrap status
```

`mise bootstrap` is host-mutating. Its post-packages hook checks the stock PAM include, installed pam-reattach, and absence of a foreign sudo_local symlink before native file convergence. Run `boot/check-system.sh` before any manual managed-file apply too. Use only read-only plans/status during validation unless host changes are explicitly authorized.

### Nushell

After editing `.nu` files, validate syntax with absolute paths. Use `--as-module` for module files only:

```bash
nu -c 'nu-check --debug --as-module /abs/path/to/module.nu'
nu -c 'nu-check --debug /abs/path/to/script-or-env.nu'
```

For config-level Nushell changes, also validate the real config load:

```bash
nu --config config/nushell/config.nu --env-config config/nushell/env.nu -c 'print ok'
```

## Tool deprecation

Given the monorepo nature of this repo, we want to exercise discretion, to that end, if we delete a tool from the repo, e.g lets say vim:

- remove the obvious code `config/vim/vimrc`
- remove any specs
- flag any other tooling that is expecting said tool, e.g a tmux workflow that tries to use `vim` directly.
    - where apparent, we would remove this dependency
    - where difficult, discuss alternatives or fallbacks
- finally commit in one single commit with convention `GOODBYE <tool>\n\n<Reason and details if needed>`, this makes it easy to dig out old features at a later date to revisit
