# macOS service deployment with mise

Use this reference when declaring or migrating macOS user services. Version-check against the installed CLI and current [LaunchAgent](https://mise.jdx.dev/bootstrap/launchd.html), [service](https://mise.jdx.dev/bootstrap/services.html), and [bootstrap order](https://mise.jdx.dev/bootstrap.html#how-it-runs) documentation. The behavior below was checked with mise 2026.10.4.

## Choose one owner

| Need | Declaration |
| --- | --- |
| One foreground command across macOS, Linux, and Windows | `[bootstrap.services.<name>]` with `scope = "user"` |
| Calendar schedule, launch events, queue directories, process type, or other launchd controls | `[bootstrap.macos.launchd.agents.<name>]` |

Both produce `~/Library/LaunchAgents/dev.mise.<name>.plist`; a name cannot appear in both.

A portable user service defaults to restart on failure. Set `requires_tools = true` when its command uses `[tools]`; this changes full-bootstrap ordering but does not wrap the command in mise or activate a shell. Use an absolute executable path or invoke the stable mise executable with `mise exec`/`mise run`.

Raw LaunchAgents support argument vectors, working directory, environment, log paths, KeepAlive variants, intervals, calendar arrays, queue directories, launch events, priority, and kickstart. They load in the logged-in user's `gui/<uid>` domain and are not root LaunchDaemons.

## Satisfy prerequisites before load

In 2026.10.4, ordinary services run before repositories and dotfiles; raw LaunchAgents run after repositories/dotfiles but before `[tools]`; services with `requires_tools = true` run after tools and plugin packages. The final `bootstrap` task runs after all of them.

Therefore:

- Use `requires_tools = true` for a portable service whose only late prerequisite is `[tools]`.
- Prepare raw LaunchAgent prerequisites in earlier declarative resources or hooks. A final bootstrap task is too late.
- If a workload needs a repository, dependencies, credentials, or log directories, place each prerequisite in a native phase that completes before its service loads. Replace preparation hooks when declarative directories, repositories, dotfiles, or a `requires_tools` user service provide the same ordering.
- Retain this repository's PAM/system checks because privileged convergence depends on them; do not treat unrelated existing hooks as constraints.
- Apply from a durable checkout because generated jobs can embed `{{ config_root }}`.

Preview the intended profile directly:

```sh
mise -E dev bootstrap macos launchd-agents apply --dry-run
mise -E dev bootstrap services apply --dry-run
```

A task that runs these commands may auto-install its own tools before the preview starts, so use the direct commands for a non-installing plan.

## Write launchd-safe commands

LaunchAgents inherit launchd's minimal environment, not shell activation or terminal `MISE_ENV`.

- Use the stable user-owned mise executable path configured by this repository, not a versioned package-manager Cellar path.
- Set required environment variables explicitly. Keep secrets in the application's established protected runtime source; do not render them into a plist.
- Select config environments explicitly in the command (`-E`) when the job depends on one.
- Use `{{ config_root }}` for a durable declaring project root and `{{ config_source }}` when the declaring file itself matters.
- `program` and `args` are an argument vector, not a shell command. Invoke a shell or script explicitly for pipelines and redirection.
- String values are Tera templates. Documented path fields expand `~`; prefer templates or absolute values in arguments rather than relying on shell expansion.
- Create application log/state directories before launchd writes to them.

A single-file `conf.d/*.toml` fragment retains the surrounding project root. A `conf.d/<name>/mise.toml` folder fragment has its own config root. Confirm the effective root before embedding paths.

## Hand off old ownership

Applying a mise job does not stop a differently labelled Git, Homebrew, or custom scheduler job. Before migration:

1. Inspect the old label, process, and plist.
2. Stop/remove the old owner in its own supported way.
3. Apply the mise declaration.
4. Confirm only one workload instance is active.

Deleting a mise declaration does not remove the installed job. Use:

```sh
mise bootstrap services remove <name>
```

This removes either kind of mise-owned user job, declared or not. For a portable service, `state = "absent"` can retain declarative retirement state.

## Verify behavior, not only files

After an authorized apply, verify:

- `plutil -lint` accepts the generated plist.
- Program, arguments, environment, working directory, schedule, and log paths match the declaration.
- `launchctl print gui/$(id -u)/dev.mise.<name>` shows the intended loaded job and useful last-exit state.
- The old label is absent and no duplicate process remains.
- The application passes a meaningful health check or scheduled test run.
- An unchanged second apply does not unexpectedly restart a healthy process.

`kickstart = true` requests `launchctl kickstart -k` after loading; use it deliberately because `-k` can replace a running instance. Reapplying a changed definition unloads the old job and stops its process before loading the replacement. Service shutdown and application readiness can be asynchronous, so use bounded observable checks rather than a fixed sleep.

Deleting a declaration or changing profiles can leave a previously installed job behind. Include explicit retirement in the migration plan instead of assuming profile selection prunes it.
