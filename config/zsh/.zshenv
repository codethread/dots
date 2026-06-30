# Minimal zsh compatibility only. Interactive shell is Nushell.
# Keep PATH/XDG/SHELL aligned with terminal and tmux bootstrap.
if [[ -f "$HOME/.config/env/bootstrap.sh" ]]; then
  source "$HOME/.config/env/bootstrap.sh"
fi

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.local/cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
export HISTFILE="${HISTFILE:-$XDG_STATE_HOME/bash/history}"

