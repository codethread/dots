# Oven Workspace

Bun workspace for managing TypeScript/JavaScript executables. Entrypoints listed in `bin/manifest.json` are built to `~/.local/bin/*`.

## Structure

- `bin/` - Source TypeScript files for CLI tools plus `manifest.json` entrypoint map
- `shared/` - Shared modules used by CLI tools
- `tests/` - Tests for `bin` files, following rails convention of `bin/myBin.ts` -> `tests/myBin.test.ts`
- `scripts/` - Build and utility scripts

## Commands

```bash
# Enter the project shell on Nix/NixOS (pins bun/biome/typescript for this repo)
nix develop

# Format and lint all code with Biome
bun run fix

# Check type definitions are correct
bun run typecheck

# Build all executables to ~/.local/bin
bun run build

# Run the full verification and build process
bun run verify

# One-shot run without opening an interactive shell
nix develop --command bun run verify
```

## Adding New Tools

1. Create a `.ts` entrypoint in `bin/` or a nested folder under `bin/`
2. Add it to `bin/manifest.json` with explicit `{ "bin": "tool-name", "entry": "path/to/main.ts" }`
3. Run `bun run fmt` to format the code
4. Run `bun run build` to create the executable

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
- **tts** - Basic OpenAI text-to-speech wrapper

### Quick Usage

All tools support the `-h` or `--help` flag to display usage information:

```bash
# Get help for any tool
analyze-subagents -h
bra --help
```
