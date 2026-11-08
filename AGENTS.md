# Dotfiles Monorepo

## Working boundaries

- Work from the selected checkout; bootstrap jobs embed its path, so only a durable checkout may be applied to a workstation.
- Use `wktree` for worktree lifecycle operations. Preserve existing assignments and human decisions when using Botlake; run `bl prime work` before tracking and `bl prime agent` before delegation.
- Run full test, check, or quality suites with `qlock exec --lock /tmp/agent-cpu.lock -w 180 -- <command>`; focused checks do not need the lock.
- Keep `core.hooksPath = .githooks`; the pre-commit hook formats staged Markdown and Nushell files.

## Ownership and profiles

- Read [docs/components.md](docs/components.md) before changing bootstrap ownership, profile layering, deployed files, or application boundaries.
- Run mise from the checkout so `.miserc.toml` can enable environment-suffixed config; `mise -C` from elsewhere does not reproduce early discovery.
- Mise owns deployed links. Stage new files in Git before previewing `manifest = "git"` groups; a file absent from the index is absent from deployment.
- Use the repository-root Bun workspace and lockfile. Dependency declarations stay in their owning package; nested lockfiles and package-manager pins create a second source of truth.
- Treat `claude/CLAUDE.md`, `config/codex/AGENTS.md`, and `pi/agent/agent.njk` as deployed global policy payloads, not repository contribution guides.

## Change workflow

1. Read the nearest nested `AGENTS.md`; it contains the hidden constraints for that component.
2. Make the smallest ownership-consistent change. Prefer native mise resources for bootstrap state and Oven for logic that needs dependencies, async behavior, or tests.
3. For command removal or renaming, retire the deployed path while its old declaration still exists; ordinary wildcard dotfiles do not reconcile removed commands.
4. Completion requires every matching check in [docs/verification.md](docs/verification.md); relevant checks are non-negotiable after every change.
5. Report each check actually run and its result, then list every exact untested behavior or blocker. A partial preview is not completion evidence.

## Safety

- Bootstrap and direct subsystem applies mutate the host. Use only the read-only checks identified in the verification guide unless host changes are explicitly authorized.
- Full bootstrap preserves the required ordering between preparation, dotfiles, LaunchAgents, and services; it still has host-visible effects and requires explicit authorization.
- Removing a tool includes its code, owned documentation, and direct consumers. Use one commit titled `GOODBYE <tool>` with the reason in the body.
