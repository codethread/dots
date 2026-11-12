# Tooling and bootstrap with mise

Use this reference when tool pinning or repeatable project bootstrap is in scope. Give maintainers one documented setup command from the repository root: `mise run`.

## Read mise-owned guidance

Load the available `mise` skill, then use `mise --help` to discover the relevant configuration and task commands. Consult the current [configuration](https://mise.jdx.dev/configuration.html) and [task documentation](https://mise.jdx.dev/tasks/) for implementation and validation. Check guidance against the installed version before relying on it; do not copy task schemas, execution semantics, or validation recipes into this skill.

## Repository-setup decisions

- If the repository uses a Makefile or justfile, offer migration but obtain approval before changing those workflows. Until approved, preserve their entrypoints and reuse existing targets.
- Extend the existing mise setup rather than introducing a parallel one. Pin required runtimes and development tools, including the agreed package manager and its runtime prerequisites, to exact versions; do not depend on maintainers' global installations. Keep application dependencies and their lockfiles with their ecosystem owners, and retain mise's lockfile when used.
- Make project bootstrap the default for `mise run`, also available as `mise run bootstrap`. It must prepare declared tools, dependencies, required generated artifacts, builds, and local hooks as applicable. Reuse existing commands and express prerequisite ordering through mise's documented task model.
- Keep setup repeatable, preserve local work, and stop on failures. Deployment and unrelated external side effects are not part of project bootstrap.
- Document installation/trust prerequisites and the setup entrypoint in the README and agent instructions. This is project preparation, not workstation convergence; do not substitute `mise bootstrap`.

## Required outcomes

Follow mise's current validation and preview guidance to confirm the default task selects the intended bootstrap and orders its prerequisites correctly. A preview is not evidence that setup works. With execution authorized, verify that the documented entrypoint prepares a fresh checkout and succeeds again on the prepared checkout without damaging local work. Report exact unexecuted steps and blockers.
