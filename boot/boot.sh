#!/usr/bin/env bash
# :module: Bootstrap an Apple Silicon macOS workstation with Homebrew and mise.
set -euo pipefail

export DOTFILES="${DOTFILES:-${HOME}/dev/dots}"
PROFILE=""
GIT_BRANCH="main"

usage() {
  echo 'Usage: boot.sh [-p|--profile <dev|personal|work>] [-b|--branch <name>]'
  echo ''
  echo '  -p, --profile  Mise profile (default: shared shell identity / MISE_ENV)'
  echo '  -b, --branch   Git branch to clone (default: main)'
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--profile|-b|--branch)
      if [ $# -lt 2 ] || [ -z "$2" ] || [[ "$2" == -* ]]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      case "$1" in
        -p|--profile) PROFILE="$2" ;;
        -b|--branch) GIT_BRANCH="$2" ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

case "$PROFILE" in
  ''|dev|personal|work) ;;
  *) echo "Unknown mise profile: $PROFILE" >&2; exit 1 ;;
esac
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo 'boot.sh supports Apple Silicon macOS only' >&2
  exit 1
fi

cd "$HOME"
# The Homebrew installer also prepares Apple's Command Line Tools (including Git).
# Use the stable native prefix, even when an older environment is inherited.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
if [ ! -x /opt/homebrew/bin/brew ]; then
  echo 'Installing Homebrew'
  installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  /bin/bash -c "$installer"
fi
if [ ! -x /opt/homebrew/bin/mise ]; then
  /opt/homebrew/bin/brew install mise
fi

mkdir -p "$DOTFILES"
if [ ! -e "$DOTFILES/.git" ]; then
  if [ -n "$(ls -A "$DOTFILES")" ]; then
    echo "Dotfiles directory exists but is not empty: $DOTFILES" >&2
    exit 1
  fi
  if [ -d "$HOME/.ssh" ]; then
    clone_url='git@github.com:codethread/dots.git'
  else
    clone_url='https://github.com/codethread/dots.git'
  fi
  /usr/bin/git clone --branch "$GIT_BRANCH" "$clone_url" "$DOTFILES"
fi

# Preserve the repo-backed config root until dotty links ~/.config.
export XDG_CONFIG_HOME="$DOTFILES/config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.local/cache"
if [ -n "$PROFILE" ]; then export MISE_ENV="$PROFILE"; fi
source "$DOTFILES/config/env/base.sh"
case "$MISE_ENV" in
  dev|personal|work) ;;
  *) echo "Unknown mise profile: $MISE_ENV" >&2; exit 1 ;;
esac
mkdir -p "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

echo "Setting up workstation (profile: $MISE_ENV, branch: $GIT_BRANCH)"
echo 'If this script fails it can be rerun.'
# Start mise here so early .miserc.toml settings load before config discovery.
cd "$DOTFILES"
/opt/homebrew/bin/mise trust "$DOTFILES/mise.toml"
/opt/homebrew/bin/mise -E "$MISE_ENV" bootstrap

# Optional first-boot integration checks and editor plugin setup.
nu \
  --env-config "$DOTFILES/config/nushell/env.nu" \
  --config "$DOTFILES/config/nushell/config.nu" \
  --commands 'boot machine'

echo 'Complete. Open a new shell.'
