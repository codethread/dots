# Every zsh sources the shared contract; interactive setup lives in .zshrc.
# Keep PATH/XDG/SHELL aligned with terminal and tmux bootstrap.
NOSYSZSHRC=1

if [[ -f "$HOME/.config/env/base.sh" ]]; then
  source "$HOME/.config/env/base.sh"
fi
