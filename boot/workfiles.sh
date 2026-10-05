#!/bin/bash
# :module: Hand off work setup to its private repository after common dots setup.
set -euo pipefail

usage() { echo 'Usage: workfiles.sh <gitlab-host> <namespace/repo> <checkout>'; }
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
[ "$#" -eq 3 ] || { usage >&2; exit 2; }
host=$1
repo=$2
checkout=$3

# boot.sh uses repo-backed config until dotty runs. The handoff runs afterwards.
if [ "${XDG_CONFIG_HOME:-}" = "${DOTFILES:-}/config" ]; then
  export XDG_CONFIG_HOME="$HOME/.config"
fi

if [ ! -e "$checkout/.git" ]; then
  if [ -e "$checkout" ]; then
    echo "Workfiles checkout exists but is not a Git repository: $checkout" >&2
    exit 1
  fi
  if ! glab auth status --hostname "$host" >/dev/null 2>&1; then
    echo "WARN: Work setup skipped: authenticate with 'glab auth login --hostname $host', then rerun dots bootstrap." >&2
    exit 0
  fi
  mkdir -p "$(dirname "$checkout")"
  if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes' \
    glab repo clone "https://$host/$repo" "$checkout"; then
    echo "WARN: Could not clone $host/$repo. Check GitLab access and Git credentials, then rerun dots bootstrap. Work setup skipped." >&2
    exit 0
  fi
fi

# Existing checkouts are local input: no auth check, pull, reset, or clean.
cd "$checkout"
mise trust "$checkout"
exec make
