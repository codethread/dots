# Neovim configuration

- Read the installed Neovim help before changing APIs, options, commands, or events; local help matches the runtime under test.
- Keep full-config modules under this root and test them with this root's plugin and runtime assumptions. Do not use the minimal configuration as a behavioral fixture for the full configuration.
- Notes behavior depends on the configured notes root; tests and fixtures must use temporary roots rather than the user's live notes directory.
- Run the parse and focused behavior checks in [the verification guide](../../docs/verification.md#neovim). State which plugin, UI, or external-tool paths remain untested.
