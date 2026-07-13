# Minimal zsh compatibility only. Interactive shell is Nushell.
# Keep PATH/XDG/SHELL aligned with terminal and tmux bootstrap.
if [[ -f "$HOME/.config/env/base.sh" ]]; then
  source "$HOME/.config/env/base.sh"
fi
