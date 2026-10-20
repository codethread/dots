# Busy Bee workflows

Workflow-only dependencies are declared here as part of the root Bun workspace. In each checkout, one install from the repository root prepares the root formatting tools, Oven, and these workflows using the root `bun.lock`:

```nu
bun install --frozen-lockfile
```

Verify that Busy Bee can import the definition:

```nu
busybee input-schema do-work --json
```

Definitions are checkout-owned: upgrading Busy Bee does not update them, and `busybee init` does not overwrite an existing `do-work`. Before changing a definition, inspect unfinished runs with `busybee preflight do-work --json`. Use `busybee skills get workflow-authoring` for definition guidance and `busybee skills get workflow-execution` for run/visit brief reads and outcome delivery.
