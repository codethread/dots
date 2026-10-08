# Model shortcuts (cls/clo/clh) wrapping home/.local/bin/cl.
# --settings takes a JSON object in Zsh; all other Claude flags pass through.
# Permissions are skipped unless --safe/-s is supplied.
_dots_cl() (
  local model=$1 effort=$2
  shift 2
  local safe=0 printing=0 mcp_work=0 style='' settings='{}' option value
  local -a args=()
  while (($#)); do
    case $1 in
      --mine|-m) export CLAUDE_CONFIG_DIR="$HOME/.config/claude"; shift ;;
      --mcp-work) mcp_work=1; shift ;;
      --safe|-s) safe=1; shift ;;
      --print|-p) printing=1; args+=(--print); shift ;;
      --continue|-c) args+=(--continue); shift ;;
      --settings|--output-style|--effort|--resume|-r|--name|-n|--worktree|-w|--permission-mode|--output-format|--allowed-tools|--disallowed-tools|--tools|--agent|--add-dir|--append-system-prompt|--system-prompt)
        if (($# < 2)); then
          print -u2 -- "$1 requires a value"
          return 2
        fi
        option=$1 value=$2
        case $option in
          --settings) settings=$value ;;
          --output-style) style=$value ;;
          --effort) effort=$value ;;
          -r) args+=(--resume "$value") ;;
          -n) args+=(--name "$value") ;;
          -w) args+=(--worktree "$value") ;;
          *) args+=("$option" "$value") ;;
        esac
        shift 2 ;;
      --settings=*|--output-style=*|--effort=*)
        option=${1%%=*} value=${1#*=}
        case $option in
          --settings) settings=$value ;;
          --output-style) style=$value ;;
          --effort) effort=$value ;;
        esac
        shift ;;
      --) args+=("$@"); break ;;
      *) args+=("$1"); shift ;;
    esac
  done

  # disableClaudeAiConnectors is any-source-true, so it cannot live in the shared
  # settings.json: --mcp-work works by omitting it from the session settings.
  settings=$(jq -ce --arg style "$style" --argjson printing "$printing" --argjson mcp "$mcp_work" '
    (if type != "object" then error("--settings must be a JSON object") else . end)
    | (if $mcp == 0 then .disableClaudeAiConnectors = true else . end)
    | if $style != "" then .outputStyle = $style
      elif $printing == 0 and (has("outputStyle") | not) then .outputStyle = "pairing"
      else . end
  ' <<< "$settings") || return
  local -a defaults=(--model "$model")
  [[ $settings == '{}' ]] || defaults+=(--settings "$settings")
  ((safe)) || defaults+=(--dangerously-skip-permissions)
  [[ -z $effort ]] || defaults+=(--effort "$effort")
  command cl "${defaults[@]}" "${args[@]}"
)

cls() { _dots_cl sonnet high "$@"; }
clo() { _dots_cl opus high "$@"; }
clh() { _dots_cl haiku '' "$@"; }
