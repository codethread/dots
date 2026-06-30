#!/usr/bin/env bash
# :module: Terminal shell bootstrap

set -euo pipefail

source "${HOME}/.config/env/bootstrap.sh"

exec "${SHELL}" --login --interactive
