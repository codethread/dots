## Ways of working

- use `$TMPDIR="/tmp/claude"`

## Tool execution

- Run full test/check/quality suites through `qlock` on `/tmp/millstrand-test.lock`; read `qlock -h` first. Focused tests do not require the lock.

## Git, Worktrees and Repo Discovery

- clone external repos with `clone --help`;
- use `honeycomb -h` instead of raw git worktree commands when operating on git branches or worktrees.
    - vendored repos go to `~/dev/vendor` for discovery/study, personal repos go to `~/dev/projects`

### Merge queues

Serialize every merge through `qlock --merge-target <branch>`, including `honeycomb finish`, direct Git merges, and GitHub/GitLab PR/MR merges. Read `qlock -h` first.

Resolve the destination before queuing: `honeycomb finish` uses origin's default branch; PRs/MRs use their base/target branch. Run from a checkout of the destination repository. `qlock` combines `honeycomb root` with the destination ref to select one local queue per repository and target branch; `main` and `refs/heads/main` select the same queue.

```bash
qlock -w 180 --merge-target main honeycomb finish --json
```

Replace `main` with the confirmed destination branch and supply the merge command's required arguments, such as `--title` for squash finish. Use the same flag with `gh pr merge`, `glab mr merge`, or Git merge commands.

Keep the final target refresh/revalidation, merge, required push, and completion confirmation inside the same lock; use a Bash script as the queued command when these need multiple steps. For remote merges, hold the lock until the merge completes, rather than releasing it after merely enabling auto-merge. On timeout (exit 75), continue with the existing ticket using `qlock await` and `qlock exec` as documented in `qlock -h`.
