# Busy Bee workflows

Workflow-only dependencies are declared here as part of the root Bun workspace. In each checkout, one install from the repository root prepares the root formatting tools, Oven, and these workflows using the root `bun.lock`:

```nu
bun install --frozen-lockfile
```

Verify that Busy Bee can import the definition:

```nu
busybee input-schema do-work --json
```
