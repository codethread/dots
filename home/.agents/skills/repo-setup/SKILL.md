---
name: repo-setup
description: "Set up shared agent instructions, skills, and repo-local Beads when creating a new repository or asked to set up br for an existing repository."
---

# Repo Setup

## Prerequisites

Work from the intended repository root with `br` available. Clear inherited
`BEADS_DIR` or `BEADS_DB` overrides if they point elsewhere.

## Knowledge

Preferred layout for new repositories:

- `AGENTS.md` is the real instruction file; `CLAUDE.md` links to `AGENTS.md`.
- `.agents/skills/` is the real skills directory; `.claude/skills` links to
  `../.agents/skills`.

`br init` creates the `.beads/` workspace, not agent instructions. Adding the
workflow guidance is a separate setup step.

## Procedures

1. For a new repository, establish the shared layout above. Create the real
   `AGENTS.md` before its `CLAUDE.md` symlink. For existing repositories, preserve
   their arrangement unless asked to convert it, retaining all guidance and skills.
2. Run `br init` unless this repository already has an initialized Beads workspace.
3. Run `br agents --add --force` to add the standard guidance to the detected
   instruction file, creating `AGENTS.md` if needed. `--force` skips confirmation.
4. Preserve existing instructions and shared-file arrangements. The generator
   rejects symlinked instruction files; in that case, edit the resolved target
   manually to explain `br ready`, `br show <id>`, `br update <id> --claim`,
   `br close <id>`, and `br sync --flush-only`.

## Constraints

Do not overwrite independent instruction files or skills to create symlinks;
resolve conflicting contents with the user first. Do not use `br init --force`
or commit/push unless explicitly requested. Generated guidance grants no authority.

## Validation

Confirm this repository has a `.beads/` workspace and its agent instructions
contain the Beads workflow. For regular instruction files, verify with
`br agents --check`.
For new repositories, also verify both relative symlinks resolve to the canonical
instruction file and skills directory.
