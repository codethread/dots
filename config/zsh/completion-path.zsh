# Shared by interactive startup and boot/shell.sh. Keep this Zsh's native
# function directories; Homebrew contributes its site completions.
typeset -Ua fpath
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
fi
