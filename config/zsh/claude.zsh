# Interactive conveniences over home/.local/bin/cl, which owns the defaults
# and override flags shared with other tooling. Sourced after compinit.
cls() { cl --model sonnet "$@"; }
clo() { cl --model opus "$@"; }
clh() { cl --model haiku "$@"; }

# Options come from `cl --help`, which appends claude's; values listed here
# add argument completion on top.
_dots_cl() {
  local -a styles=(default explanatory learning ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/output-styles/*.md(N:t:r))
  _arguments -s -S \
    "--output-style=[session output style]:style:(${styles[*]})" \
    '--model=[model for the session]:model:(sonnet opus haiku fable)' \
    '--effort=[effort level]:effort:(low medium high xhigh max)' \
    '--permission-mode=[permission mode]:mode:(acceptEdits auto bypassPermissions manual dontAsk plan)' \
    '--settings=[session settings]:settings:_files -g "*.json"' \
    '--add-dir=[extra directory]:directory:_directories' \
    -- '*:prompt: '
}
compdef _dots_cl cl cls clo clh
