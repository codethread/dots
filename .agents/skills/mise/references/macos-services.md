# macOS service deployment with mise

Use this reference when replacing nix-darwin jobs or deploying macOS user services. Verified with Homebrew mise 2026.9.15 in September 2026; consult current [launchd](https://mise.jdx.dev/bootstrap/launchd.html), [services](https://mise.jdx.dev/bootstrap/services.html), and [bootstrap order](https://mise.jdx.dev/bootstrap.html#how-it-runs) docs before assuming the same behavior in another version.

## Choose the declaration

- `[bootstrap.macos.launchd.agents.<name>]`: native argument vectors, working directory, environment, explicit log paths, KeepAlive, intervals, and calendar arrays. Appropriate for scheduled jobs and services needing macOS-specific controls.
- `[bootstrap.services.<name>]` with `scope = "user"`: generic background service lifecycle, including `state = "absent"` and `requires_tools = true`. On macOS, `restart = "always"` corresponds to unconditional KeepAlive; the default is only on failure. `requires_tools` controls installation order, not automatic mise environment wrapping.
- Neither needs pitchfork. A foreground `mise run` task can be launched by launchd, but tasks alone do not provide login persistence.

Both tables produce labels `dev.mise.<name>` and must not use the same name. User agents need a GUI launchd domain and run as the logged-in user; they are not root LaunchDaemons.

## Prepare, then apply

In the verified bootstrap order, raw LaunchAgents are loaded **before** `[tools]` installation and the final `bootstrap` task. Generic user services with `requires_tools = true` wait for tools, but still precede the final task. Do not install application dependencies in a final task and assume the service will wait.

Use explicit preparation and apply tasks with a dependency, or another ordering that demonstrably completes prerequisites before service loading:

1. Install tools and ensure the intended checkout exists.
2. Install application dependencies using its lockfile.
3. Check required credentials without printing their values. Keep secrets in the application's existing local file or runtime environment, not rendered plists.
4. Create log/state directories. mise creates the LaunchAgents directory, not arbitrary application log directories.
5. Retire any previous owner, then apply the agents.

Run the direct command for a genuinely non-installing preview, using the intended profile:

```nu
mise -E dev bootstrap macos launchd-agents apply --dry-run
```

A task containing that command can still install `[tools]` before the dry run begins. `status --missing` checks definitions/load state, not readiness.

## Executables, config, and working directory

LaunchAgents inherit launchd's minimal environment, not shell activation. Use a durable executable path, explicit HOME/PATH where needed, and `mise exec` or a foreground task for mise-managed tools. Homebrew's stable mise symlink can survive later Nix removal; a versioned Cellar binary or `/nix/store` path cannot be assumed durable across cleanup. Use the host's actual installation prefix.

A service launched with `mise -C <dotfiles> -E <profile> run <task>` can load tools from the dotfiles project while the task's `dir` selects the application checkout. This was verified with Bun and an app-local `.env`. Plain `mise -C <dotfiles> exec` changes the child's working directory too; do not assume a plist `working_directory` overrides it.

`{{ config_root }}` refers to the declaring config's directory and becomes an absolute path in the generated plist. Apply production jobs from a durable checkout, not a worktree you intend to remove. Select profiles explicitly; login jobs do not inherit your terminal's `MISE_ENV`.

Path fields such as `program`, `working_directory`, and log paths expand `~/`. `args` do **not** expand tilde or shell variables: use templates for those values. Shell pipelines require an explicitly invoked shell or script.

## Hand off ownership and verify lifecycle

Nix, Git's own scheduler, and mise use different labels: applying mise does not stop earlier jobs. Inspect live labels and plists before switching. Refuse an apply that would leave two copies active. Prefer switching the updated Nix configuration first; user-domain disable/bootout is a scoped alternative when authorized, not permission to alter unrelated system services.

Deleting a mise declaration does not prune its installed job. Remove explicitly, or use `state = "absent"` with the generic user-service API. Treat cleanup separately from applying new definitions.

Check these observable outcomes:

- Generated plists pass `plutil -lint`; schedules, log paths, executable paths, and environment match the intended source.
- The old labels are absent, and the new labels are loaded. For scheduled jobs, idle is normal; run one and inspect its last exit code and logs.
- The application is actually ready: health endpoint, socket, or another meaningful probe. A successful apply can return before a Bun server writes its port file or starts listening.
- Shutdown is also asynchronous. An immediate process/sentinel check after `bootout` can still see the exiting child. Confirm cleanup has completed before starting the replacement, rather than treating one immediate snapshot as a leak.
- For raw LaunchAgents, an unchanged second apply preserves the running PID. Updating source or a runtime without changing the plist requires an explicit restart; reapplying an unchanged definition is not a restart. `kickstart = true` requests an immediate run when an agent is applied, not a forced restart of an already-loaded unchanged job. Generic built-in services can have different lifecycle behavior; consult their docs.

Use observable bounded readiness checks for automation, not an arbitrary sleep or unbounded polling. Do not send real notifications merely to test a notification server when its health endpoint suffices.

## Native tool boundaries

A macOS-only runner can use `/usr/bin/git` and `/bin/bash` instead of carrying Nix executables across the migration; first verify the required flags against the installed versions. Preserve workload-specific policy such as filtered repository lists and private Git configuration rather than assuming `git maintenance start` is equivalent.

For manual Git-maintenance validation, use disposable repositories with a committed, packed object. Native Git's daily incremental repack can fail on an empty repository with "no pack files to index"; distinguish a poor fixture from a migration regression.

An installed Homebrew cask can still fail `brew info` when its tap is untrusted. Report that separately from mise failures; do not broaden tap trust just to make an unrelated verification command pass.
