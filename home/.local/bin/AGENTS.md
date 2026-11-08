# Local helpers

- Keep helpers self-contained Zsh command composition, normally no more than about 200 lines. Move dependency-heavy, asynchronous, shared, or test-worthy logic to Oven.
- Give each command a `:module:` description, executable mode, and `-h` or `--help` output that states its contract.
- Keep shell logic direct; do not add a standalone test harness. If behavior needs unit tests, implement it in Oven instead.
- The home group follows filesystem entries, including untracked helpers; adding a source does not authorize applying its live link.
- Run the shell checks in [the verification guide](../../../docs/verification.md#shell-environment-and-helpers).
