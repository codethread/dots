# Deployment templates

- Files here are deployment inputs, not live configuration. Editing a template does not authorize rendering or applying it to the user's home directory.
- `codex-config.toml` makes `CLAUDE.md` a fallback project-instruction filename; repository pairs must therefore keep `AGENTS.md` canonical and `CLAUDE.md` as its sibling symlink.
- Treat plugin, package, and skill declarations as discovery configuration: enabled metadata can advertise a skill or extension without proving its body loaded at runtime.
- Read templates before running status or diff because template functions may execute during rendering. Use only the read-only checks in [the verification guide](../docs/verification.md#native-links-and-settings).
