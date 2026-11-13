# Component ownership

## Machine roles

Dots converges an Apple Silicon Mac from a durable checkout: registered jobs embed its path. Linux is a configuration/command portability target, not a full-bootstrap target.

[Profile selection](../config/env/base.sh) preserves explicit `MISE_ENV`; otherwise work identity selects `work`, `codethread` selects `personal`, and other accounts select `dev`.

- **Personal:** daily-use laptop without development services.
- **Dev:** public-project development host; SSH policy permits only `ct`, but Remote Login remains manual.
- **Work:** shared setup followed by the private workfiles handoff. Mixed personal/work files stay in dots; wholly work-specific files, overlays, tools, and services belong to workfiles.

[Workfiles](../boot/workfiles.sh) trusts existing checkouts without pulling, resetting, or cleaning. Missing credentials skip a missing checkout visibly.

## Convergence and deployment

Mise owns declarative state; [setup](../boot/setup.sh) prepares dependencies that native resources cannot. Checkout [`.mise/conf.d/`](../.mise/conf.d/) links expose tools/services before global links exist. Preserve the dependency order: PAM safety and Ruby before packages; remaining tools before repositories; repository builds, links, and daemon registration before dotfiles and LaunchAgents. Moving preparation to the final bootstrap task is too late. Failed phases leave earlier changes applied.

The [home group](../mise.toml) includes untracked filesystem entries; Git-manifest groups deploy only indexed files. Stage additions before previewing them. Linked-file edits are immediate; additions and renames need another apply. Ordinary wildcard commands do not reconcile removals: retire the old target with an authorized `mise dot unapply ~/.local/bin/<old-command>` while its declaration and source still exist.

Keep destination directories real so application-owned credentials, sessions, and metadata survive deployment.

[Global agent instructions](../templates/agents/README.md) share a Markdown base rendered by mise. `mise run link` applies the three generated global files alongside symlinks; Pi keeps its session-dependent Nunjucks rules in place.

Settings have deliberately different ownership:

- [Claude](../templates/claude-settings.json.tera) renders the whole owned file. Workfiles overlays override ordinary keys, but permission lists are unioned: overlays can add permissions, not revoke base permissions. Malformed overlays fail.
- [Codex](../templates/codex-config.toml) merges owned keys, preserves target-only keys, and replaces arrays. Removing a source key does not delete the target key.

## Runtime owners

Use [Oven](../oven/AGENTS.md) for dependencies, async behavior, shared logic, or tests; keep self-contained shell composition in [local helpers](../home/.local/bin/AGENTS.md).

Vendor installers own Claude, Codex, Pi, and Pi-Bolt through [mise-llm](../home/.local/bin/mise-llm). External repositories own their builds and behavior; dots owns preparation, linking, and scheduling. Preserve the pinned Todoist fork's API contract.

Pitchfork owns daemon supervision; launchd starts its single durable supervisor. Separate LaunchAgents are reserved for macOS scheduling/lifecycle requirements, not duplicate daemon ownership. Their environments cannot depend on interactive shell activation.

Homebrew owns the Botlake CLI binaries; the `botlake-supervisor` mise daemon uses their stable opt path. Do not also enable its Homebrew service. Source checkouts do not install global CLIs during bootstrap; each lake retains its own Core and extensions. See [Botlake operations](botlake.md) for upgrades, restart impact, and lake recovery.

Login shells rebuild the [baseline environment](../config/env/base.sh); non-login children preserve the active project environment. Tmux imports that baseline through `config/env/emit.sh --tmux`, not interactive startup.

[Theme](../oven/bin/theme.ts) applies locally before forwarding explicit mode/family to a selected host; the receiver never forwards. Failures retain local changes, so retry an explicit mode, not `toggle`. Rex is never auto-started and shares no sessions with tmux. Rex palettes follow customized Kitty palettes; preserve their [Rose Pine](../config/rex/themes/LICENSE-rose-pine) and [TokyoNight](../config/rex/themes/LICENSE-tokyonight) licenses.
