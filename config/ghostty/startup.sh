#!/usr/bin/env bash

set -euo pipefail

# XDG Base Directory Specification
export XDG_CONFIG_HOME=~/.config
export XDG_DATA_HOME=~/.local/share
export XDG_STATE_HOME=~/.local/state
export XDG_CACHE_HOME=~/.local/cache

# Build tools
export CARGO_BIN=~/.local/share/cargo/bin
export VOLTA_HOME=~/.volta
export PATH=~/.local/bin:/opt/homebrew/bin:${CARGO_BIN}:~/.volta/bin:${PATH}

# Custom flags
export KSM_WORK=1
export FZF_DEFAULT_OPTS="--color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97,border:#44415a,header:#3e8fb0,gutter:#232136,spinner:#f6c177,info:#9ccfd8,pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"

# Exec into shell with login/interactive flags
exec ~/.local/bin/nu --login --interactive
