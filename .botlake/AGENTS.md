# Botlake lake

- `.botlake/package.json` uses relative dependencies that assume the durable dots checkout at `~/dev/dots` and the managed Botlake sibling at `~/dev/projects/botlake`; another checkout layout does not represent bootstrap runtime.
- All linked dots worktrees share this lake and its machine-local database, so configuration changes affect concurrent worktree sessions after restart.
- After configuration or shared-module changes, follow [agent-assets and external-handoffs verification](../docs/verification.md#agent-assets-and-external-handoffs) to restart and inspect the loaded extension snapshot.
