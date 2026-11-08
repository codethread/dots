# vim:foldmethod=marker:foldlevel=0

#: env {{{

# zsh remains minimal, but accidental interactive launches get human-facing env.
# shuck: source=../env/interactive.sh
source "$DOTFILES/config/env/interactive.sh"

# mise project activation for interactive shells; bash uses the same standard
# hook in config/bash/env. Noninteractive shells use shims or `mise exec`.
eval "$(mise activate zsh)"

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

# Inspect dots' mise resources from any directory, loading its .miserc.toml.
mise-packages() (cd -- "$DOTFILES" && mise bootstrap packages status "$@")
mise-services() (cd -- "$DOTFILES" && mise bootstrap macos launchd-agents status "$@")
mise-dot-diff() { "$DOTFILES/.agents/skills/mise-diff/scripts/mise-dot-diff" "$@"; }

# Copy the current directory to the clipboard.
cdy() {
  print -r -- "$PWD" | pbcopy
}

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

alias gst='git status --short'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'

alias l='ls -la'

alias ai='mill bin run agent --fzf'

alias pp='pnpm'

alias nn='nvim "+Telescope find_files"'
alias nvim-md="nvim - \"+set ft=markdown\""

for n in {0..9}; do
  alias "cd$n=cd \"\$(tmux-session --print $n)\""
done

# shuck: source=./helpers.zsh
source "$DOTFILES/config/zsh/helpers.zsh"

#: }}}
#: completion {{{

# shuck: source=./completion-path.zsh
source "$DOTFILES/config/zsh/completion-path.zsh"

mkdir -p "$XDG_CACHE_HOME/zsh"
autoload -Uz compinit bashcompinit
if [[ -r "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION" ]]; then
  # Audited and compiled by mise; deliberately no per-shell rescan.
  compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
else
  print -u2 'zsh: completion cache missing; run mise bootstrap from dots to generate it.'
  # Safe before the first preparation or after cache deletion: audit, but do not
  # write a replacement cache or skip security checks on an unprepared path.
  compinit -D
fi
bashcompinit

# Highlight the selected completion while Tab or arrow keys cycle matches.
zmodload zsh/complist
zstyle ':completion:*' menu select

# shuck: source=./ai.zsh
source "$DOTFILES/config/zsh/ai.zsh"

# Work-only config, linked from the private workfiles repo when present.
[[ -r ~/.config/zsh/work/work.zsh ]] && source ~/.config/zsh/work/work.zsh

#: }}}
#: keybindings {{{
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line
#: }}}
#: init {{{

# Worktree picker and current-shell directory handoff.
eval "$(wktree shell-init zsh)"

source "$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"

eval "$(starship init zsh)"
eval "$(fzf --zsh)"
# Atuin loads after fzf so its history widget owns Ctrl-R.
eval "$(atuin init zsh)"
# Embedded completion for both CLIs; bl discovers lake commands at Tab time.
eval "$(botlake completions zsh)"
eval "$(wktree completions zsh)"
# The standalone mise install supplies completions through its CLI.
eval "$(mise completion zsh)"

#: }}}
#: plugins {{{

antidote load

#: }}}
