# Minimal zsh compatibility only. Interactive shell is Nushell.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.local/cache}"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

mkdir -p "$XDG_STATE_HOME/zsh" 2>/dev/null
export HISTFILE="$XDG_STATE_HOME/zsh/history"
