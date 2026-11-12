# Projects host setup

Use this reference for a host used to develop personal and public projects. Read the current instructions and setup documentation in the relevant local source repositories rather than copying their installation recipes into this skill.

Start with `~/dev/dots/AGENTS.md`, `docs/components.md`, and `docs/verification.md` in that checkout for shared host setup, profile selection, ownership, and verification. A projects host does not imply the dots `personal` profile; select the profile according to the host's documented role. Load the `mise` skill when mise-managed host setup is in scope.

## Key project sources

Use the repositories relevant to the requested setup, not every checkout beneath `~/dev/projects/`:

| Source checkout             | Consult for                                                              |
| --------------------------- | ------------------------------------------------------------------------ |
| `~/dev/dots`                | Dot repos and wider configuration                                        |
| `~/dev/projects/agents`     | Agent harness integrations, extensions, themes, and skill bundles        |
| `~/dev/projects/botlake`    | Botlake installation, lake configuration, and extension documentation    |
| `~/dev/projects/botlake-ui` | Sibling to botlake, runs PWA                                             |
| `~/dev/projects/skillbox`   | Repository skill management and bundled authoring/configuration guidance |
| `~/dev/projects/qlock`      | Shared command queues and test/check locking                             |
| `~/dev/projects/wktree`     | Worktree management and setup conventions                                |

Read each selected checkout's `AGENTS.md` when present and its README, then follow its current tool-owned skills and documentation. Preserve the owning repository's setup and verification procedures. If a needed checkout is missing, report it and ask for its location or authorization to obtain it; do not assume every project is installed or required.

Inspect and propose changes first. A request to review host setup is not authorization to install tools, apply dotfiles to the real home, start services, or bootstrap the workstation. After authorized changes, use the owning repositories' checks and report what was verified, skipped, or remains untested.
