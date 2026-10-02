## Ways of working

- use `$TMPDIR="/tmp/claude"`

## Tool execution

- Run full test/check/quality suites through `qlock` on `/tmp/millstrand-test.lock`; read `qlock -h` first. Focused tests do not require the lock.

## Git, Worktrees and Repo Discovery

- clone external repos with `clone --help`;
- use `wktree -h` instead of raw git worktree commands when operating on git branches or worktrees.
    - vendored repos go to `~/dev/vendor` for discovery/study, personal repos go to `~/dev/projects`
