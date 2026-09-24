# vim:foldmethod=marker:foldlevel=0

#: env {{{

# zsh remains minimal, but accidental interactive launches get human-facing env.
source "$DOTFILES/config/env/interactive.sh"

#: }}}
#: history {{{

typeset +x HISTFILE
HISTFILE="$HOME/.zsh_history"
HISTSIZE=2000
SAVEHIST=2000
setopt HIST_FCNTL_LOCK HIST_IGNORE_DUPS SHARE_HISTORY
bindkey -e

#: }}}
#: alias {{{

# Pi wrappers for interactive use. Keep these in sync with the Nushell
# equivalents in config/nushell/scripts/ct/interactive/pi.nu.
pi_core_tools=(read bash edit write interactive_shell pi-internals harness_metadata subagent)
pi_goal_tools=(goal_complete goal_blocked goal_wait)

alias pim="pi --provider openai-codex --model gpt-5.6-sol       --thinking medium --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools}"
alias pih="pi --provider openai-codex --model gpt-6-astra       --thinking high   --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools}"
alias pil="pi --provider openai-codex --model gpt-5.6-terra     --thinking high   --tools ${(j:,:)pi_core_tools}"
alias pif="pi --provider deepseek     --model deepseek-v4-flash --thinking max    --tools ${(j:,:)pi_core_tools}"
alias pio="pi --provider anthropic    --model claude-opus-4-6   --thinking high   --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools}"

# Change to the current repository's root.
cdd() {
  local root
  root=$(git rev-parse --show-toplevel) || return
  cd -- "$root"
}

# Change to the primary worktree.
cdm() {
  local listing root
  listing=$(git worktree list --porcelain) || return
  root=${${(f)listing}[1]#worktree }
  cd -- "$root"
}

# Stash uncommitted changes, or discard them with --force.
gnah() {
  if (($# > 1)) || { (($# == 1)) && [[ $1 != '--force' ]]; }; then
    print -u2 'usage: gnah [--force]'
    return 2
  fi

  if [[ $1 == '--force' ]]; then
    git reset --hard || return
    git clean -df
  else
    git stash
  fi
}

unset pi_core_tools pi_subagent pi_goal_tools

alias gst='git status --short'
alias ga='git add'
alias gco='git checkout'

alias l="nu -c 'ls -a'"

alias ai='mill bin run agent --fzf'

alias pp='pnpm'

alias nn='nvim "+Telescope find_files"'
alias nvim-md="nvim - \"+set ft=markdown\""

for n in {0..9}; do
  alias "cd$n=cd \"\$(tmux-session --print $n)\""
done

#: }}}
#: completion {{{

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

#: }}}
#: init {{{

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

#: }}}
#: plugins {{{

antidote load

#: }}}
