#!/bin/bash
# :module: Repo-specific setup after mise provisions packages, tools, files, and repos.
set -euo pipefail

case "${1:-}" in
  -h|--help) echo 'Usage: mise bootstrap (runs this post-repos hook)'; exit 0 ;;
  '') ;;
  *) echo "Unexpected argument: $1" >&2; exit 2 ;;
esac
: "${DOTFILES:?Run through mise bootstrap}"

warnings=()
warn() {
  warnings+=("$1")
  printf 'WARN: %s\n' "$1" >&2
}
optional() {
  local label=$1
  shift
  # Call external commands so their own fail-fast behavior stays intact.
  if "$@"; then return 0; fi
  warn "$label failed; that tool may be unavailable. Fix the error above and rerun bootstrap."
}
summary() {
  if ((${#warnings[@]})); then
    printf '\nBootstrap setup warnings:\n' >&2
    printf '  WARN: %s\n' "${warnings[@]}" >&2
  fi
}
trap summary EXIT

# Official installers own agent CLIs; their updates remain a separate task.
optional 'Agent CLI setup' "$DOTFILES/home/.local/bin/mise-llm" install
optional 'Playwright CLI installation' env NPM_CONFIG_PREFIX="$HOME/.local" npm install --global @playwright/cli
for extension in $DOTS_VSCODE_EXTENSIONS; do
  optional "VS Code extension $extension" "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" --install-extension "$extension"
done

# The pinned Todoist fork commits its generated parser; no goyacc step is needed.
optional 'Todoist build' /bin/bash -c 'cd "$HOME/dev/vendor/todoist" && go build -trimpath -o "$HOME/.local/bin/todoist" .'
# Each repo owns its install/build/link steps behind a default mise task.
# Hive's canonical checkout owns its launchers and tracker, not a feature worktree.
(
  cd "$HOME/dev/projects/hive"
  mise trust mise.toml
  mise run
)
( cd "$HOME/dev/projects/agents" && mise run )

nu -n -I "$DOTFILES/config/nushell/scripts" -c 'use ct/dotty; dotty link --no-cache ($env.DOTFILES | path join "config/dotty/dotty.toml") | ignore'
git -C "$DOTFILES" config core.hooksPath .githooks
"$DOTFILES/boot/shell.sh"
# Development verification (including fixes and docs) belongs to make build.
optional 'Oven installation/build' mise -C "$DOTFILES/oven" exec -- /bin/bash -c 'bun install --frozen-lockfile && bun run build'

# launchd loads later in native bootstrap, after the gitwatch dotfile is linked.
# Check its real execution PATH; gitwatch itself is linked in the next phase.
for cmd in bash git fswatch greadlink; do
  PATH="$SYNCENGINE_PATH" command -v "$cmd" >/dev/null || {
    echo "Missing syncengine dependency: $cmd. Apply bootstrap packages first." >&2
    exit 1
  }
done
[ -f "$HOME/dev/vendor/gitwatch/gitwatch.sh" ]

if [ -n "$GIT_MAINTENANCE_REPOSITORIES" ]; then
  (
    cd "$HOME/dev/projects/cc-notify"
    bun install --frozen-lockfile
    # Link the CLI into ~/.local/bin before dependent LaunchAgents load.
    make link-bin
    # Warn without blocking other services; cc-notify owns runtime validation.
    bun -e 'const missing = ["PUSHOVER_CC_KEY", "PUSHOVER_DEV_KEY"].filter(key => !process.env[key]);
      if (missing.length) console.error(`WARN: cc-notify is missing ${missing.join(", ")}. Notifications will not work until configured in ~/dev/projects/cc-notify/.env. Bootstrap will continue; inspect ~/.local/state/com.codethread.cc-notify/std.log after startup.`);'
  )
  "$DOTFILES/home/.local/bin/git-maintenance" register
fi
