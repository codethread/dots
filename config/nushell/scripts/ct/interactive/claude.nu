# :module: claude code wrappers and helpers for tty usage
#
# The main `cl` wrapper is a bash script at home/.local/bin/cl which handles
# conditional system prompt injection. These nushell wrappers provide model
# shortcuts.

# cl with opus model
export def clo --wrapped [--dangerously-skip-permissions(-d) ...rest] {
	if $dangerously_skip_permissions { ^cl -d --model opus ...$rest } else { ^cl --model opus ...$rest }
}

# cl with sonnet model
export def cls --wrapped [--dangerously-skip-permissions(-d) ...rest] {
	if $dangerously_skip_permissions { ^cl -d --model sonnet ...$rest } else { ^cl --model sonnet ...$rest }
}

# cl with haiku model
export def clh --wrapped [--dangerously-skip-permissions(-d) ...rest] {
	if $dangerously_skip_permissions { ^cl -d --model haiku ...$rest } else { ^cl --model haiku ...$rest }
}

export alias _claude-session = jq 'select(.event == "PreToolUse")' .logs/claude-session-*.jsonl
export alias _claude-prompts = jq 'select(.event == "UserPromptSubmit") | {prompt: .raw_data.prompt, transcript: .raw_data.transcript_path, timestamp}' .logs/claude-session-*.jsonl


# Get tool usage statistics
export alias _claude-session-stats = jq -s 'group_by(.tool_name) | map({tool: .[0].tool_name, count: length})' .logs/claude-session-*.jsonl

export alias oc = opencode

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
		"check_shell 'playwright-cli binary' 'command -v playwright-cli'"
		"check_shell 'bun binary' 'command -v bun'"
		"check_shell 'nu binary' 'command -v nu'"
		"check_shell 'claude version' 'claude --version'"
		"check_shell 'codex version' 'codex --version'"
		"check_shell 'PATH has ~/.local/bin' 'printf \"%s\\n\" \"$PATH\" | grep -F \"/home/user/.local/bin\"'"
		"check_shell 'PATH has ~/.bun/bin' 'printf \"%s\\n\" \"$PATH\" | grep -F \"/home/user/.bun/bin\"'"
		"check_shell 'CODEX_HOME set' '[ \"$CODEX_HOME\" = \"/home/user/.config/codex\" ] && printf \"%s\" \"$CODEX_HOME\"'"
		"check_shell 'claude settings mounted' '[ -f /home/user/.claude/settings.json ] && printf \"%s\" /home/user/.claude/settings.json'"
		"check_shell 'codex config linked' '[ -f /home/user/.config/codex/config.toml ] && printf \"%s\" /home/user/.config/codex/config.toml'"
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
