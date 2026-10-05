# Oven Workspace

Bun workspace for managing TypeScript/JavaScript executables. Entrypoints listed in `bin/manifest.json` are built to `~/.local/bin/*`.

## Structure

- `bin/` - Source TypeScript files for CLI tools plus `manifest.json` entrypoint map
- `shared/` - Shared modules used by CLI tools
- `tests/` - Tests for `bin` files, following rails convention of `bin/myBin.ts` -> `tests/myBin.test.ts`
- `scripts/` - Build and utility scripts

## Tooling and commands

Mise manages Bun and Node through `mise.toml` and `mise.lock`, with locked downloads for macOS and Linux (arm64/x64). The project-local `settings.enable_tools` allowlist limits mise activation and installation to those runtimes; parent/global workstation tools remain available outside Oven. Add future mise-managed task tools to this allowlist too. Biome and TypeScript come from `package.json` / `bun.lock`, not global tools. Git must be available on PATH (provided by the workstation's host packages).

Run from `oven/`:

```nu
# Review and trust this project's configuration once
mise trust mise.toml

# Install the pinned runtimes and frozen project dependencies
mise run install

# Format and lint all code with the project-local Biome
mise exec -- bun run fix

# Check type definitions with the project-local TypeScript
mise exec -- bun run typecheck

# Build all executables to ~/.local/bin
mise exec -- bun run build

# Install dependencies, test, typecheck, fix, build, and sync docs
mise run verify
```

From the repository root, `make build` runs the same `mise -C oven run verify` workflow. The generated wrappers still execute `bun` from PATH; workstation setup provides the mise-managed runtime. Keep this checkout available because wrappers point to its source files.

To update runtimes, edit their exact versions in `mise.toml`, run `mise lock --platform linux-arm64,linux-x64,macos-arm64,macos-x64`, then `mise run verify`. Review and commit both mise files together. Oven's strict lock policy applies only to its runtimes, not inherited workstation tools.

## Adding New Tools

1. Create a `.ts` entrypoint in `bin/` or a nested folder under `bin/`
2. Add it to `bin/manifest.json` with explicit `{ "bin": "tool-name", "entry": "path/to/main.ts" }`
3. Run `mise exec -- bun run fmt` to format the code
4. Run `mise exec -- bun run build` to create the executable

## Tools Included

- **bra** - Git branch switcher with fzf
- **cc-hook--context-injector** - Claude Code hook that provides project context at session start
- **cc-hook--npm-redirect** - Claude Code hook that redirects npm/npx/node commands to detected package manager
- **cc-speak** - Advanced text-to-speech tool with file and section reading support
- **cc-statusline** - Process Claude Code statusline data and display custom status
- **cindex** - Generate an index of files in the current project
- **ghub** - Open GitHub/GitLab repository in browser
- **git-cleanup** - Clean up build artifacts and log files from git projects
- **git-pipeline--await** - Watch the current branch's MR pipeline to completion
- **gitlab-pipeline-watcher** - Monitor GitLab pipelines and send notifications
- **notif** - Show macOS native notifications
- **prepend-comment** - Add or update module documentation comments
- **strip-markdown** - Strip markdown formatting from text, optimized for text-to-speech or plain text output.
- **theme** - Switch macOS and terminal color theme
- **tts** - Basic OpenAI text-to-speech wrapper

### Quick Usage

All tools support the `-h` or `--help` flag to display usage information:

```bash
# Get help for any tool
analyze-subagents -h
bra --help
```
