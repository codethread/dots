# Carapace completions

- Completion generation writes repository sources under `bridge/bash/` and `specs/`; it does not install live configuration.
- Stage generated sources before previewing native config-group deployment because the Git manifest ignores untracked files.
- Mise is the only linker for generated completions; use [native-link verification](../../docs/verification.md#native-links-and-settings) rather than adding a generator-owned installer.
