#!/bin/bash
# :module: Start the dots lake and mise-supervised Homebrew Botlake, preserving external supervisors.
set -euo pipefail

case "${1:-}" in
  -h|--help) echo 'Usage: boot/start-botlake.sh (also run by mise bootstrap)'; exit 0 ;;
  '') ;;
  *) echo "Unexpected argument: $1" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/opt/botlake/bin:$HOME/.local/bin:/opt/homebrew/bin:$PATH"
botlake=/opt/homebrew/opt/botlake/bin/botlake

# An unreachable supervisor needs normal startup; keep its diagnostic visible.
if status=$("$botlake" status); then
  botlake_pid=$(jq -er '.pid | numbers' <<<"$status")
  managed_pid=$(mise daemons status botlake-supervisor --json | jq -r '.pid')
  if [ "$botlake_pid" != "$managed_pid" ]; then
    printf 'WARN: Botlake PID %s is running outside mise; skipping managed supervisor startup. To hand over ownership when safe, run %s stop, then mise daemons start botlake-supervisor.\n' "$botlake_pid" "$botlake" >&2
  else
    mise daemons start botlake-supervisor
  fi
else
  mise daemons start botlake-supervisor
fi

exec "$botlake" lake start --workspace "$PWD"
