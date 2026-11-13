# Botlake lake

Install dependencies from the checkout root with `bun install --frozen-lockfile`; the root workspace and lockfile own this package. Shared configuration comes from `@botlake/extension-ct-config`. `mise run build` includes lake lint, formatting, and typechecking. Linked worktrees share the main checkout’s lake and database. For config changes, follow the [restart and snapshot check](../docs/verification.md#agent-assets-and-external-handoffs).
