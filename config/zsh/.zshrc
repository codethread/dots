# zsh remains minimal, but accidental interactive launches get human-facing env.
source "$DOTFILES/config/env/interactive.sh"

typeset +x HISTFILE
HISTFILE="$HOME/.zsh_history"
HISTSIZE=2000
SAVEHIST=2000
setopt HIST_FCNTL_LOCK HIST_IGNORE_DUPS SHARE_HISTORY
bindkey -e

source "$DOTFILES/config/zsh/completion-path.zsh"

mkdir -p "$XDG_CACHE_HOME/zsh"
autoload -Uz compinit bashcompinit
if [[ -r "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION" ]]; then
  # Audited and compiled during switch; deliberately no per-shell rescan.
  compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
else
  print -u2 'zsh: completion cache missing; run make system to generate it.'
  # Safe before the first switch or after cache deletion: audit, but do not
  # write a replacement cache or skip security checks on an unprepared path.
  compinit -D
fi
bashcompinit

source "$XDG_STATE_HOME/home-manager/gcroots/current-home/home-path/share/antidote/antidote.zsh"

cache_zsh_init() {
  local name="$1"
  shift

  local bin="${commands[$name]:A}"
  local init="$XDG_CACHE_HOME/zsh/$name-init.zsh"
  local stamp="$XDG_CACHE_HOME/zsh/$name-path"

  if [[ ! -r "$init" || ! -s "$init" || ! -r "$stamp" || "$(< "$stamp")" != "$bin" ]]; then
    local tmp
    tmp=$(mktemp -d "$XDG_CACHE_HOME/zsh/.$name-init.XXXXXXXX") || return
    {
      # Publish only complete, successful output; a failed generator must retry.
      "$bin" "$@" >| "$tmp/init" || return
      print -r -- "$bin" >| "$tmp/stamp" || return
      mv -f -- "$tmp/init" "$init" || return
      mv -f -- "$tmp/stamp" "$stamp" || return
    } always {
      rm -rf -- "$tmp"
    }
  fi
  source "$init"
}

cache_zsh_init starship init zsh
cache_zsh_init fzf --zsh
# Atuin loads after fzf so its history widget owns Ctrl-R.
cache_zsh_init atuin init zsh
unfunction cache_zsh_init

antidote load
