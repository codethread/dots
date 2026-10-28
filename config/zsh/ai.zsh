# Pi shortcuts over home/.local/bin/piw, which owns shared tool defaults.
alias pih='BL_AUDIENCE=human piw --model openai-codex/gpt-6-astra --thinking xhigh --goals --mcp'
alias pio='BL_AUDIENCE=human piw --model anthropic/claude-opus-5-5 --thinking high --goals --mcp'
alias pim='BL_AUDIENCE=human piw --model openai-codex/gpt-6.1-sol --thinking high --goals --mcp'
alias pif='BL_AUDIENCE=human piw --model deepseek/deepseek-flash --thinking max'
alias pil='BL_AUDIENCE=human piw --model openai-codex/gpt-6-luna --thinking xhigh'
# Resolve per invocation: checkouts under $HOME/pb use Sonnet; elsewhere Sol.
pis() {
  if [[ $PWD == $HOME/pb || $PWD == $HOME/pb/* ]]; then
    BL_AUDIENCE=human piw --model anthropic/claude-sonnet-5-5 --thinking high --goals --mcp "$@"
  else
    BL_AUDIENCE=human piw --model openai-codex/gpt-6.1-sol --thinking xhigh --goals --mcp "$@"
  fi
}

# Interactive conveniences over home/.local/bin/cl, which owns the defaults
# and override flags shared with other tooling.
cls() { BL_AUDIENCE=human cl --model sonnet "$@"; }
clo() { BL_AUDIENCE=human cl --model opus "$@"; }
clh() { BL_AUDIENCE=human cl --model haiku "$@"; }

# Codex defaults use --config so an explicit --model can override them.
coa() { BL_AUDIENCE=human co --config 'model="gpt-6-astra"' --thinking xhigh "$@"; }
cos() { BL_AUDIENCE=human co --config 'model="gpt-6.1-sol"' --thinking high "$@"; }
com() { BL_AUDIENCE=human co --config 'model="gpt-6.1-sol"' --thinking medium --fast "$@"; }
# Shadows /usr/bin/col; use `command col` for the text filter.
col() { BL_AUDIENCE=human co --config 'model="gpt-6-luna"' --thinking high --fast "$@"; }

# Completion helpers and registrations; this file is sourced after compinit.
_dots_pi() {
  local -a models=(
    openai-codex/gpt-6-astra
    openai-codex/gpt-6.1-sol
    openai-codex/gpt-6-luna
    anthropic/claude-sonnet-5-5
    anthropic/claude-opus-5-5
    deepseek/deepseek-flash
  )
  local -a thinking=(off minimal low medium high xhigh max)
  local model_option='*--model=' thinking_option='*--thinking='
  if [[ ${words[1]:t} == pi ]]; then
    model_option='*--model'
    thinking_option='*--thinking'
  fi
  _arguments -s -S \
    "${model_option}[provider/model for the session]:model:(${models[*]})" \
    "${thinking_option}[thinking level]:thinking:(${thinking[*]})" \
    "$@" \
    -- '*:message: '
}

_dots_piw() {
  _dots_pi \
    '--goals[enable goal tools]' \
    '--mcp[enable mcp and codemode]' \
    '--dry-run[print the pi command instead of running it]'
}

# Options come from `cl --help`, which appends claude's; values listed here
# add argument completion on top.
_dots_cl() {
  local -a styles=(default explanatory learning ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/output-styles/*.md(N:t:r))
  local -a models=(sonnet opus haiku fable)
  local -a thinking=(low medium high xhigh max)
  _arguments -s -S \
    "--output-style=[session output style]:style:(${styles[*]})" \
    "--model=[model for the session]:model:(${models[*]})" \
    "*--thinking=[thinking level]:thinking:(${thinking[*]})" \
    '--permission-mode=[permission mode]:mode:(acceptEdits auto bypassPermissions manual dontAsk plan)' \
    '--settings=[session settings]:settings:_files -g "*.json"' \
    '--add-dir=[extra directory]:directory:_directories' \
    -- '*:prompt: '
}

_dots_codex() {
  # Visible models from `codex debug models`, refreshed 2026-10-13.
  local -a models=(gpt-6.1-sol gpt-6-astra gpt-6-sol gpt-6-luna gpt-5.6-sol gpt-5.6-terra gpt-5.6-luna)
  _arguments -s -S \
    "(-m --model)-m+[model for the session]:model:(${models[*]})" \
    "(-m --model)--model=[model for the session]:model:(${models[*]})" \
    "$@" \
    -- '*:prompt: '
}

_dots_co() {
  local -a thinking=(low medium high xhigh max ultra)
  _dots_codex \
    "*--thinking=[thinking level]:thinking:(${thinking[*]})" \
    '--fast[use the fast service tier]' \
    '--dry-run[print the codex command instead of running it]'
}
compdef _dots_pi pi
compdef _dots_piw piw pih pim pis pil pio pif
compdef _dots_cl cl cls clo clh
compdef _dots_codex codex
compdef _dots_co co coa cos com col
