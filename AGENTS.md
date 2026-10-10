# Dotfiles Monorepo

## Bootstrap Flow

New machine → `boot/boot.sh`: install Homebrew/mise, clone dots, initialize the shared environment, run `mise bootstrap`, then check Full Disk Access and sync Neovim plugins. Existing machine → `mise bootstrap` (also `make`). Preview with `mise bootstrap --dry-run`; inspect with `mise bootstrap status`. `MISE_ENV` selects the machine profile, `-E` overrides it, and `boot.sh -p` sets it explicitly.

Mise itself comes from the official `https://mise.run` installer at `~/.local/bin/mise` and updates with `mise self-update`. Do not add it to Homebrew packages. Shells and LaunchAgents use this stable user-owned executable.

`llm:update` is the only custom task. `mise.toml` owns shared bootstrap resources and hooks; `mise.<profile>.toml` holds machine differences. `.mise/conf.d/` is reserved for reusable entrypoints: `tools.toml` and `tools.dev.toml` symlink to global `config/mise/` sources, while `services.dev.toml` symlinks to `.mise/dev-services.toml`, a source not loaded directly. `.miserc.toml` enables environment-suffixed entrypoints. Global tools are linked by dotty into `~/.config/mise` and reused by project tool fragments before those links exist. Keep bootstrap resources project-local, not in global tool config.

Start mise from the checkout (change directory before launching it) so its early `.miserc.toml` discovery settings load. Do not rely on `mise -C` when invoking dots from outside the checkout; service entrypoints must set their working directory before starting mise too.

Load the mise skill before changing bootstrap. Root hooks install tools early, check sudo prerequisites, and run `boot/setup.sh` after repository provisioning, before native LaunchAgents load. Do not move preparation into a final bootstrap task: that runs too late. The workfiles handoff is the narrow exception: it starts after common dots phases, and workfiles independently prepares its own resources and services before its LaunchAgents phase. Full bootstrap is the safe setup path; native subsystem applies require already-prepared dependencies. See `devflow/specs/mise-infra.md` and `devflow/specs/mise-services.md`. Apply from a durable checkout: jobs embed its path.

On work profiles, `mise.work.toml` owns only `brew:glab` and a final `boot/workfiles.sh` handoff with the GitLab host, repository, and checkout. Workfiles owns work-specific bootstrap resources and assumes common dots setup. If its checkout is absent and `glab` is not authenticated for GitLab, the handoff warns and skips without failing dots. An existing checkout is local input: the hook does not authenticate, pull, reset, or clean it; it trusts that checkout only and runs its default `make`, whose errors block bootstrap visibly. `mise -E work bootstrap --dry-run` prints this final handoff but does not recursively plan workfiles; after the checkout exists, run `make plan` or `make status` from it separately.

Runtime application ownership is per file: mixed personal/shared and work configuration stays in dots, even when it references workfiles. Move only wholly work-specific files; do not split shared configs just to remove work references. Workfiles owns the Nushell work hooks and 1Password helpers, loaded through the existing optional `~/.work.nu` entrypoint; its hooks append to shared/mise hooks.

## Directories

- **boot/** - System setup scripts. Go here to bootstrap a new machine.
- **claude/** - Global Claude Code configurations and agent documentation. Go here for multi-agent specs and hooks.
- **config/** - Application dotfiles (vim, kitty, nushell, etc). Go here to modify tool configurations.
- **home/** - Mise links this tree into `~` with `symlink-each`; it also links `home/.agents/skills/` into `~/.claude/skills/`, preserving Claude-owned metadata. Dotty owns only `config/`, `claude/` (except settings and skills), and `pi/`. Hive owns the live `qlock` launcher, excluded from the home mapping.
- **oven/** - TypeScript/Bun workspace for CLI tools. Go here for active development.
- **devflow/** - Planning workspace. Root specs live in `devflow/specs/`; RFCs in `devflow/rfcs/`; active feature work in `devflow/feat/`.
- **pdx/** - pandoras-box configs (pithos) for personal machines

### Makefile (Root)

Run `make help` for commands and profile selection. Plain `make` runs native mise bootstrap; `make build` installs, checks, fixes, builds, and syncs Oven docs through `mise -C oven run verify`.

## Tool Development Workflow

### Development Hierarchy

Nushell tooling is deprecated. Choose between two forms for new utilities:

1. **Standalone Zsh helper** (usually no more than 200 lines)
    - Location: `home/.local/bin/`
    - Use for simple command composition and tools needed on PATH.
    - Add a `:module:` description and `-h` or `--help` output.
    - `make link` links executables into `~/.local/bin/`.

2. **TypeScript/Bun in Oven**
    - Use for complex logic, dependencies, async control, shared code, or behavior that needs tests.
    - Declare entrypoints in `oven/bin/manifest.json`.
    - `make build` builds the declared tools into `~/.local/bin/` and runs the development checks.

### Script Evolution Path

Start with a small Zsh helper and move it into `oven/` when it exceeds this scope or needs TypeScript. Keep shell scripts simple and self-explanatory. Do not add standalone shell test suites or harnesses: if the logic needs tests, implement and test it in Oven. Verify shell changes with syntax checks and focused smoke checks.

## Claude Code integrations

This repo defines Claude Code configurations such as commands and agents at `claude/`. These include hooks, commands and agents, and the `claude/README.md` gives a comprehensive overview of all aspects, including the dependencies on any scripts from the `oven` module.

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

## Beads / br

Track work and implementation steps in repo-local Beads with `br`, from the repository root, instead of native harness todo lists. Start with the work assigned by the user or coordinating agent; do not run triage to replace it with a different task. `bv` is for read-only work selection, prioritization, and coordination—not a prerequisite for execution. Never run bare `bv`, which launches an interactive TUI.

1. **Identify:** If given a bead ID, run `br show <id> --json`. Otherwise, use `br search "<topic>" --json` to find an existing bead; if none fits, create one with `br create --title="..." --type=task --priority=2 --description="Scope and completion criteria" --json`.
2. **Claim:** Before implementation, run `br update <id> --claim --json`. Respect existing ownership and blockers; do not force a claim. A request to just record work ("bead this") stops after creation and sync, without claiming or implementing it.
3. **Work:** Break multi-step work, especially features, into child beads so steps can be claimed, verified, and closed incrementally. Keep progress, decisions, blockers, and handoff context in `br update <id> --append-notes="..." --json`. Pass the relevant bead ID when delegating; reuse it for the same scope rather than creating duplicates.
4. **Finish:** Verify the work, record the verification in notes, then `br close <id> --reason="Completed" --json`. Leave unfinished or blocked work open with a clear next step.

Use `task` for scoped work, `bug` for defects, `feature` for new capability, and `epic` for a larger effort; `chore` and `docs` cover maintenance and documentation. Nesting is not limited to epics: any bead can have children, and children can have their own children. Create a step with `br create --title="..." --type=task --parent=<parent-id> --json`; use as many levels as useful (e.g. feature → task → subtask), without splitting trivial work unnecessarily. Close a parent only after its children and overall completion criteria are satisfied.

Priorities run P0 (critical) through P4 (backlog), with P2 for normal work. Parent-child links group work; record execution prerequisites separately with `br dep add <issue> <depends-on>`: the first issue is blocked by the second.

`.beads/issues.jsonl` is generated and included in normal commits by the pre-commit hook; ignore incidental diffs and do not edit it manually. Tracker commands do not grant permission to commit or push application code.
