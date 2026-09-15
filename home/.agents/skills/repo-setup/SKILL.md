---
name: repo-setup
description: "Set up shared agent instructions, skills, and repo-local Beads when creating a new repository or asked to set up br for an existing repository."
---

# Repo Setup

## Prerequisites

Work from the intended repository root with `br` available. Clear inherited `BEADS_DIR` or `BEADS_DB` overrides if they point elsewhere.

## Knowledge

Preferred layout for new repositories:

- `AGENTS.md` is the real instruction file; `CLAUDE.md` links to `AGENTS.md`.
- `.agents/skills/` is the real skills directory; `.claude/skills` links to `../.agents/skills`.

`br init` creates the `.beads/` workspace, not agent instructions. Adding the workflow guidance is a separate setup step.

## Procedures

1. For a new repository, establish the shared layout above. Create the real `AGENTS.md` before its `CLAUDE.md` symlink. For existing repositories, preserve their arrangement unless asked to convert it, retaining all guidance and skills.
2. Run `br init` unless this repository already has an initialized Beads workspace.
3. Run `br agents --add --force` to add the standard guidance to the detected instruction file, creating `AGENTS.md` if needed. `--force` skips confirmation.
4. Preserve existing instructions and shared-file arrangements. The generator rejects symlinked instruction files; in that case, edit the resolved target manually to explain `br ready`, `br show <id>`, `br update <id> --claim`, `br close <id>`, and `br sync --flush-only`.
5. For new repositories, add Beads automation to the pre-commit workflow. Inspect `git config --show-origin --get core.hooksPath` and the active hook first. Extend the existing hook/framework or call a Git-tracked Bash helper; preserve custom/global hooks rather than replacing their ownership. With no existing hook setup, create an executable, tracked `.githooks/pre-commit` and put `git config --local core.hooksPath .githooks` in the project's tracked bootstrap script or setup target, then run it to activate the hook reproducibly rather than leaving activation only in `.git/config`. Use this Bash body (add a Bash shebang for a standalone hook):

   ```bash
   repo_root="$(git rev-parse --show-toplevel)" || exit $?
   br --db "$repo_root/.beads/beads.db" sync --flush-only --quiet || exit $?
   case "$(basename "${GIT_INDEX_FILE:-index}")" in
     next-index-*) ;; # Git's path-limited commit index: do not widen its scope.
     *) git add -- "$repo_root/.beads/issues.jsonl" || exit $? ;;
   esac
   ```

   Keep flush failures fatal and stage only the generated collaboration file, never the SQLite DB or other `.beads/` state. Add just this line to `AGENTS.md`: “`.beads/issues.jsonl` is generated and included in normal commits by the pre-commit hook; ignore incidental diffs and do not edit it manually.”

## Constraints

Do not overwrite independent instruction files or skills to create symlinks; resolve conflicting contents with the user first. Do not use `br init --force` or commit/push unless explicitly requested. Generated guidance grants no authority.

## Validation

Confirm this repository has a `.beads/` workspace and its agent instructions contain the Beads workflow. For regular instruction files, verify with `br agents --check`. For new repositories, also verify both relative symlinks resolve to the canonical instruction file and skills directory. Confirm the hook/helper and its activation instructions are in version-controlled project files and the effective hook path/framework invokes it alongside existing hooks. Check in isolation that ordinary commits stage only JSONL, `next-index-*` indexes skip automatic staging, and a failed flush stops before staging; do not make live commits to verify setup.
