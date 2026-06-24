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
IS_NIXOS=0
IS_MACOS=0

usage() {
  echo "Usage: boot.sh [-p|--profile <name>] [-b|--branch <name>]"
  echo ""
  echo "  -p, --profile  Nix profile to build (default: homelab on NixOS, username-based on macOS)"
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

resolve_nixos_host_dir() {
  case "$1" in
    vm)
      echo "vm-aarch"
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

if [ -f "/etc/NIXOS" ]; then
  IS_NIXOS=1
elif [ "$(uname)" = "Darwin" ]; then
  IS_MACOS=1
else
  printf "${_red}( •_• )${_reset} Unsupported OS. boot.sh supports NixOS and macOS only\n" >&2
  exit 1
fi

if [ -z "$NIX_PROFILE" ]; then
  if [ "$IS_NIXOS" -eq 1 ]; then
    NIX_PROFILE="homelab"
  else
    NIX_PROFILE="$(default_macos_profile)"
  fi
fi

if [ "$IS_MACOS" -eq 1 ]; then
  NIX_PROFILE="$(resolve_profile "$NIX_PROFILE")"
fi

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
#: hardware {{{

if [ "$IS_NIXOS" -eq 1 ]; then
  _hw_src="/etc/nixos/hardware-configuration.nix"
  _nixos_host_dir="$(resolve_nixos_host_dir "$NIX_PROFILE")"
  _hw_dest="${DOTFILES}/nix/hosts/nixos/${_nixos_host_dir}/hardware-configuration.nix"
  if [ -f "${_hw_src}" ] && grep -q '{ \.\.\. }: { }' "${_hw_dest}" 2>/dev/null; then
    printf "${_cyan}( ◕ ◡ ◕ )${_reset} Copying hardware configuration from installer\n"
    cp "${_hw_src}" "${_hw_dest}"
  fi
fi

#: }}}
#: environment {{{

export XDG_CONFIG_HOME="${DOTFILES}/config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_CACHE_HOME="${HOME}/.local/cache"
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:${PATH}"

mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_CONFIG_HOME"
mkdir -p "$XDG_STATE_HOME"
mkdir -p "$XDG_CACHE_HOME"

#: }}}
#: nixos {{{

if [ "$IS_NIXOS" -eq 1 ]; then
  if [ ! -f "/etc/codethread/nm.env" ]; then
    printf "${_red}( •_• )${_reset} Missing /etc/codethread/nm.env for NetworkManager profiles\n"
    echo "      Create with:"
    echo "      sudo mkdir -p /etc/codethread"
    echo "      printf 'PIFI_PSK=your_wifi_password\\n' | sudo tee /etc/codethread/nm.env >/dev/null"
    echo "      sudo chmod 600 /etc/codethread/nm.env"
    echo ""
  fi
  if [ ! -f "${DOTFILES}/nix/flake.lock" ]; then
    printf "${_cyan}( ◕ ◡ ◕ )${_reset} NixOS: generating flake.lock\n"
    nix-shell -p git --run "nix --extra-experimental-features 'nix-command flakes' flake update --flake ${DOTFILES}/nix"
  fi
  printf "${_cyan}( ◕ ◡ ◕ )${_reset} NixOS: running nixos-rebuild (profile: %s)\n" "$NIX_PROFILE"
  sudo nixos-rebuild switch --flake "path:${DOTFILES}/nix#${NIX_PROFILE}" --show-trace -L -v
fi

#: }}}
#: macos {{{

if [ "$IS_MACOS" -eq 1 ]; then
  # install Lix package manager if not already present
  if ! command -v nix >/dev/null 2>&1; then
    printf "${_cyan}( ◕ ◡ ◕ )${_reset} Installing Lix package manager\n"
    curl -sSf -L https://install.lix.systems/lix | sh -s -- install -v --logger pretty
    if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
  fi

  # install Homebrew if not already present (required by nix-darwin homebrew module)
  if ! command -v brew >/dev/null 2>&1; then
    printf "${_cyan}( ◕ ◡ ◕ )${_reset} Installing Homebrew\n"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # run darwin-rebuild
  printf "${_cyan}( ◕ ◡ ◕ )${_reset} macOS: running darwin-rebuild (profile: %s)\n" "$NIX_PROFILE"
  if command -v darwin-rebuild >/dev/null 2>&1; then
    sudo -H darwin-rebuild switch --flake "path:${DOTFILES}/nix#${NIX_PROFILE}" --show-trace -L -v
  else
    sudo -H nix run nix-darwin/master#darwin-rebuild -- switch --flake "path:${DOTFILES}/nix#${NIX_PROFILE}" --show-trace -L -v
  fi
fi

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
#: commit {{{

if [ "$IS_NIXOS" -eq 1 ]; then
  _nixos_host_dir="$(resolve_nixos_host_dir "$NIX_PROFILE")"
  _hw_file="nix/hosts/nixos/${_nixos_host_dir}/hardware-configuration.nix"
  if git -C "${DOTFILES}" status --porcelain -- "${_hw_file}" | grep -q .; then
    if git -C "${DOTFILES}" config user.name >/dev/null 2>&1 \
      && git -C "${DOTFILES}" config user.email >/dev/null 2>&1; then
      echo "( ◕ ◡ ◕ ) Committing hardware configuration"
      git -C "${DOTFILES}" add "${_hw_file}"
      git -C "${DOTFILES}" commit -m "Add hardware-configuration.nix for ${NIX_PROFILE}" -- "${_hw_file}"
    else
      echo "( •_• ) hardware-configuration.nix has uncommitted changes"
      echo "      Run after setting up git identity:"
      echo "      cd ${DOTFILES} && git add ${_hw_file} && git commit -m 'Add hardware-configuration.nix for ${NIX_PROFILE}'"
    fi
  fi
fi

#: }}}

printf "${_cyan}( ◕ ◡ ◕ )${_reset} Complete, open new shell\n"
