# Dots lake

This lake uses `ct-config` from `~/dev/projects/botlake`. The relative dependencies expect dots at `~/dev/dots`; bootstrap provisions the Botlake checkout and CLIs. Install the lake dependencies and start it with the existing supervisor running:

```sh
bun install --cwd .botlake
botlake lake start --workspace "$PWD"
bl help
bl work list --view all --state all
```

The manifest selects Batteries, Identity and the shared Flags, References, Agents, Priming, Work and Work–Agents descriptors. Configuration does not launch agents. Linked Git worktrees share this lake. Its database, dependency installation and local Bun lockfile are ignored.

After changing configuration or updating shared modules, run `botlake lake restart`; inspect the loaded snapshot with `botlake lake info`.
