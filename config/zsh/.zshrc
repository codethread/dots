# zsh remains minimal, but accidental interactive launches get human-facing env.
source "$DOTFILES/config/env/interactive.sh"

if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
fi

mkdir -p "$XDG_CACHE_HOME/zsh"
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

source "$XDG_STATE_HOME/home-manager/gcroots/current-home/home-path/share/antidote/antidote.zsh"
antidote load

autoload -Uz promptinit
promptinit
prompt pure
