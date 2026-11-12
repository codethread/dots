# Botlake integration

Use Botlake for repository agent workflows and tracking when that setup is requested. Preserve existing lake configuration, tracking data, and hook ownership unless changes are in scope.

## Read Botlake-owned guidance

Start with `botlake --help` for setup/lifecycle discovery and `bl -h` for lake operations. Follow the relevant subcommand help, and read `bl prime OP` before using an unfamiliar operation. Use `botlake lake info` to locate selected extensions' documentation. Let these sources own configuration, dependency installation, lifecycle commands, and operational verification; do not reproduce their procedures here or in repository instructions.

## Compose the setup

- For a new lake, use the current `.botlake/` configuration in the local dots checkout (`~/dev/dots`) as the default template. Read it at setup time, select its configuration and supporting files, and adapt repository-specific names and paths while preserving instruction symlinks. Do not copy databases, installed dependencies, or other runtime state. If the checkout is unavailable, ask for its location rather than using a stale snapshot.
- When setup introduces package tooling or changes package-manager/workspace arrangements, first follow [Existing Node tooling and workspaces](node-workspaces.md). Resolve those choices before installation, then follow Botlake's current initialization guidance for the agreed layout.
- In an existing Bun repository, include lake configuration in the root workspace and applicable lint, formatting, and typechecking coverage. Keep dependency ownership with the lake package; report integration gaps rather than silently excluding it.
- When tool pins or project bootstrap change, follow [Tooling and bootstrap with mise](mise-bootstrap.md). Reuse its setup entrypoint instead of creating a separate bootstrap workflow here.

## Consent and required outcomes

An explicit Botlake setup request permits lake restarts needed to activate that configuration, not supervisor restarts; obtain separate confirmation for those. A review-only request does not authorize lifecycle changes.

With setup execution authorized, follow current Botlake guidance to activate and verify the lake. Require evidence that the intended configuration and extensions are loaded, the expected operations are available, and any workspace/check integration includes the lake package. Report exact checks, blockers, and untested behavior; configuration files alone are not evidence of a running lake.
