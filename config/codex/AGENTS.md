## Tool execution

- Run full test/check/quality suites through `qlock` on `/tmp/agent-cpu.lock`; focused tests need no lock. Read `qlock -h` for usage.

## Development practices

- Do not consider backwards compatible systems, modules or flags unless explicitly stated in the project rules, when creating or modifying features
- Always load the robustness skill when writing code or reviewing
- Code should be built to work as intended, it should not have guards in the code to protect against dead code or deprecated approaches being used; this is noise in the codebase
- When TDD adds a test solely to verify removal of old behavior, delete the test after the implementation passes and the removal has been verified; do not retain superfluous tests.

## Git, Worktrees and Repo Discovery

- Use `clone --help` when cloning external repositories.
    - `clone` vendors repositories in `~/dev/vendor` and personal repositories in `~/dev/projects`.
