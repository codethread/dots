# Invoked by mise shell:prepare, using the same Zsh as interactive startup.
# Run as the user, without loading interactive plugins or prompt hooks.
setopt ERR_EXIT PIPE_FAIL
umask 077
source "$DOTFILES/config/zsh/completion-path.zsh"

autoload -Uz compaudit compinit
if ! compaudit; then
  print -u2 'zsh: refusing to cache insecure completions; fix the paths above and run mise run shell:prepare again.'
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

# Keep only the dump for the Zsh selected by this platform.
rm -f -- "$cache/zcompdump" "$cache/zcompdump.zwc"
for stale in "$cache"/zcompdump-*(N); do
  [[ "$stale" == "$cache/$dump" || "$stale" == "$cache/$dump.zwc" ]] || rm -f -- "$stale"
done

print -r -- "zsh $ZSH_VERSION: rebuilt and compiled $cache/$dump (including Homebrew when present)."
