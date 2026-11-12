# Work host setup

Use `~/pb/adam.hall/workfiles` as the source of truth for work-specific host setup. This private repository is not expected on non-work machines.

- If the directory is absent, safely skip work-specific setup and report it as not applicable on this machine. Do not treat its absence as an error, clone it, request credentials, or create a replacement.
- If it is present, read its `AGENTS.md` when available, README, and current setup documentation before proposing changes. Follow its documented entrypoints and checks rather than embedding private installation recipes here. Report unreadable or invalid existing sources as blockers rather than treating them as absent.
- For shared host setup and the boundary between dots and workfiles, read `~/dev/dots/AGENTS.md`, `docs/components.md`, and `docs/verification.md` in that checkout. Keep wholly work-specific configuration owned by workfiles. Load the `mise` skill when mise-managed host setup is in scope.

Preserve local changes in workfiles; do not pull, reset, or clean it as part of discovery. Obtain authorization before applying real-home changes, installing tools, running bootstrap, or operating services. After authorized changes, follow workfiles' current verification guidance and report checks passed, blockers, and exact untested behavior. Keep private work configuration in its source repository rather than copying it into this skill.
