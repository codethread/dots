# :module: claude code wrappers and helpers for tty usage
#
# These are written for nushell https://www.nushell.sh/ using a wrapped
# command: https://www.nushell.sh/book/custom_commands.html#rest-parameters-with-wrapped-external-commands
# but can likely be adapted for other shells like bash or zsh. The main
# function of interest is `cl`

# claude code wrapper with extra args to handle common mcp configs when i want
# them as well as any default claude code args
export def cl --wrapped [
	--dangerously-skip-permissions(-d) # ahhhhh
	...rest
] {
	let custom = if $dangerously_skip_permissions {
		["--dangerously-skip-permissions"]
	} else {
		[]
	}

	let all_args: list<string> = ($custom ++ $rest)
	print $all_args
	claude ...$all_args
}

# cl with opus model
export def clo --wrapped [--dangerously-skip-permissions(-d) ...rest] { cl --dangerously-skip-permissions=$dangerously_skip_permissions --model opus ...$rest }

# cl with sonnet model
export def cls --wrapped [--dangerously-skip-permissions(-d) ...rest] { cl --dangerously-skip-permissions=$dangerously_skip_permissions --model sonnet ...$rest }

# cl with haiku model
export def clh --wrapped [--dangerously-skip-permissions(-d) ...rest] { cl --dangerously-skip-permissions=$dangerously_skip_permissions --model haiku ...$rest }

export alias _claude-session = jq 'select(.event == "PreToolUse")' .logs/claude-session-*.jsonl
export alias _claude-prompts = jq 'select(.event == "UserPromptSubmit") | {prompt: .raw_data.prompt, transcript: .raw_data.transcript_path, timestamp}' .logs/claude-session-*.jsonl


# Get tool usage statistics
export alias _claude-session-stats = jq -s 'group_by(.tool_name) | map({tool: .[0].tool_name, count: length})' .logs/claude-session-*.jsonl

export alias oc = opencode

# Ephemeral claude session with haiku model - deletes session files on exit
export def cll --wrapped [...rest] {
	let session_id = (random uuid)
	let normalized_path = ($env.PWD | str replace --all "/" "-")
	let project_dir = ($"~/.claude/projects/($normalized_path)" | path expand)

	print $"(ansi yellow)Simple details mode(ansi reset)"
	claude --model haiku --session-id $session_id ...$rest

	for name in [$"($session_id).jsonl" $session_id] {
		let p = ($project_dir | path join $name)
		if ($p | path exists) {
			if ($p | path type) == "dir" {
				rm --recursive $p
			} else {
				rm $p
			}
		}
	}
}
