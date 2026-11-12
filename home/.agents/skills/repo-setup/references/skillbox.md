# Skills with Skillbox

Use Skillbox to manage repository-local skills. Its bundled skills are the source of truth for configuration, migration, authoring, and verification; do not duplicate those procedures here or in repository instructions.

```sh
bunx skillbox skills -h
bunx skillbox skills list
```

Select the relevant skill from the list and load it with `bunx skillbox skills get <name>`. Load its referenced resources on demand with `bunx skillbox skills file <name> <path>`. Follow that guidance, including its completion checks.

Keep instruction-file setup in [Shared instructions](shared-instructions.md). When tool pinning or repeatable project bootstrap is also in scope, follow [Tooling and bootstrap with mise](mise-bootstrap.md) alongside the selected Skillbox guidance.

In `AGENTS.md`, point agents to `bunx skillbox skills list` when adding or editing skills rather than copying the bundled procedures.
