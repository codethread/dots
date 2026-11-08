# Minimal Neovim configuration

- Keep this root independently loadable; it must not rely on modules or plugin state from `config/nvim`.
- Read installed Neovim help before changing runtime APIs or options.
- Validate against the minimal root and its own plugin assumptions using [the Neovim verification checks](../../docs/verification.md#neovim); parsing a file does not prove plugin startup or UI behavior.
