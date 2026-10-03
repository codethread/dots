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
ct_inherited_shell="${SHELL:-}"

ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
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
# Default mise's config environment from identity; preserve explicit overrides.
if [ "$CT_USER" = work ]; then
  if [ "$USER" = adamhall ] && [ -d "$HOME/pb/adam.hall/workfiles" ]; then
    MISE_ENV="${MISE_ENV:-work}"
  else
    MISE_ENV="${MISE_ENV:-work-boot}"
  fi
  KSM_WORK=true
  IS_WORK=true
else
  if [ "$USER" = codethread ]; then
    MISE_ENV="${MISE_ENV:-personal}"
  else
    MISE_ENV="${MISE_ENV:-dev}"
  fi
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

if [ "$ct_os" = Darwin ]; then
  PLAYWRIGHT_MCP_EXECUTABLE_PATH="${PLAYWRIGHT_MCP_EXECUTABLE_PATH:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
else
  PLAYWRIGHT_MCP_EXECUTABLE_PATH="${PLAYWRIGHT_MCP_EXECUTABLE_PATH:-/usr/bin/chromium}"
fi

# Agent and service state ----------------------------------------------------

PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
# TODO: likely want this in the cli wrapper so it's only interactive and on demand
# PI_CACHE_RETENTION="${PI_CACHE_RETENTION:-long}"
PI_SKIP_VERSION_CHECK="${PI_SKIP_VERSION_CHECK:-1}"

PDX_DATA_DIR="${PDX_DATA_DIR:-$HOME/.pdx}"
PITHOS_DB="${PITHOS_DB:-$PDX_DATA_DIR/pithos.sqlite}"
PDX_USER_DATA_DIR="${PDX_USER_DATA_DIR:-$HOME/dev/projects/pdx}"

# Toolchains and CLI defaults ------------------------------------------------

GOBIN="${GOBIN:-$HOME/go/bin}"
GOPATH="${GOPATH:-$HOME/go}"
RUSTUP_HOME="${RUSTUP_HOME:-$XDG_DATA_HOME/rustup}"
PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE:-1}"
PIP_REQUIRE_VIRTUALENV="${PIP_REQUIRE_VIRTUALENV:-false}"
LSP_USE_PLISTS="${LSP_USE_PLISTS:-true}"
# mise maintains this major-version symlink. exec/run override it for projects.
JAVA_HOME="${JAVA_HOME:-${MISE_DATA_DIR:-$XDG_DATA_HOME/mise}/installs/java/temurin-21}"

# Gas City CLI: don't report usage metrics from work machines.
if [ "$CT_USER" = work ]; then
  GC_DISABLE_USAGE_METRICS="${GC_DISABLE_USAGE_METRICS:-1}"
fi

ENABLE_CLAUDEAI_MCP_SERVERS="${ENABLE_CLAUDEAI_MCP_SERVERS:-0}"
CLAUDE_CODE_DISABLE_CRON="${CLAUDE_CODE_DISABLE_CRON:-1}"
CLAUDE_CODE_DISABLE_1M_CONTEXT="${CLAUDE_CODE_DISABLE_1M_CONTEXT:-0}"
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-1}"
CLAUDE_CODE_DISABLE_BUNDLED_SKILLS="${CLAUDE_CODE_DISABLE_BUNDLED_SKILLS:-1}"

# Darwin ---------------------------------------------------------------------

if [ "$ct_os" = Darwin ]; then
  CT_BACKGROUNDS_DIR="${CT_BACKGROUNDS_DIR:-$HOME/sync/images/backgrounds}"
  HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-/opt/homebrew/Cellar}"
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
  HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY:-/opt/homebrew}"
  ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

  if [ -d /Applications/kitty.app/Contents/Resources/man ]; then
    case ":${MANPATH:-}:" in
      *:/Applications/kitty.app/Contents/Resources/man:*) ;;
      ::) MANPATH="/Applications/kitty.app/Contents/Resources/man:" ;;
      *) MANPATH="/Applications/kitty.app/Contents/Resources/man:$MANPATH" ;;
    esac
  fi
fi


# PATH -----------------------------------------------------------------------

# Construct the host baseline at login, before mise activation. Child shells
# inherit their parent's PATH instead of sourcing this file again.
ct_path=""
ct_path_append "$HOME/.local/bin"
# Pi's official managed launcher follows local wrappers.
ct_path_append "$PI_CODING_AGENT_DIR/bin"
# Global defaults without interactive activation; local wrappers stay first.
ct_path_append "${MISE_DATA_DIR:-$XDG_DATA_HOME/mise}/shims"
if [ "$ct_os" = Darwin ]; then
  ct_path_append /opt/homebrew/opt/coreutils/libexec/gnubin
  ct_path_append /opt/homebrew/bin
  ct_path_append /opt/homebrew/sbin
fi
ct_path_append "$CARGO_BIN"
ct_path_append "$HOME/.bun/bin"
ct_path_append "$HOME/.luarocks/bin"
ct_path_append "$GOBIN"
ct_path_append "$HOME/.linkerd2/bin"
ct_path_append "$HOME/.emacs.d/bin"
ct_path_append "$XDG_CONFIG_HOME/skein/bin"
ct_path_append /opt/podman/bin

if [ "$ct_os" = Darwin ]; then
  ct_path_append "$ANDROID_HOME/platform-tools"
  ct_path_append "$ANDROID_HOME/emulator"
  ct_path_append /opt/homebrew/opt/ruby@3.1/bin
  ct_path_append /opt/homebrew/lib/ruby/gems/3.1.0/bin
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
ct_path_append_list "$ct_inherited_path"
PATH=$ct_path
ct_shell_candidate=${ct_inherited_shell:-zsh}
# macOS owns Zsh. Normalize inherited Homebrew or other Zsh paths as well as
# the default so terminals and tmux agree with shell:prepare, regardless of
# PATH order.
if [ "$ct_os" = Darwin ] && [ "${ct_shell_candidate##*/}" = zsh ]; then
  ct_shell_candidate=/bin/zsh
fi
ct_shell_resolution_failed=false
if ct_resolved_shell=$(command -v "$ct_shell_candidate") &&
  [ "${ct_resolved_shell#/}" != "$ct_resolved_shell" ] &&
  [ -x "$ct_resolved_shell" ]; then
  SHELL=$ct_resolved_shell
else
  printf 'could not resolve SHELL to an executable path: %s\n' "$ct_shell_candidate" >&2
  ct_shell_resolution_failed=true
fi

unset ct_dir ct_inherited_path ct_inherited_shell ct_os ct_path ct_remaining
unset ct_resolved_shell ct_shell_candidate

unset -f ct_path_append ct_path_append_list 2>/dev/null || true
if [ "$ct_restore_allexport" = true ]; then
  set +a
fi
unset ct_restore_allexport
if [ "$ct_shell_resolution_failed" = true ]; then
  unset ct_shell_resolution_failed
  return 1
fi
unset ct_shell_resolution_failed
