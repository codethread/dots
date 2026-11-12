# Shared instructions

For new repositories, use `AGENTS.md` as the real instruction file, with a relative sibling `CLAUDE.md -> AGENTS.md` symlink.

Create the real target before the relative symlink. Preserve existing arrangements and instructions unless conversion is requested. Do not overwrite independent files to create links; resolve conflicting content with the user first.

Keep repository instructions project-specific: explain setup, development and verification commands, important directories, and local conventions. Reference tool-owned guidance rather than copying its procedures into `AGENTS.md`.

For skill installation, migration, authoring, or harness discovery, follow [Skills with Skillbox](skillbox.md). Delegate installation paths and discovery-link handling to its current guidance rather than creating or repairing skill links as part of instruction setup.

Verify the instruction link resolves to `AGENTS.md`, preserves its contents, and is discoverable by the selected harnesses. Report any harness behavior that was not tested.
