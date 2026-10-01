# Mise cheat sheet

Mise handles **tool versions**, **host packages**, **tasks**, and **managed configuration**.

## For this dotfiles repo

Run from the dots checkout. Replace `dev` with `work` on your work machine.

```nu
# Discover available tasks
mise -E dev tasks

# Preview Claude settings changes
mise -E dev dot diff ~/.claude/settings.json

# Apply/check Claude settings
mise -E dev run claude:apply
mise -E dev run claude:status

# Prepare dependencies, then apply services
mise -E dev run services:apply

# Check services
mise -E dev run services:status

# Preview host packages (host packages only; no npm or VS Code extras)
mise -E dev bootstrap packages apply --dry-run

# Install host packages, then Playwright CLI and VS Code extensions
mise -E dev run packages:apply

# Show host package installation state
mise -E dev run packages:status
```

**Avoid bare `mise bootstrap` here**: use the dedicated tasks so service dependencies are prepared first. Package work belongs to `packages:apply`, not the service tasks.

Host packages live in `.mise/conf.d/packages.toml` plus the active profile overlay: `mise.dev.toml`, `mise.work.toml`, `mise.personal.toml`, or `mise.work-boot.toml` (both work bootstrap usernames use `work-boot`). `packages:apply` installs those Homebrew formulae and casks, then `@playwright/cli` with the Homebrew npm into `~/.local`, then the profile's VS Code extensions. `packages:status` reports host packages only. Applying packages never prunes unlisted packages or upgrades existing formulae; run `mise -E dev bootstrap packages upgrade --manager brew` to upgrade formulae explicitly.

## General commands

```nu
# Show loaded configuration files
mise config

# Show configured tools and their versions
mise ls

# Install versioned tools declared in [tools] (not host packages)
mise install

# Run a command with mise-managed tools
mise exec -- bun --version

# Diagnose mise setup
mise doctor
```

To add tools:

```nu
# Add Node to the current project's mise.toml and install it
mise use node@24

# Set a user-wide default instead
mise use --global node@24
```

Useful distinction: **`use` changes configuration; `install` installs versioned tools only; `run` executes a task; `exec` executes an arbitrary command. Host packages are applied by `packages:apply`, not `mise install`.**

No shell activation is needed for this repo’s tasks.
