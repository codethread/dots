## Communication protocol

When the user asks for shell code to run themselves, provide working `nushell` examples not bash

## Tool execution

- Run full test/check/quality suites through `qlock` on `/tmp/millstrand-test.lock`; read `qlock -h` first. Focused tests do not require the lock.

## Development practices

- Do not consider backwards compatible systems, modules or flags unless explicitly stated in the project rules, when creating or modifying features
- Always load the robustness skill when writing code or reviewing
- Code should be built for to work as intended, it should not have guards in the code to protect against dead code or deprecated approaches being used; this is noise in the codebase
- When TDD adds a test solely to verify removal of old behavior, delete the test after the implementation passes and the removal has been verified; do not retain superfluous tests.

## Git, Worktrees and Repo Discovery

- Investigate unexpected state (unfamiliar files, branches, lock files) before deleting or overwriting
- clone external repos with `clone --help`;
- use `wktree -h` instead of raw git worktree commands when operating on git branches or worktrees.
- vendored repos go to `~/dev/vendor` for discovery/study, personal repos go to `~/dev/projects`
