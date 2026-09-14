# Shared by interactive startup and switch-time completion generation.
# Explicit profile paths also work on NixOS without a system-wide zshrc.
typeset -Ua fpath
for ct_zsh_profile in \
  /nix/var/nix/profiles/default \
  /run/current-system/sw \
  "/etc/profiles/per-user/$USER" \
  "$XDG_STATE_HOME/nix/profile" \
  "$HOME/.nix-profile"; do
  fpath=(
    "$ct_zsh_profile/share/zsh/site-functions"
    "$ct_zsh_profile/share/zsh/$ZSH_VERSION/functions"
    "$ct_zsh_profile/share/zsh/vendor-completions"
    $fpath
  )
done
unset ct_zsh_profile

if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
fi
