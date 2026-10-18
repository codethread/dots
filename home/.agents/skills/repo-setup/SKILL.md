---
name: repo-setup
description: >
    Set up or repair shared agent instructions and skills, adopt Hive, or configure Markdown format-on-commit in a repository.
---

# Repository setup

Follow only the sections needed for the requested setup.

## Inspect the repository

Work from the intended repository root. Read its instructions and relevant README files; inspect the working tree, instruction/skill layout, setup commands, and active Git hooks (including the origin of `core.hooksPath`).

## Shared instructions and skills

For new repositories, prefer:

- `AGENTS.md` as the real instruction file, with `CLAUDE.md` linking to `AGENTS.md`.
- `.agents/skills/` as the real skills directory, with `.claude/skills` linking to `../.agents/skills`.

Create real targets before relative symlinks. Preserve existing arrangements, instructions and skills unless conversion is requested. Do not overwrite independent files or directories to create links; resolve conflicting content with the user first.

Keep repository instructions project-specific: explain setup, development and verification commands, important directories, and local conventions. Reference tool-owned guidance rather than copying its procedures into `AGENTS.md`.

## Hive integration

Use Hive for the repository's agent workflow and tracking when that setup is in scope. Follow its installed setup guidance:

```nu
beeswax skills get repository-setup
beeswax setup --help
```

Follow that guidance for tracker setup, harness onboarding, workflow configuration and validation. Preserve existing tracking data and hook ownership. For routine Hive work, use the repository's `hive` skill when installed.

## Markdown formatting

Produce a repository where Markdown has a documented format command and staged format-compatible files are formatted before each commit. Adapt the repository's existing tooling first; use the pnpm/oxfmt path only when no suitable setup exists.

### Workflow

1. Inspect the formatting setup:
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

## Complete the setup

Verify requested instruction and skill links resolve and are discoverable by the selected harnesses. Use Hive's own validation for its integration and the checks above for formatting. Keep hook activation reproducible through tracked setup instructions or an entrypoint.

Report what was created or reused, which checks passed, and any remaining setup decisions. Do not commit, push, discard pre-existing work, or rewrite the user's staged state without authorization.
