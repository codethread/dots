# Oven Workspace

Oven is the only package in the repository-root Bun workspace. Its executable Bun entrypoints in `bin/` are linked into `~/.local/bin/*` by native mise dotfiles.

## Structure

- `bin/` - Executable Bun entrypoints for CLI tools
- `shared/` - Shared modules used by CLI tools
- `tests/` - Tests for `bin` files, following rails convention of `bin/myBin.ts` -> `tests/myBin.test.ts`
- `scripts/` - Build and utility scripts

## Tooling and commands

Mise manages Bun and Node through `mise.toml` and `mise.lock`, with locked downloads for macOS and Linux (arm64/x64). The project-local `settings.enable_tools` allowlist limits mise activation and installation to those runtimes; parent/global workstation tools remain available outside Oven. Add future mise-managed task tools to this allowlist too. Biome and TypeScript are declared in this package's `package.json` and resolved by the repository-root `bun.lock`, not global tools. One `bun install --frozen-lockfile` from the repository root installs the root tools and Oven. The `.botlake/` lake package is independent of this workspace, resolves its dependencies from the bootstrap-managed Botlake checkout and shared `ct-config`, and installs with `bun install --cwd .botlake`. Git must be available on PATH (provided by the workstation's host packages).

Run from `oven/`:

```nu
# Review and trust this project's configuration once
mise trust mise.toml

# Install the pinned runtimes and frozen dependencies for Oven and root tooling
mise run install

# Format and lint all code with the project-local Biome
mise exec -- bun run fix

# Check type definitions with the project-local TypeScript
mise exec -- bun run typecheck

# Install dependencies, test, typecheck, fix, and sync docs
mise run verify
```

From the repository root, `mise run build` changes into `oven/` and runs the same `mise run verify` workflow. Native mise dotfiles link each executable entrypoint into `~/.local/bin`; the links execute Bun from PATH and resolve imports and dependencies from this checkout.

To update runtimes, edit their exact versions in `mise.toml`, run `mise lock --platform linux-arm64,linux-x64,macos-arm64,macos-x64`, then `mise run verify`. Review and commit both mise files together. Oven's strict lock policy applies only to its runtimes, not inherited workstation tools.

## Adding New Tools

1. Create a directly executable `.ts` entrypoint in `bin/` named for the public command
2. Start it with `#!/usr/bin/env bun` and mark it executable
3. Add `"$HOME/.local/bin/<name>"` to the root `tasks.link` target list; the wildcard dotfile declaration already maps `bin/<name>.ts` to the extensionless command
4. Run `mise exec -- bun run fmt` and `mise run verify`

## Tools Included

- **bra** - Git branch switcher with fzf
- **cc-hook--context-injector** - Claude Code hook that provides project context at session start
- **cc-hook--npm-redirect** - Claude Code hook that redirects npm/npx/node commands to detected package manager
- **cc-statusline** - Process Claude Code statusline data and display custom status
- **cindex** - Generate an index of files in the current project
- **ghub** - Open GitHub/GitLab repository in browser
- **git-cleanup** - Clean up build artifacts and log files from git projects
- **git-pipeline--await** - Watch the current branch's MR pipeline to completion
- **gitlab-pipeline-watcher** - Monitor GitLab pipelines and send notifications
- **mise-dot-diff** - Preview mise dotfiles and pull JSON template edits into local overlays
- **notif** - Send desktop notifications, or CC Notify when away from tmux
- **prepend-comment** - Add or update module documentation comments
- **strip-markdown** - Strip markdown formatting from text, optimized for text-to-speech or plain text output.
- **theme** - Apply a local theme and forward explicit state to a Rex host
- **tts** - Basic OpenAI text-to-speech wrapper

### Quick Usage

All tools support the `-h` or `--help` flag to display usage information:

```bash
# Get help for any tool
analyze-subagents -h
bra --help
```
