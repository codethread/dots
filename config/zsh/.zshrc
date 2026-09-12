# zsh remains minimal, but accidental interactive launches get human-facing env.
source "$DOTFILES/config/env/interactive.sh"

source "/etc/profiles/per-user/$USER/share/antidote/antidote.zsh"
antidote load

autoload -Uz promptinit
promptinit
prompt pure
