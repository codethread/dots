# zsh remains minimal, but accidental interactive launches get human-facing env.
source "$DOTFILES/config/env/interactive.sh"

source "$XDG_STATE_HOME/home-manager/gcroots/current-home/home-path/share/antidote/antidote.zsh"
antidote load

autoload -Uz promptinit
promptinit
prompt pure
