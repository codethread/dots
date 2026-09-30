#!/usr/bin/env bash
# :module: Terminal shell bootstrap

set -euo pipefail

# base.sh resolves SHELL to an absolute executable, failing if it cannot.
source "${HOME}/.config/env/base.sh"

exec "${SHELL}" --login --interactive
