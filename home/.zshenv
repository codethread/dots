# Discovery only: login environment belongs in .zprofile, not every zsh.
ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
export ZDOTDIR
