## Ways of working

- use `$TMPDIR="/tmp/claude"`

## Tool execution

- Run full test/check/quality suites under the shared lock: `flock -w 180 /tmp/millstrand-test.lock <command>`. Focused tests do not require the lock.
  - If lock acquisition times out, try up to 10 times total, then run `tmux-agent-switch --json` to check whether other agents are actively working. If the lock is deadlocked, terminate its holder to clear it, then retry.

## Git, Worktrees and Repo Discovery

- Investigate unexpected state (unfamiliar files, branches, lock files) before deleting or overwriting
- clone external repos with `nu -l -c "clone --help"`;
- use `wktree -h` instead of raw git worktree commands when operating on git branches or worktrees.
- vendored repos go to `~/dev/vendor` for discovery/study, personal repos go to `~/dev/projects`
