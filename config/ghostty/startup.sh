#!/usr/bin/env bash
# :module: Ghostty shell bootstrap

set -euo pipefail

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.local/cache}"
export DOTFILES="${DOTFILES:-$HOME/dev/dots}"
export EDITOR="${EDITOR:-nvim}"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
export HISTFILE="${HISTFILE:-$XDG_STATE_HOME/bash/history}"
export VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
export CARGO_HOME="${CARGO_HOME:-$XDG_DATA_HOME/cargo}"
export CARGO_BIN="${CARGO_BIN:-$CARGO_HOME/bin}"
export CODEX_HOME="${CODEX_HOME:-$XDG_CONFIG_HOME/codex}"

bootstrap_path=(
  "$HOME/.local/bin"
  "$CARGO_BIN"
  "$VOLTA_HOME/bin"
  "$HOME/.bun/bin"
  "/etc/profiles/per-user/${USER}/bin"
  "/run/current-system/sw/bin"
  "/nix/var/nix/profiles/default/bin"
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  "/usr/local/bin"
  "/usr/bin"
  "/bin"
  "/usr/sbin"
  "/sbin"
)

PATH="$(IFS=:; echo "${bootstrap_path[*]}")${PATH:+:$PATH}"
export PATH

if command -v nu >/dev/null 2>&1; then
  exec nu --login --interactive
fi

if [[ -n "${SHELL:-}" ]] && [[ -x "${SHELL}" ]]; then
  echo "nu not found; falling back to SHELL=${SHELL}" >&2
  exec "${SHELL}" -l
fi

echo "nu not found in expected locations or PATH" >&2
exit 1
