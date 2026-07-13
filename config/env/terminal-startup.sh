#!/usr/bin/env bash
# :module: Terminal shell bootstrap

set -euo pipefail

source "${HOME}/.config/env/base.sh"

if ! command -v nu >/dev/null 2>&1; then
  echo "nu not found after shared environment bootstrap" >&2
  exit 1
fi

exec "${SHELL}" --login --interactive
