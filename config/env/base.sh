#!/usr/bin/env bash
# Stable environment contract for terminals, shells, agents, and containers.
# Keep syntax compatible with bash, zsh, and POSIX sh when sourced.

case $- in
  *a*) ct_restore_allexport=false ;;
  *) ct_restore_allexport=true; set -a ;;
esac

# Helpers --------------------------------------------------------------------

ct_path_append() {
  [ -n "${1:-}" ] || return 0
  case ":${ct_path}:" in
    *":$1:"*) ;;
    *) ct_path="${ct_path:+${ct_path}:}$1" ;;
  esac
}

ct_path_append_list() {
  ct_remaining=${1:-}
  while [ -n "$ct_remaining" ]; do
    case "$ct_remaining" in
      *:*) ct_dir=${ct_remaining%%:*}; ct_remaining=${ct_remaining#*:} ;;
      *) ct_dir=$ct_remaining; ct_remaining= ;;
    esac
    ct_path_append "$ct_dir"
  done
}

ct_inherited_path=${PATH:-}

# Core / XDG -----------------------------------------------------------------

USER="${USER:-$(id -un)}"
DOTFILES="${DOTFILES:-$HOME/dev/dots}"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.local/cache}"

EDITOR="${EDITOR:-nvim}"
ct_inherited_shell="${SHELL:-/bin/bash}"

ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.local}"
CARGO_HOME="${CARGO_HOME:-$XDG_DATA_HOME/cargo}"
CARGO_BIN="${CARGO_BIN:-$CARGO_HOME/bin}"
CODEX_HOME="${CODEX_HOME:-$HOME/.config/codex}"
RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-$XDG_CONFIG_HOME/ripgrep/config}"
CT_VENDOR_DIR="${CT_VENDOR_DIR:-$HOME/dev/vendor}"
WAKATIME_HOME="${WAKATIME_HOME:-$HOME/.config/wakatime}"

# Machine identity -----------------------------------------------------------

case "$USER" in
  adam.hall|adamhall) CT_USER="${CT_USER:-work}" ;;
  *) CT_USER="${CT_USER:-home}" ;;
esac
if [ "$CT_USER" = work ]; then
  KSM_WORK=true
  IS_WORK=true
else
  KSM_WORK=false
  IS_WORK=false
fi

ct_os="$(uname -s)"
if [ "$CT_USER" = work ]; then
  CT_NOTES="${CT_NOTES:-$HOME/gdrive/perks}"
elif [ "$ct_os" = Darwin ]; then
  CT_NOTES="${CT_NOTES:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Notes}"
else
  CT_NOTES="${CT_NOTES:-$HOME/notes}"
fi

# Platform -------------------------------------------------------------------

if [ -e /etc/NIXOS ]; then
  IS_NIXOS=true
  DOCKER_HOST="${DOCKER_HOST:-unix:///run/user/$(id -u)/podman/podman.sock}"
  PLAYWRIGHT_MCP_EXECUTABLE_PATH="${PLAYWRIGHT_MCP_EXECUTABLE_PATH:-/etc/profiles/per-user/$USER/bin/chromium}"
else
  IS_NIXOS=false
  if [ "$ct_os" = Darwin ]; then
    PLAYWRIGHT_MCP_EXECUTABLE_PATH="${PLAYWRIGHT_MCP_EXECUTABLE_PATH:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
  else
    PLAYWRIGHT_MCP_EXECUTABLE_PATH="${PLAYWRIGHT_MCP_EXECUTABLE_PATH:-/usr/bin/chromium}"
  fi
fi

# Agent and service state ----------------------------------------------------

PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PI_CACHE_RETENTION="${PI_CACHE_RETENTION:-long}"
PI_OFFLINE="${PI_OFFLINE:-1}"
PI_SKIP_VERSION_CHECK="${PI_SKIP_VERSION_CHECK:-1}"

PDX_DATA_DIR="${PDX_DATA_DIR:-$HOME/.pdx}"
PITHOS_DB="${PITHOS_DB:-$PDX_DATA_DIR/pithos.sqlite}"
PDX_USER_DATA_DIR="${PDX_USER_DATA_DIR:-$HOME/dev/projects/pdx}"

BEADS_DIR="${BEADS_DIR:-$HOME/dev/beads-db/.beads}"
BEADS_DOLT_SERVER_MODE="${BEADS_DOLT_SERVER_MODE:-1}"
BEADS_DOLT_SERVER_HOST="${BEADS_DOLT_SERVER_HOST:-127.0.0.1}"
BEADS_DOLT_SERVER_PORT="${BEADS_DOLT_SERVER_PORT:-3307}"
BEADS_DOLT_SERVER_USER="${BEADS_DOLT_SERVER_USER:-root}"

# Toolchains and CLI defaults ------------------------------------------------

GOBIN="${GOBIN:-$HOME/go/bin}"
GOPATH="${GOPATH:-$HOME/go}"
RUSTUP_HOME="${RUSTUP_HOME:-$XDG_DATA_HOME/rustup}"
PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE:-1}"
PIP_REQUIRE_VIRTUALENV="${PIP_REQUIRE_VIRTUALENV:-false}"
VOLTA_FEATURE_PNPM="${VOLTA_FEATURE_PNPM:-1}"
LSP_USE_PLISTS="${LSP_USE_PLISTS:-true}"

ENABLE_CLAUDEAI_MCP_SERVERS="${ENABLE_CLAUDEAI_MCP_SERVERS:-0}"
CLAUDE_CODE_DISABLE_CRON="${CLAUDE_CODE_DISABLE_CRON:-1}"
CLAUDE_CODE_DISABLE_1M_CONTEXT="${CLAUDE_CODE_DISABLE_1M_CONTEXT:-0}"
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-1}"
CLAUDE_CODE_DISABLE_BUNDLED_SKILLS="${CLAUDE_CODE_DISABLE_BUNDLED_SKILLS:-1}"

# Darwin ---------------------------------------------------------------------

if [ "$ct_os" = Darwin ]; then
  CT_BACKGROUNDS_DIR="${CT_BACKGROUNDS_DIR:-$HOME/sync/images/backgrounds}"
  HOMEBREW_BUNDLE_FILE="${HOMEBREW_BUNDLE_FILE:-$HOME/.local/data/Brewfile.conf}"
  HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-/opt/homebrew/Cellar}"
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
  HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY:-/opt/homebrew}"
  ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [ -d /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home ]; then
    JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home}"
  else
    JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home}"
  fi
fi

# PATH -----------------------------------------------------------------------

ct_path=""
ct_project_path_first=false
if [ -n "${IN_NIX_SHELL:-}${DIRENV_DIR:-}" ]; then
  ct_project_path_first=true
  ct_path_append_list "$ct_inherited_path"
fi
# Volta launches tools with a selected image directory first in PATH and sets
# _VOLTA_TOOL_RECURSION. Preserve (or recover) those directories before adding
# Volta's shim: rebuilding PATH with only the shim makes it fall back to the
# system Node instead of the project-pinned toolchain.
ct_volta_image_prefix=false
if [ -n "${_VOLTA_TOOL_RECURSION+x}" ]; then
  ct_remaining=$ct_inherited_path
  while [ -n "$ct_remaining" ]; do
    case "$ct_remaining" in
      *:*) ct_dir=${ct_remaining%%:*}; ct_remaining=${ct_remaining#*:} ;;
      *) ct_dir=$ct_remaining; ct_remaining= ;;
    esac
    case "$ct_dir" in
      "$VOLTA_HOME"/tools/image/*/*/bin)
        ct_path_append "$ct_dir"
        ct_volta_image_prefix=true
        ;;
      *) break ;;
    esac
  done
  if [ "$ct_volta_image_prefix" = false ]; then
    ct_volta_cli=$(command -v volta 2>/dev/null || true)
    if [ -n "$ct_volta_cli" ]; then
      for ct_volta_tool in pnpm yarn npm node; do
        ct_volta_executable=$($ct_volta_cli which "$ct_volta_tool" 2>/dev/null || true)
        case "$ct_volta_executable" in
          "$VOLTA_HOME"/tools/image/*/*/bin/*)
            ct_path_append "${ct_volta_executable%/*}"
            ;;
        esac
      done
    fi
  fi
fi
ct_path_append "$HOME/.local/bin"
ct_path_append "$CARGO_BIN"
ct_path_append "$VOLTA_HOME/bin"
ct_path_append "$HOME/.bun/bin"
ct_path_append "$HOME/.luarocks/bin"
ct_path_append "$GOBIN"
ct_path_append "$HOME/.linkerd2/bin"
ct_path_append "$HOME/.emacs.d/bin"
ct_path_append "$XDG_CONFIG_HOME/skein/bin"
ct_path_append "$HOME/.nix-profile/bin"
ct_path_append "$XDG_STATE_HOME/nix/profile/bin"
ct_path_append "/etc/profiles/per-user/$USER/bin"
ct_path_append /run/current-system/sw/bin
ct_path_append /nix/var/nix/profiles/default/bin
if [ "$IS_NIXOS" = true ]; then
  ct_path_append /run/wrappers/bin
fi
ct_path_append /opt/podman/bin

if [ "$ct_os" = Darwin ]; then
  ct_path_append "$JAVA_HOME/bin"
  ct_path_append "$ANDROID_HOME/platform-tools"
  ct_path_append "$ANDROID_HOME/emulator"
  ct_path_append /opt/homebrew/opt/ruby@3.1/bin
  ct_path_append /opt/homebrew/lib/ruby/gems/3.1.0/bin
  ct_path_append /opt/homebrew/bin
  ct_path_append /opt/homebrew/sbin
  ct_path_append "/Applications/kitty.app/Contents/MacOS"
  ct_path_append "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  ct_path_append "/Applications/Cursor.app/Contents/Resources/app/bin"
fi

ct_path_append "$HOME/.local/share/nvim/mason/bin"
ct_path_append /usr/local/bin
ct_path_append /usr/local/sbin
ct_path_append /usr/bin
ct_path_append /bin
ct_path_append /usr/sbin
ct_path_append /sbin
if [ -n "${CT_PATH_EXTRA:-}" ]; then
  ct_path_append_list "$CT_PATH_EXTRA"
fi
if [ "$ct_project_path_first" = false ]; then
  ct_path_append_list "$ct_inherited_path"
fi
PATH=$ct_path
if command -v nu >/dev/null 2>&1; then
  SHELL="$(command -v nu)"
else
  SHELL=$ct_inherited_shell
fi

unset ct_dir ct_inherited_path ct_inherited_shell ct_os ct_path ct_project_path_first ct_remaining
unset ct_volta_cli ct_volta_executable ct_volta_image_prefix ct_volta_tool
unset -f ct_path_append ct_path_append_list 2>/dev/null || true
if [ "$ct_restore_allexport" = true ]; then
  set +a
fi
unset ct_restore_allexport
