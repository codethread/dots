# Internal Home Manager activation step, not a user-facing refresh command.
# Run as the user, without loading interactive plugins or prompt hooks.
setopt ERR_EXIT PIPE_FAIL
umask 077
source "$DOTFILES/config/zsh/completion-path.zsh"

# Scan the incoming Darwin system profile before /run/current-system switches.
fpath=("${(@)fpath/#\/run\/current-system\/sw\//$1/}")

autoload -Uz compaudit compinit
if ! compaudit; then
  print -u2 'zsh: refusing to cache insecure completions; fix the paths above and switch again.'
  exit 1
fi

cache="$XDG_CACHE_HOME/zsh"
mkdir -p "$cache"
chmod 700 "$cache"
tmp=$(mktemp -d "$cache/.completions.XXXXXXXX")
trap 'rm -rf -- "$tmp"' EXIT

dump="zcompdump-$ZSH_VERSION"
# The fresh path forces a full rebuild, even when only #compdef names changed.
# -C is safe here because compaudit has just succeeded for this exact fpath.
compinit -C -d "$tmp/$dump"
zcompile -U "$tmp/$dump"

# Each rename is atomic: concurrent shells see a complete old or new file.
# Publish source first; until bytecode arrives Zsh can parse the new source.
mv -f -- "$tmp/$dump" "$cache/$dump"
mv -f -- "$tmp/$dump.zwc" "$cache/$dump.zwc"
print 'zsh: rebuilt and compiled completion cache (including Homebrew when present).'
