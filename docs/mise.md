# Mise cheat sheet

Mise handles **tool versions**, **tasks**, and **managed configuration**.

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
```

**Avoid bare `mise bootstrap` here**: use the dedicated tasks so service dependencies are prepared first.

## General commands

```nu
# Show loaded configuration files
mise config

# Show configured tools and their versions
mise ls

# Install tools declared in configuration
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

Useful distinction: **`use` changes configuration; `install` installs it; `run` executes a task; `exec` executes an arbitrary command.**

No shell activation is needed for this repo’s tasks.
