# Oven

- Use Oven for utilities that need TypeScript, dependencies, async control, shared code, or tests; small self-contained PATH composition stays in `home/.local/bin/`.
- A public command is an executable `bin/<name>.ts` file. Its filename is the extensionless deployed command name; add the exact target to root `tasks.link` because the narrowed link task does not infer new wildcard matches.
- Start each public entrypoint with a `:module:` description and make help's first line `<command> - <description>` so generated command documentation can identify it.
- Keep importable behavior free of module-level execution. Export core logic and invoke the CLI only under `if (import.meta.main)`.
- Put reusable implementation in `shared/`; keep entrypoints responsible for parsing, invoking core logic, and reporting results.
- Removing or renaming a command requires an authorized `mise dot unapply ~/.local/bin/<old-command>` while the old source exists, followed by source and `tasks.link` changes. The wildcard declaration does not prune old ordinary dotfiles.
- Install from the repository root with the committed root `bun.lock`; Oven is a workspace member and must not gain a nested lockfile or package-manager pin.
- Complete the relevant focused and full checks in [the verification guide](../docs/verification.md#oven); review changes produced by the full suite before committing.
