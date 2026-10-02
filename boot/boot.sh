#!/bin/sh
# vim:foldmethod=marker:foldlevel=0

export DOTFILES="${DOTFILES:-${HOME}/dev/dots}"

cd "${HOME}" || exit 1

#: colors {{{
_cyan='\033[36m'
_red='\033[31m'
_reset='\033[0m'
#: }}}
#: flags {{{

NIX_PROFILE=""
GIT_BRANCH="main"

usage() {
  echo "Usage: boot.sh [-p|--profile <name>] [-b|--branch <name>]"
  echo ""
  echo "  -p, --profile  Nix profile to build (default: username-based on macOS)"
  echo "  -b, --branch   Git branch to clone (default: main)"
}

default_macos_profile() {
  case "$(id -un)" in
    adam.hall)
      echo "work-boot"
      ;;
    adamhall)
      echo "work-adamhall-boot"
      ;;
    codethread)
      echo "personal"
      ;;
    *)
      echo "dev"
      ;;
  esac
}

resolve_profile() {
  case "$1:$(id -un)" in
    work-boot:adamhall)
      echo "work-adamhall-boot"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--profile)
      if [ $# -lt 2 ] || [ -z "$2" ] || [ "${2#-}" != "$2" ]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      NIX_PROFILE="$2"
      shift 2
      ;;
    -b|--branch)
      if [ $# -lt 2 ] || [ -z "$2" ] || [ "${2#-}" != "$2" ]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      GIT_BRANCH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

#: }}}
#: profile {{{

if [ "$(uname)" != "Darwin" ]; then
  printf "${_red}( •_• )${_reset} Unsupported OS. boot.sh supports macOS only\n" >&2
  exit 1
fi

if [ -z "$NIX_PROFILE" ]; then
  NIX_PROFILE="$(default_macos_profile)"
fi
NIX_PROFILE="$(resolve_profile "$NIX_PROFILE")"

printf "${_cyan}( ◕ ◡ ◕ )${_reset} Setting up system (profile: %s, branch: %s)\n" "$NIX_PROFILE" "$GIT_BRANCH"
echo "If this script fails at any point it can be rerun"
echo ""

#: }}}
#: clone {{{

if [ ! -d "${DOTFILES}" ]; then
  printf "${_cyan}( ◕ ◡ ◕ )${_reset} Creating dotfiles directory: %s\n" "${DOTFILES}"
  mkdir -p "${DOTFILES}"
fi

if [ ! -d "${DOTFILES}/.git" ]; then
  if [ "$(ls -A "${DOTFILES}")" ]; then
    printf "${_red}( •_• )${_reset} Dotfiles directory exists but is not empty: %s\n" "${DOTFILES}" >&2
    exit 1
  fi

  printf "${_cyan}( ◕ ◡ ◕ )${_reset} Cloning dotfiles\n"
  _clone_url=""
  if [ -d "${HOME}/.ssh" ]; then
    _clone_url="git@github.com:codethread/dots.git"
  else
    echo "  (no ~/.ssh found, cloning via HTTPS)"
    _clone_url="https://github.com/codethread/dots.git"
  fi

  if command -v git >/dev/null 2>&1; then
    git clone --branch "$GIT_BRANCH" "$_clone_url" "${DOTFILES}"
  else
    echo "  (no git in PATH, using nix-shell)"
    nix-shell -p git --run "git clone --branch ${GIT_BRANCH} ${_clone_url} ${DOTFILES}"
  fi
fi

if [ ! -d "${DOTFILES}/.git" ]; then
  printf "${_red}( •_• )${_reset} Expected dotfiles checkout at %s but it was not found\n" "${DOTFILES}" >&2
  exit 1
fi

#: }}}
#: environment {{{

export XDG_CONFIG_HOME="${DOTFILES}/config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_CACHE_HOME="${HOME}/.local/cache"
# Preserve the repo-backed config root until dotty links ~/.config.
. "${DOTFILES}/config/env/base.sh"

mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_CONFIG_HOME"
mkdir -p "$XDG_STATE_HOME"
mkdir -p "$XDG_CACHE_HOME"

#: }}}
#: macos {{{

# install Lix package manager if not already present
if ! command -v nix >/dev/null 2>&1; then
  printf "${_cyan}( ◕ ◡ ◕ )${_reset} Installing Lix package manager\n"
  curl -sSf -L https://install.lix.systems/lix | sh -s -- install -v --logger pretty
  if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
fi

# Install Homebrew to bootstrap the stable native mise executable.
if ! command -v brew >/dev/null 2>&1; then
  printf "${_cyan}( ◕ ◡ ◕ )${_reset} Installing Homebrew\n"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install user tools before dropping the old Nix packages. Do not apply services.
if ! command -v mise >/dev/null 2>&1; then
  brew install mise || exit 1
fi
MISE_PROFILE="$NIX_PROFILE"
case "$MISE_PROFILE" in
  work-adamhall-boot) MISE_PROFILE="work-boot" ;;
esac
mise trust "${DOTFILES}/mise.toml" || exit 1
mise -C "${DOTFILES}" -E "$MISE_PROFILE" run packages:apply || exit 1

# run darwin-rebuild
printf "${_cyan}( ◕ ◡ ◕ )${_reset} macOS: running darwin-rebuild (profile: %s)\n" "$NIX_PROFILE"
if command -v darwin-rebuild >/dev/null 2>&1; then
  sudo -H darwin-rebuild switch --flake "path:${DOTFILES}/nix#${NIX_PROFILE}" --show-trace -L -v || exit 1
else
  sudo -H nix run nix-darwin/master#darwin-rebuild -- switch --flake "path:${DOTFILES}/nix#${NIX_PROFILE}" --show-trace -L -v || exit 1
fi

# Mise owns user setup. Generate completions after switching so the cache
# reflects the current system profile.
mise -C "${DOTFILES}" -E "$MISE_PROFILE" run workstation:setup || exit 1

#: }}}
#: boot {{{

printf "${_cyan}( ◕ ◡ ◕ )${_reset} Booting machine\n"
echo "available again with 'boot machine --help'"

if ! command -v nu >/dev/null 2>&1; then
  printf "${_red}( •_• )${_reset} Nushell is not available in PATH; cannot run 'boot machine'\n" >&2
  exit 1
fi

nu \
  --env-config "${DOTFILES}/config/nushell/env.nu" \
  --config "${DOTFILES}/config/nushell/config.nu" \
  --commands "boot machine"

#: }}}
printf "${_cyan}( ◕ ◡ ◕ )${_reset} Complete, open new shell\n"
