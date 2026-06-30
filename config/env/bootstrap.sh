# Shared terminal/tmux bootstrap environment.
# Source this before starting Nushell, and from tmux.conf when seeding tmux's
# global environment. Keep this file POSIX-ish: it is sourced by bash/sh.

bootstrap_path="${HOME}/.local/bin:${HOME}/.local/share/cargo/bin:${HOME}/.volta/bin:${HOME}/.bun/bin:/etc/profiles/per-user/${USER}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

PATH="${bootstrap_path}"
export PATH

XDG_CONFIG_HOME="${HOME}/.config"
XDG_DATA_HOME="${HOME}/.local/share"
XDG_STATE_HOME="${HOME}/.local/state"
XDG_CACHE_HOME="${HOME}/.local/cache"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

if command -v nu >/dev/null 2>&1; then
  SHELL="$(command -v nu)"
  export SHELL
else
  echo "nu not found after terminal bootstrap PATH" >&2
  return 1 2>/dev/null || exit 1
fi
