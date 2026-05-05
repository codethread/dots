# :module: claude code wrappers and helpers for tty usage
#
# The main `cl` wrapper is a bash script at home/.local/bin/cl which handles
# conditional system prompt injection. These nushell wrappers provide model
# shortcuts.

def cl-effort-completions [] {
	["low" "medium" "high" "xhigh" "max"]
}

def cl-output-format-completions [] {
	["text" "json" "stream-json"]
}

def cl-permission-mode-completions [] {
	["acceptEdits" "auto" "bypassPermissions" "default" "dontAsk" "plan"]
}

def cl-tools-completions [] {
	["Bash" "Edit" "Read" "Write" "Glob" "Grep" "LS" "WebFetch" "WebSearch" "default"]
}

# Build forwarded args list from common cl flags, then invoke cl with a fixed model
def _cl-run [
	model: string
	continue: bool
	dangerously_skip_permissions: bool
	print: bool
	verbose: bool
	resume: string
	effort: string
	permission_mode: string
	output_format: string
	allowed_tools: string
	disallowed_tools: string
	tools: string
	agent: string
	add_dir: string
	append_system_prompt: string
	system_prompt: string
	name: string
	worktree: string
	rest: list<string>
] {
	mut args = [--model $model]
	if $continue { $args ++= [--continue] }
	if $dangerously_skip_permissions { $args ++= [--dangerously-skip-permissions] }
	if $print { $args ++= [--print] }
	if $verbose { $args ++= [--verbose] }
	if ($resume | is-not-empty) { $args ++= [--resume $resume] }
	if ($effort | is-not-empty) { $args ++= [--effort $effort] }
	if ($permission_mode | is-not-empty) { $args ++= [--permission-mode $permission_mode] }
	if ($output_format | is-not-empty) { $args ++= [--output-format $output_format] }
	if ($allowed_tools | is-not-empty) { $args ++= [--allowed-tools $allowed_tools] }
	if ($disallowed_tools | is-not-empty) { $args ++= [--disallowed-tools $disallowed_tools] }
	if ($tools | is-not-empty) { $args ++= [--tools $tools] }
	if ($agent | is-not-empty) { $args ++= [--agent $agent] }
	if ($add_dir | is-not-empty) { $args ++= [--add-dir $add_dir] }
	if ($append_system_prompt | is-not-empty) { $args ++= [--append-system-prompt $append_system_prompt] }
	if ($system_prompt | is-not-empty) { $args ++= [--system-prompt $system_prompt] }
	if ($name | is-not-empty) { $args ++= [--name $name] }
	if ($worktree | is-not-empty) { $args ++= [--worktree $worktree] }
	^cl ...$args ...$rest
}

# cl with opus model
export def clo [
	--continue(-c)                                           # Continue most recent conversation
	--dangerously-skip-permissions(-d)                       # Bypass all permission checks
	--print(-p)                                              # Print response and exit (non-interactive)
	--verbose                                                # Override verbose mode
	--resume(-r): string = ""                                # Resume a conversation by session ID
	--effort: string@cl-effort-completions = "high"          # Effort level
	--permission-mode: string@cl-permission-mode-completions = ""  # Permission mode
	--output-format: string@cl-output-format-completions = ""      # Output format (--print only)
	--allowed-tools: string@cl-tools-completions = ""        # Tools to allow
	--disallowed-tools: string@cl-tools-completions = ""     # Tools to deny
	--tools: string@cl-tools-completions = ""                # Available tools from built-in set
	--agent: string = ""                                     # Agent for the session
	--add-dir: string = ""                                   # Additional directory to allow tool access to
	--append-system-prompt: string = ""                      # Append to default system prompt
	--system-prompt: string = ""                             # System prompt for the session
	--name(-n): string = ""                                  # Display name for this session
	--worktree(-w): string = ""                              # Create a new git worktree for this session
	...rest: string
] {
	_cl-run "opus" $continue $dangerously_skip_permissions $print $verbose $resume $effort $permission_mode $output_format $allowed_tools $disallowed_tools $tools $agent $add_dir $append_system_prompt $system_prompt $name $worktree $rest
}

# cl with sonnet model
export def cls [
	--continue(-c)                                           # Continue most recent conversation
	--dangerously-skip-permissions(-d)                       # Bypass all permission checks
	--print(-p)                                              # Print response and exit (non-interactive)
	--verbose                                                # Override verbose mode
	--resume(-r): string = ""                                # Resume a conversation by session ID
	--effort: string@cl-effort-completions = "high"          # Effort level
	--permission-mode: string@cl-permission-mode-completions = ""  # Permission mode
	--output-format: string@cl-output-format-completions = ""      # Output format (--print only)
	--allowed-tools: string@cl-tools-completions = ""        # Tools to allow
	--disallowed-tools: string@cl-tools-completions = ""     # Tools to deny
	--tools: string@cl-tools-completions = ""                # Available tools from built-in set
	--agent: string = ""                                     # Agent for the session
	--add-dir: string = ""                                   # Additional directory to allow tool access to
	--append-system-prompt: string = ""                      # Append to default system prompt
	--system-prompt: string = ""                             # System prompt for the session
	--name(-n): string = ""                                  # Display name for this session
	--worktree(-w): string = ""                              # Create a new git worktree for this session
	...rest: string
] {
	_cl-run "sonnet" $continue $dangerously_skip_permissions $print $verbose $resume $effort $permission_mode $output_format $allowed_tools $disallowed_tools $tools $agent $add_dir $append_system_prompt $system_prompt $name $worktree $rest
}

# cl with haiku model
export def clh [
	--continue(-c)                                           # Continue most recent conversation
	--dangerously-skip-permissions(-d)                       # Bypass all permission checks
	--print(-p)                                              # Print response and exit (non-interactive)
	--verbose                                                # Override verbose mode
	--resume(-r): string = ""                                # Resume a conversation by session ID
	--effort: string@cl-effort-completions = ""              # Effort level
	--permission-mode: string@cl-permission-mode-completions = ""  # Permission mode
	--output-format: string@cl-output-format-completions = ""      # Output format (--print only)
	--allowed-tools: string@cl-tools-completions = ""        # Tools to allow
	--disallowed-tools: string@cl-tools-completions = ""     # Tools to deny
	--tools: string@cl-tools-completions = ""                # Available tools from built-in set
	--agent: string = ""                                     # Agent for the session
	--add-dir: string = ""                                   # Additional directory to allow tool access to
	--append-system-prompt: string = ""                      # Append to default system prompt
	--system-prompt: string = ""                             # System prompt for the session
	--name(-n): string = ""                                  # Display name for this session
	--worktree(-w): string = ""                              # Create a new git worktree for this session
	...rest: string
] {
	_cl-run "haiku" $continue $dangerously_skip_permissions $print $verbose $resume $effort $permission_mode $output_format $allowed_tools $disallowed_tools $tools $agent $add_dir $append_system_prompt $system_prompt $name $worktree $rest
}

export alias _claude-session = jq 'select(.event == "PreToolUse")' .logs/claude-session-*.jsonl
export alias _claude-prompts = jq 'select(.event == "UserPromptSubmit") | {prompt: .raw_data.prompt, transcript: .raw_data.transcript_path, timestamp}' .logs/claude-session-*.jsonl


# Get tool usage statistics
export alias _claude-session-stats = jq -s 'group_by(.tool_name) | map({tool: .[0].tool_name, count: length})' .logs/claude-session-*.jsonl


def _smoke-check [check: string, ok: bool, detail: string] {
	{
		check: $check
		ok: $ok
		detail: ($detail | str trim)
	}
}

def _summarize-complete [result: record] {
	let text = (
		[$result.stdout $result.stderr]
		| each {|s| ($s | default "" | str trim) }
		| where {|s| $s != "" }
		| str join "\n"
		| str replace --all "\t" " "
		| str replace --regex '\s*\n\s*' " / "
		| str replace --regex ' {2,}' " "
		| str trim
	)

	if ($text | is-empty) {
		""
	} else if ($text | str length) > 240 {
		$"($text | str substring 0..239)..."
	} else {
		$text
	}
}

# Smoke-test the cc-sandbox container. Fast local checks run by default;
# headless Claude/Codex pings are opt-in because they depend on API/network/auth.
export def cc-sandbox-smoke [
	--no-cache # rebuild the sandbox image without cache
	--skip-models # compatibility flag; local checks already skip model pings by default
	--with-models # include headless Claude/Codex requests
	--stream # stream sandbox output live instead of only showing the final table
] {
	let script = [
		"set +e"
		"trim() { tr '\\n' ' ' | tr '\\t' ' ' | sed 's/  */ /g' | cut -c1-240; }"
		"emit() { jq -nc --arg check \"$1\" --argjson ok \"$2\" --arg detail \"$3\" '{check:$check, ok:$ok, detail:$detail}'; }"
		"progress() { printf '==> %s\n' \"$1\"; }"
		"check_shell() {"
		"  local name=\"$1\""
		"  local cmd=\"$2\""
		"  local out"
		"  progress \"$name\""
		"  if out=$(eval \"$cmd\" 2>&1); then"
		"    emit \"$name\" true \"$(printf '%s' \"$out\" | trim)\""
		"  else"
		"    emit \"$name\" false \"$(printf '%s' \"$out\" | trim)\""
		"  fi"
		"}"
		"check_shell 'claude binary' 'command -v claude'"
		"check_shell 'codex binary' 'command -v codex'"
		"check_shell 'pi binary' 'command -v pi'"
		"check_shell 'playwright-cli binary' 'command -v playwright-cli'"
		"check_shell 'bun binary' 'command -v bun'"
		"check_shell 'nu binary' 'command -v nu'"
		"check_shell 'claude version' 'claude --version'"
		"check_shell 'codex version' 'codex --version'"
		"check_shell 'pi version' 'pi --version'"
		"check_shell 'PATH has ~/.local/bin' 'printf \"%s\\n\" \"$PATH\" | grep -F \"/home/user/.local/bin\"'"
		"check_shell 'PATH has ~/.bun/bin' 'printf \"%s\\n\" \"$PATH\" | grep -F \"/home/user/.bun/bin\"'"
		"check_shell 'CODEX_HOME set' '[ \"$CODEX_HOME\" = \"/home/user/.config/codex\" ] && printf \"%s\" \"$CODEX_HOME\"'"
		"check_shell 'PI_CODING_AGENT_DIR set' '[ \"$PI_CODING_AGENT_DIR\" = \"/home/user/.pi/agent\" ] && printf \"%s\" \"$PI_CODING_AGENT_DIR\"'"
		"check_shell 'claude settings mounted' '[ -f /home/user/.claude/settings.json ] && printf \"%s\" /home/user/.claude/settings.json'"
		"check_shell 'codex config linked' '[ -f /home/user/.config/codex/config.toml ] && printf \"%s\" /home/user/.config/codex/config.toml'"
		"check_shell 'pi config linked' '[ -f /home/user/.pi/agent/settings.json ] && printf \"%s\" /home/user/.pi/agent/settings.json'"
		"check_shell 'project mounted under /vm' 'pwd | grep \"^/vm/\"'"
		"check_shell 'nvim config' 'nvim --headless -c \"lua print((vim.g.colors_name or \\\"none\\\") .. \\\",oil:\\\" .. tostring(require(\\\"oil\\\") ~= nil) .. \\\",ts:\\\" .. tostring(require(\\\"nvim-treesitter\\\") ~= nil))\" +qa 2>&1'"
	]

	let run_model_checks = ($with_models and (not $skip_models))

	let model_checks = if $run_model_checks {
		[
			"check_shell 'claude ping' 'out=$(timeout 30s claude -p --output-format text --model haiku --dangerously-skip-permissions \"ping\"); [ -n \"$out\" ] && printf \"%s\" \"$out\"'"
			"check_shell 'codex ping' 'tmp=$(mktemp); timeout 30s codex exec --sandbox read-only --skip-git-repo-check --ephemeral -o \"$tmp\" \"ping\" >/dev/null && [ -s \"$tmp\" ] && cat \"$tmp\"; status=$?; rm -f \"$tmp\"; exit $status'"
		]
	} else {
		[
			"emit 'model checks' true 'skipped (pass --with-models to enable headless Claude/Codex pings)'"
		]
	}

	let command = (($script ++ $model_checks ++ ["exit 0"]) | str join "\n")

	if $stream {
		if $no_cache {
			^cc-sandbox --no-cache --run $command
		} else {
			^cc-sandbox --run $command
		}
		return
	}

	let result = (
		do {
			if $no_cache {
				^cc-sandbox --no-cache --run $command
			} else {
				^cc-sandbox --run $command
			}
		} | complete
	)

	if $result.exit_code != 0 {
		let detail = (_summarize-complete $result)
		error make { msg: $"cc-sandbox failed before smoke checks completed: ($detail)" }
	}

	let checks = (
		$result.stdout
		| lines
		| where {|line| ($line | str trim | str starts-with "{") }
		| each {|line| $line | from json }
	)

	if ($checks | is-empty) {
		error make { msg: "cc-sandbox smoke produced no check output" }
	}

	let report = (
		$checks
		| each {|check|
			$check | upsert status (if $check.ok { "ok" } else { "fail" })
		}
		| select check status detail
	)

	$report | table -e

	if ($checks | where ok == false | is-not-empty) {
		error make { msg: "cc-sandbox smoke failed" }
	}

	$report
}

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
