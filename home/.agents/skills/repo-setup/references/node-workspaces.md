# Existing Node tooling and workspaces

Use this reference when assessing package-manager or workspace changes, including changes needed by another setup workflow.

## Inspect and agree on scope

Inspect the current package manager, pins, lockfiles, manifests, scripts, CI, and workspace setup. Identify maintained packages rather than treating every nested manifest as a workspace candidate; exclude dependencies, vendored/generated files, fixtures, and application configuration. Preserve an existing workspace arrangement unless changing it is requested.

Offer these as independent choices:

- For an npm, Yarn, or pnpm repository, offer migration to Bun. Retaining the current manager is valid; do not migrate without approval.
- When multiple maintained packages are not already workspaces, offer consolidation with the user's chosen manager. The goal is one root install plus repository-wide and package-targeted commands, not a directory reshuffle. Do not restructure without approval.
- If another setup workflow needs package tooling where none exists, agree on the manager before initializing it.

If an offer is declined, continue the requested setup without that change.

## Read package-manager-owned guidance

Before proposing configuration or commands, use the chosen manager's `--help` and current official guidance: [Bun](https://bun.com/docs/pm/workspaces), [npm](https://docs.npmjs.com/cli/using-npm/workspaces), [Yarn](https://yarnpkg.com/features/workspaces), or [pnpm](https://pnpm.io/workspaces). Load any available tool-owned skill first. Check compatibility with the version being pinned.

Let those sources define migration and lockfile import, workspace discovery and local linking, install/lifecycle behavior, and script selection. Do not transplant another manager's syntax or maintain a parallel recipe here.

## Compose the approved changes

Preserve package names, useful scripts, publishing boundaries, dependency behavior, and preferably the existing directory layout. For consolidation, require one root install and lockfile with dependencies declared in their owning packages. Review the supported migration's result before removing superseded lockfiles.

Follow [Tooling and bootstrap with mise](mise-bootstrap.md) when tool pins or project bootstrap change. Align CI, hooks, and setup documentation with the agreed manager and install boundary; do not introduce another orchestration tool merely to get workspaces.

## Required outcomes

Follow the manager's current verification guidance. Require a clean install from the committed lockfile and passing relevant builds/checks. For workspace changes, verify coverage of every intended package, local dependency resolution, and both repository-wide and package-targeted commands. When mise-managed project bootstrap is in scope, confirm its documented entrypoint prepares the whole repository without per-package installs. Report migrated, retained, pending, and untested behavior separately.
