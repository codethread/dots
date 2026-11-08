# Oven

- Public commands are executable `bin/<name>.ts` entrypoints deployed without extensions. Add each target to root `tasks.link`; that narrowed task does not infer new wildcard matches.
- README generation executes every `bin/*.ts -h` concurrently, without deployed links. It extracts a `<command> - <description>` line anywhere in help, or a description after Commander-style `Usage:`. Regenerate `README.md` through the build gate.
- Keep importable logic free of module-level execution; invoke the CLI under `if (import.meta.main)`. Reusable implementation belongs in `shared/`.
