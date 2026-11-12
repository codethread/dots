# Markdown formatting

Produce a repository with a documented Markdown format command and pre-commit formatting for staged format-compatible files. Adapt existing tooling first; formatting is not permission to replace the package manager or hook framework.

## Choose the smallest integration

Inspect the existing formatter, Markdown support, scripts, package workflow, staged-file handling, and hooks before selecting tools.

- Extend a suitable existing formatter. If none exists, prefer Oxfmt as a development dependency through the repository's package manager.
- Reuse the existing pre-commit framework and preserve unrelated checks. If it already handles staged paths and re-staging directly, integrate the formatter there rather than adding a staged-file runner.
- Reuse an existing staged-file runner when present. Add lint-staged only when the existing hook setup cannot meet the staged-formatting outcome; add Husky only when there is no existing hook framework or configured hooks path.
- If there is no usable package workflow, offer Bun. Before initializing package tooling or changing manager/workspace arrangements, follow [Existing Node tooling and workspaces](node-workspaces.md) and settle those choices. Do not introduce a second manager or lockfile just for formatting.
- If tool pins or project bootstrap change, follow [Tooling and bootstrap with mise](mise-bootstrap.md) for repeatable setup. Do not introduce mise solely for formatting.

## Read the selected tools' guidance

Load available tool-owned skills, then consult the selected tools' current CLI help and official documentation. For the preferred additions, start with [Oxfmt](https://oxc.rs/docs/guide/usage/formatter.html), [lint-staged](https://github.com/lint-staged/lint-staged#readme), and [Husky](https://typicode.github.io/husky/), loading only what the chosen path needs. Use the repository's established package invocation to access each selected CLI's `--help`; do not install an unselected tool just to inspect it.

Follow those sources for installation, configuration, supported file patterns, hook activation, lifecycle integration, and verification procedures. Confirm the selected formatter distribution supports Markdown and the selected versions meet runtime requirements. For new additions, prefer current releases; report runtime conflicts rather than silently choosing older versions. Do not copy package manifests, formatter schemas, hook scripts, or flag explanations into this reference.

## Repository-setup decisions

Keep existing style and exclusions. For a new Oxfmt setup, prefer tabs with four-column width and unwrapped prose; translate those preferences through the current configuration documentation. Preserve meaningful package metadata without retaining initialization placeholders that misdescribe a non-JavaScript repository.

Expose a repository-wide format command and, when useful, a non-writing check command. Keep hook activation reproducible through the established setup entrypoint. Preserve unrelated lifecycle commands, existing partial-staging behavior, and path-limited commit behavior.

## Required outcomes

Use the selected tools' verification guidance in a disposable repository or suitably isolated environment that cannot rewrite the user's worktree or staged state. Verify outcomes, not just configuration:

- The documented format command covers representative `.md` and `.markdown` files and respects exclusions; review its diff.
- Git actually invokes the active pre-commit hook, and formatted staged content reaches the commit without pulling in unrelated unstaged edits or paths outside a path-limited commit.
- The staged-file workflow handles an empty selection, existing hook checks still run, and formatter failures prevent the commit.
- Setup reproducibly activates the hook, and the final diff contains no accidental lockfile replacement, placeholder files, or removed hook behavior.

Run the repository's relevant checks if formatting changes source or machine-readable data. Report exact untested cases and blockers.
