# Dotfiles Monorepo

## Bootstrap Flow

New machine → `boot/boot.sh`. Existing clone → `make system`. Optional local tool rebuild → `make build`.

## Directories

- **boot/** - System setup scripts. Go here to bootstrap a new machine.
- **claude/** - Global Claude Code configurations and agent documentation. Go here for multi-agent specs and hooks.
- **config/** - Application dotfiles (vim, kitty, nushell, etc). Go here to modify tool configurations.
- **home/** - Files that belong in home directory. Go here for home-specific scripts and configs.
- **oven/** - TypeScript/Bun workspace for CLI tools. Go here for active development.
- **devflow/** - Planning workspace. Root specs live in `devflow/specs/`; RFCs in `devflow/rfcs/`; active feature work in `devflow/feat/`.
- **nix/** - nix configs for NixOS and nix-darwin. When scripting for NixOS or not, env `$IS_NIXOS='true'` if running NixOS.
- **pdx/** - pandoras-box configs (pithos) for personal machines

### Makefile (Root)

```bash
make         # Run link then build (default) - quiet output, errors only
make link    # Link dotfiles via dotty
make build   # Build oven executables through `nix develop`
make system  # Rebuild nix-darwin or NixOS (override with `PROFILE=work`, etc)
```

## Tool Development Workflow

### Development Hierarchy

Build tools in order of increasing complexity

1. **Nushell alias** (1 line)
   - Location: `config/nushell/scripts/ct/alias/*.nu`
   - Example: `export alias ga = git add`
   - When: Simple command shortcuts

2. **Nushell function** (3-4 lines)
   - Location: `config/nushell/scripts/ct/<category>/mod.nu`
   - Example: Short functions like `git_current_branch`
   - When: Need parameters or simple logic

3. **Bash script** (≤200 lines)
   - Location: `home/.local/bin/`
   - Example: `home/.local/bin/nush`
   - When: Composition of multiple tools, and or needs to be globally available in PATH for non-tty usage
   - Notes:
     - `$ make link` links executables to `~/.local/bin/` (in PATH)
     - Always use bash (not zsh or other shells)
     - Add `:module:` comment for documentation
     - Use `-h` or `--help` flag for usage info

4. **TypeScript/Bun** (>200 lines or needs dependencies)
   - Location: entrypoints declared in `oven/bin/manifest.json`
   - When: Complex logic, dependencies, async task control or shared code
   - Notes:
     - `$ make build` builds manifest-declared executables to `~/.local/bin/` (in PATH)
     - Full development environment with testing

### Script Evolution Path

Start simple → Graduate as needed:

1. Try as nushell alias first
2. Expand to nushell function if needed
3. Create bash script in `home/.local/bin/` for standalone tools
   - `make link` to add script to PATH
4. Migrate to `oven/` when exceeding 200 lines or needing TypeScript
   - Build with `make build` (or `bun run build` inside `oven/`) to create executable

## Claude Code integrations

This repo defines Claude Code configurations such as commands and agents at `claude/`. These include hooks, commands and agents, and the `claude/README.md` gives a comprehensive overview of all aspects, including the dependencies on any scripts from the `oven` module.

## Verification

### Nix

When checking flake builds, avoid leaving repo-local `result` symlinks. Use `--no-link` for `nix build` commands, for example:

```bash
nix build ./nix#darwinConfigurations.home.system --show-trace --no-link
```

`nrs` / `make system` switch the system and do not need a `result` link.

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
