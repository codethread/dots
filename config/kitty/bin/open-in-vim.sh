#!/usr/bin/env bash
set -euo pipefail

# Configuration
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
LOG_FILE="$XDG_CACHE_HOME/open-in-vim.log"
SCRIPT_NAME="$(basename "$0")"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" || {
  echo "ERROR: Cannot create log directory" >&2
  exit 1
}

# Enhanced logging function
log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $SCRIPT_NAME: $*" >>"$LOG_FILE"

  case "$level" in
  ERROR) echo "ERROR: $*" >&2 ;;
  WARN) echo "WARNING: $*" >&2 ;;
  esac
}

# Cleanup function for signals
cleanup() {
  local exit_code=$?
  log "INFO" "Script exiting with code $exit_code"
  exit $exit_code
}
trap cleanup EXIT

# Error handler for debugging
error_handler() {
  local line_no=$1
  log "ERROR" "Script failed at line $line_no"
}
trap 'error_handler ${LINENO}' ERR

# Validate inputs
validate_inputs() {
  if [[ -z "${1:-}" ]]; then
    log "ERROR" "No filename provided"
    echo "Usage: $0 <filename[:line[:column]]>" >&2
    exit 2
  fi
}

# Check kitty connection
check_kitty_connection() {
  if ! kitty @ ls >/dev/null 2>&1; then
    log "ERROR" "Cannot connect to kitty remote control"
    echo "Error: Cannot connect to kitty remote control. Ensure 'allow_remote_control yes' is set in kitty.conf" >&2
    exit 3
  fi
  log "INFO" "Kitty remote control connection verified"
}

# Send command to nvim window
send_command_to_nvim() {
  local window_id="$1"
  local command="$2"

  if ! kitty @ send-text --match "id:$window_id" "$command" 2>&1; then
    log "ERROR" "Failed to send command '$command' to window $window_id"
    return 4
  fi

  log "INFO" "Successfully sent command '$command' to window $window_id"
  return 0
}

# Main function
main() {
  validate_inputs "$@"
  check_kitty_connection

  local input="$1"
  log "INFO" "Script called with argument: $input"

  # Parse vimgrep format: filename:line:column:text or filename:line:text
  local filename line column
  if [[ "$input" =~ ^([^:]+):([0-9]+)(:([0-9]+))?(:.*)?$ ]]; then
    filename="${BASH_REMATCH[1]}"
    line="${BASH_REMATCH[2]}"
    column="${BASH_REMATCH[4]}"
    log "INFO" "Parsed vimgrep format - File: $filename, Line: $line, Column: $column"
  else
    # If not in vimgrep format, treat as regular filename
    filename="$input"
    line=""
    column=""
    log "INFO" "Parsed as regular filename: $filename"
  fi

  # Find window ID running nvim
  log "INFO" "Looking for nvim window..."
  local kitty_output nvim_window_id

  if ! kitty_output=$(kitten @ ls --match 'var:IS_NVIM and state:parent_active' 2>&1); then
    log "ERROR" "Failed to list kitty windows: $kitty_output"
    exit 5
  fi

  if ! nvim_window_id=$(echo "$kitty_output" | jq -r '.[] | select(.tabs[].windows[].foreground_processes[].cmdline[]? | contains("nvim")) | .tabs[].windows[].id' 2>/dev/null | head -1); then
    log "ERROR" "Failed to parse kitty window list"
    exit 2
  fi

  if [[ -z "$nvim_window_id" ]]; then
    log "ERROR" "No nvim window found"
    echo "Error: No nvim window found" >&2
    exit 4
  fi

  log "INFO" "Found nvim window ID: $nvim_window_id"

  # Build and send the appropriate command
  local vim_command
  if [[ -n "$line" ]] && [[ -n "$column" ]]; then
    vim_command=":e +call\ cursor($line,$column) $filename\r"
    log "INFO" "Sending command: :e +$line $filename with column $column"
  elif [[ -n "$line" ]]; then
    vim_command=":e +$line $filename\r"
    log "INFO" "Sending command: :e +$line $filename"
  else
    vim_command=":e $filename\r"
    log "INFO" "Sending command: :e $filename"
  fi

  if ! send_command_to_nvim "$nvim_window_id" "$vim_command"; then
    exit 4
  fi

  if ! kitten @ focus-window --match "id:$nvim_window_id" 2>&1; then
    log "ERROR" "Failed to focus-window to window $nvim_window_id"
    exit 4
  fi

  log "INFO" "Operation completed successfully"
}

main "$@"
