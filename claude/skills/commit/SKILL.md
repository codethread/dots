---
name: ct:commit
description: Create git commit(s) with a well-crafted conventional commit message
argument-hint: [optional context about changes]
allowed-tools: Bash(git:*)
---

# Create Git Commit

Create a git commit following your standard git commit workflow. The user has completed work and is ready to commit their changes.

## User Context About Changes

$ARGUMENTS

## Current Repository State

- **Current git status**: !`git status`
- **Current git diff** (staged and unstaged changes): !`git diff HEAD`
- **Current branch**: !`git branch --show-current`
- **Recent commits** (for style reference): !`git log --oneline -10`

## Your Task

Based on the above changes and user context, create atomic commits following these guidelines:

- **IMPORTANT**: Any repo specific instructions around git commits supersede these instructions

### Commit Message Guidelines

1. **Format**: Use conventional commits (feat:, fix:, docs:, refactor:, chore:, test:, style:)
2. **First line**: 50 characters or less, imperative mood
3. **Focus**: Explain "why" rather than "what" (code shows the what)
4. **Style**: Match the style of recent commits in this repository

### Atomic level

- Favour one commit, but multiple is applicable if recent commits show a clear separation of concerns

### Quality Checks

- Exclude temporary files (.env, \*.log, .DS_Store, build artifacts, etc.)
- Ensure message accurately reflects the changes
- Verify all relevant changes are included

### Execution Steps

1. Add relevant files with `git add` (exclude temp files)
2. Create commit with message using HEREDOC format:
   ```bash
   git commit -m "$(cat <<'EOF'
   Your commit message here
   EOF
   )"
   ```
3. Run `git status` after to verify success

### Pre-commit Hook Handling

- If hooks modify files and it's safe to amend (check authorship with `git log -1 --format='%an %ae'` and verify not pushed), amend the commit
- Otherwise create a new commit

## Current context

- If this is running within an existing session, focus on the work we have done only.
- If running in a new session, commit everything to get a clean worktree
- If in doubt, just ask
