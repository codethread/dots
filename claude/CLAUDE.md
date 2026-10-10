## Ways of working

- Set `TMPDIR` to `/tmp/claude`.

## Tool execution

- Run full test/check/quality suites through `qlock` on `/tmp/agent-cpu.lock`; focused tests need no lock. Read `qlock -h` for usage.

## Git, Worktrees and Repo Discovery

- Use `clone --help` when cloning external repositories.
    - `clone` vendors repositories in `~/dev/vendor` and personal repositories in `~/dev/projects`.
