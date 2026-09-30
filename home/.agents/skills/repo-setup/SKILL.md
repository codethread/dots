---
name: repo-setup
description: >
    Set up or repair a repository's agent scaffolding: shared instructions and skills, repo-local Beads tracking with br/bv, and Markdown format-on-commit. Use when bootstrapping a repository, initializing br, or standardizing formatting while preserving existing package and Git hook tooling.
---

# Repository setup

Set up or repair a repository's agent-facing scaffolding. The two tracks are independent: shared instructions, skills, and Beads tracking; and Markdown formatting with format-on-commit.

## Instructions, skills, and Beads

### Prerequisites

Work from the intended repository root with `br` available. Clear inherited `BEADS_DIR` or `BEADS_DB` overrides if they point elsewhere.

### Knowledge

Preferred layout for new repositories:

- `AGENTS.md` is the real instruction file; `CLAUDE.md` links to `AGENTS.md`.
- `.agents/skills/` is the real skills directory; `.claude/skills` links to `../.agents/skills`.

`br init` creates the `.beads/` workspace, not agent instructions. Adding the workflow guidance is a separate setup step.

### Procedures

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

### Constraints

Do not overwrite independent instruction files or skills to create symlinks; resolve conflicting contents with the user first. Do not use `br init --force` or commit/push unless explicitly requested. Generated guidance grants no authority.

### Validation

Confirm this repository has a `.beads/` workspace and its agent instructions contain the Beads workflow. For regular instruction files, verify with `br agents --check`. For new repositories, also verify both relative symlinks resolve to the canonical instruction file and skills directory. Confirm the hook/helper and its activation instructions are in version-controlled project files and the effective hook path/framework invokes it alongside existing hooks. Check in isolation that ordinary commits stage only JSONL, `next-index-*` indexes skip automatic staging, and a failed flush stops before staging; do not make live commits to verify setup.

## Markdown formatting

Produce a repository where Markdown has a documented format command and staged format-compatible files are formatted before each commit. Adapt the repository's existing tooling first; use the pnpm/oxfmt path only when no suitable setup exists.

### Workflow

1. Read the repository instructions and inspect its working tree before editing. Identify:
    - package manifests and lockfiles;
    - format scripts and formatter configuration;
    - whether the formatter supports `.md` and `.markdown`;
    - lint-staged or equivalent staged-file configuration;
    - existing Git hook tooling and pre-commit hook contents; and
    - whether an existing hook already collects, formats, and re-stages files directly.

2. Choose one path. Do not introduce a second formatter, package manager, lockfile, or hook manager merely to match the fallback recipe.

```text
START
  |
  v
[existing formatter can format Markdown?] -- yes --> [extend existing setup]
  |
  no
  v
[existing package workflow can add one?] -- yes --> [add oxfmt with that manager]
  |
  no
  v
[initialize pnpm]
  |
  v
[existing hook can run oxfmt directly?] -- yes --> [install oxfmt only]
  |
  no
  v
[install full hook fallback]
```

3. Prefer the existing setup when it can meet the outcome:
    - Enable Markdown in the formatter's include patterns, plugins, or overrides.
    - Add or retain a repository-wide format script and, when useful locally, a non-writing check script.
    - Reuse the existing pre-commit framework and preserve unrelated hook commands.
    - Follow the hook's existing precedent. If it already collects staged paths, invokes formatters directly, and re-stages results, call the Markdown formatter the same way; do not add lint-staged or another staged-file runner.
    - Otherwise, add staged Markdown to the existing staged-file runner. If the formatter safely ignores unsupported files, a catch-all pattern is acceptable.
    - Use the repository's existing package manager and update its lockfile.

4. If there is package tooling but no suitable formatter, install the latest `oxfmt` development dependency with that package manager. Use the Oxfmt npm package, not its standalone binary: Markdown formatting is Prettier-backed and is available from the package distribution. Only install `lint-staged` when no existing hook can invoke Oxfmt directly, and only install `husky` when no hook framework or configured hooks path exists. Check the selected versions' runtime requirements; if the repository's pinned Node version is incompatible, report the conflict rather than silently choosing an older package.

5. If there is no usable package workflow, initialize pnpm:

```nu
pnpm init --init-package-manager --yes
```

If an existing hook can invoke Oxfmt directly, install only Oxfmt:

```nu
pnpm add --save-dev oxfmt@latest
```

Only use the full hook fallback when no existing hook tooling can meet the outcome:

```nu
pnpm add --save-dev oxfmt@latest husky@latest lint-staged@latest
pnpm exec husky init
```

Keep generated package metadata that is meaningful, but remove placeholder entry points, test scripts, descriptions, and other `pnpm init` boilerplate that falsely describe a non-JavaScript repository. Keep only the tools selected by the applicable path in `devDependencies`.

6. Configure the Oxfmt fallback in `.oxfmtrc.json`:

```json
{
	"$schema": "./node_modules/oxfmt/configuration_schema.json",
	"tabWidth": 4,
	"useTabs": true,
	"proseWrap": "never"
}
```

Merge these preferences into an existing Oxfmt config rather than overwriting project-specific settings. Respect existing ignore files and generated/vendor exclusions.

7. Configure the fallback `package.json` while preserving useful existing fields:

```json
{
	"scripts": {
		"fmt": "oxfmt --disable-nested-config",
		"prepare": "husky"
	},
	"lint-staged": {
		"*": "oxfmt --no-error-on-unmatched-pattern"
	}
}
```

`--no-error-on-unmatched-pattern` belongs to Oxfmt. It lets the catch-all staged pattern coexist with file types Oxfmt does not support. Use a narrower Markdown glob instead when integrating into a formatter that cannot safely receive every staged path.

8. Wire pre-commit formatting:
    - For an existing hook that directly handles staged files, extend its existing collection → format → re-stage flow and invoke Oxfmt directly. Preserve its handling of partially staged files and path-limited commits.
    - For an existing staged-file runner, add the equivalent Markdown formatting task without deleting tests, linters, or other checks.
    - For a new Husky setup, replace the command generated by `husky init` in `.husky/pre-commit` with `pnpm exec lint-staged` and keep the file executable.
    - Ensure the package's `prepare` lifecycle installs Husky only when Husky is used; do not duplicate it if another prepare command exists—compose the commands deliberately.

9. Validate the behavior, not just the manifest:
    - run the repository format command and inspect the resulting diff;
    - confirm representative Markdown is accepted and formatted;
    - run the staged-file command with no staged files when a staged-file runner is used;
    - execute the pre-commit hook directly, using an isolated temporary index when necessary to preserve the user's staged state;
    - verify the hook is executable and Git's hooks path points at the hook manager;
    - run the repository's normal focused checks when formatting touched source or machine-readable data; and
    - inspect the final diff for accidental lockfile replacement, generated files, or removed hook behavior.

Do not commit, discard pre-existing changes, or rewrite the user's staged state unless explicitly asked. Report which path was selected, the files changed, and which commands verified the setup.
