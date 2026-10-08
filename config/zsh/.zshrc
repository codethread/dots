# vim:foldmethod=marker:foldlevel=0

#: env {{{

# zsh remains minimal, but accidental interactive launches get human-facing env.
# shuck: source=../env/interactive.sh
source "$DOTFILES/config/env/interactive.sh"
source "$HOME/.privates.sh"

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
mise-dot-diff() (cd -- "$DOTFILES" && mise dot diff "$@")

# Pi wrappers for interactive use. Keep these in sync with the Nushell
# equivalents in config/nushell/scripts/ct/interactive/pi.nu.
pi_core_tools=(read bash edit write interactive_shell pi-internals harness_metadata subagent)
pi_goal_tools=(goal_complete goal_blocked goal_wait)

alias pih="pi --provider openai-codex --model gpt-6-astra       --thinking xhigh  --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools},mcp,codemode"
alias pim="pi --provider openai-codex --model gpt-6-astra       --thinking low    --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools},mcp,codemode"
# pis: work machines (IS_WORK) and checkouts under $HOME/pb use Anthropic
# sonnet; everywhere else keeps sol on codex. Resolved per invocation so the
# choice follows the current directory (pi_core_tools/pi_goal_tools stay set
# for the runtime tool expansion).
pis() {
  if [[ $IS_WORK == true || $PWD == $HOME/pb || $PWD == $HOME/pb/* ]]; then
    pi --provider anthropic    --model claude-sonnet-5-5 --thinking high   --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools} "$@"
  else
    pi --provider openai-codex --model gpt-6.1-sol       --thinking xhigh  --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools} "$@"
  fi
}
alias pil="pi --provider openai-codex --model gpt-6-luna        --thinking xhigh  --tools ${(j:,:)pi_core_tools}"
alias pif="pi --provider deepseek     --model deepseek-flash    --thinking max    --tools ${(j:,:)pi_core_tools}"
alias pio="pi --provider anthropic    --model claude-opus-5-5   --thinking high   --tools ${(j:,:)pi_core_tools},${(j:,:)pi_goal_tools}"

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

alias l="nu -c 'ls -a'"

alias ai='mill bin run agent --fzf'

alias pp='pnpm'

alias nn='nvim "+Telescope find_files"'
alias nvim-md="nvim - \"+set ft=markdown\""

for n in {0..9}; do
  alias "cd$n=cd \"\$(tmux-session --print $n)\""
done

alias hc='honeycomb'

# shuck: source=./helpers.zsh
source "$DOTFILES/config/zsh/helpers.zsh"
# shuck: source=./claude.zsh
source "$DOTFILES/config/zsh/claude.zsh"

#: }}}
#: completion {{{

# shuck: source=./completion-path.zsh
source "$DOTFILES/config/zsh/completion-path.zsh"

# TODO: move to comp
eval "$(honeycomb shell-init zsh)"

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

#: }}}
#: keybindings {{{
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line
#: }}}
#: init {{{

source "$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"

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
# Cobra shim; suggestions are queried from `honeycomb __complete` at tab time.
cache_zsh_init honeycomb completions zsh
unfunction cache_zsh_init

#: }}}
#: plugins {{{

antidote load

#: }}}
