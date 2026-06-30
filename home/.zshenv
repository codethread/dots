ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
export ZDOTDIR

if [[ -f "$ZDOTDIR/.zshenv" ]]; then
  source "$ZDOTDIR/.zshenv"
fi
