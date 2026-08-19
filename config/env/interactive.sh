#!/usr/bin/env bash
# Environment for human-facing interactive shells only.
# Keep syntax compatible with bash, zsh, and POSIX sh when sourced.

case $- in
  *a*) ct_interactive_restore_allexport=false ;;
  *) ct_interactive_restore_allexport=true; set -a ;;
esac

if [ -n "${VSCODE_IPC_HOOK_CLI:-}" ]; then
  VISUAL="code --wait"
elif [ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}" ]; then
  VISUAL="nvim"
else
  VISUAL="nvim"
  # VISUAL="${VISUAL:-zed --wait}"
fi

HISTFILE="${HISTFILE:-$XDG_STATE_HOME/bash/history}"
STARSHIP_CACHE="${STARSHIP_CACHE:-$XDG_CACHE_HOME/starship}"
LESSHISTFILE="${LESSHISTFILE:--}"
MANPAGER="${MANPAGER:-nvim +Man! -c 'lua require(\"codethread.manpager\")'}"
MANWIDTH="${MANWIDTH:-80}"
CARAPACE_BRIDGES="${CARAPACE_BRIDGES:-fish,bash,inshellisense}"

FZF_ALT_C_COMMAND="${FZF_ALT_C_COMMAND:-fd --hidden --type d --exclude '{Library,Movies,Music,Applications,Pictures,Unity,VirtualBox VMs,WebstormProjects,Tools,node_modules,.git}' . ~}"
FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-fd --type f --hidden --exclude '{.git}'}"
FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --exclude '{.git}'}"
FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97,border:#44415a,header:#3e8fb0,gutter:#232136,spinner:#f6c177,info:#9ccfd8,pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa}"

if [ "$(uname -s)" = Darwin ] && [ -d /Applications/kitty.app/Contents/Resources/man ]; then
  case ":${MANPATH:-}:" in
    *:/Applications/kitty.app/Contents/Resources/man:*) ;;
    ::) MANPATH="/Applications/kitty.app/Contents/Resources/man:" ;;
    *) MANPATH="/Applications/kitty.app/Contents/Resources/man:$MANPATH" ;;
  esac
fi

if [ "$ct_interactive_restore_allexport" = true ]; then
  set +a
fi
unset ct_interactive_restore_allexport
