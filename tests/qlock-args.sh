#!/usr/bin/env bash
# Regression checks for qlock's value-taking options.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QLOCK="${QLOCK:-$ROOT/home/.local/bin/qlock}"

for option in -w -E --urgent --ticket; do
  for kind in missing empty; do
    args=("$option")
    if [[ $kind == empty ]]; then args+=(""); fi
    status=0
    output=$("$QLOCK" "${args[@]}" 2>&1) || status=$?
    expected="qlock: $option requires a value (see qlock -h)"
    if [[ $status != 2 || $output != "$expected" ]]; then
      printf 'FAIL: %s %s value: expected exit 2 and "%s", got exit %s and "%s"\n' \
        "$option" "$kind" "$expected" "$status" "$output" >&2
      exit 1
    fi
  done
done

printf 'qlock argument checks passed (8 cases)\n'
