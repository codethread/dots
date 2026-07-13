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
    [
        "acceptEdits"
        "auto"
        "bypassPermissions"
        "default"
        "dontAsk"
        "plan"
    ]
}

def cl-tools-completions [] {
    [
        "Bash"
        "Edit"
        "Read"
        "Write"
        "Glob"
        "Grep"
        "LS"
        "WebFetch"
        "WebSearch"
        "default"
    ]
}

# Build forwarded args list from common cl flags, then invoke cl with a fixed model
def _cl-run [
    model: string
    continue: bool
    safe: bool
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
    # dangerous-skip is the default for tty usage; --safe opts back into permission prompts
    if not $safe { $args ++= [--dangerously-skip-permissions] }
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

# cl with sonnet fable
export def clf [
	--continue(-c)                                           # Continue most recent conversation
	--safe(-s)                                               # Re-enable permission prompts (dangerous-skip is default)
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
    (_cl-run
        "fable"
        $continue
        $safe
        $print
        $verbose
        $resume
        $effort
        $permission_mode
        $output_format
        $allowed_tools
        $disallowed_tools
        $tools
        $agent
        $add_dir
        $append_system_prompt
        $system_prompt
        $name
        $worktree
        $rest
    )
}

# cl with opus model
export def clo [
	--continue(-c)                                           # Continue most recent conversation
	--safe(-s)                                               # Re-enable permission prompts (dangerous-skip is default)
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
    (_cl-run
        "opus"
        $continue
        $safe
        $print
        $verbose
        $resume
        $effort
        $permission_mode
        $output_format
        $allowed_tools
        $disallowed_tools
        $tools
        $agent
        $add_dir
        $append_system_prompt
        $system_prompt
        $name
        $worktree
        $rest
    )
}

# cl with sonnet model
export def cls [
	--continue(-c)                                           # Continue most recent conversation
	--safe(-s)                                               # Re-enable permission prompts (dangerous-skip is default)
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
    (_cl-run
        "sonnet"
        $continue
        $safe
        $print
        $verbose
        $resume
        $effort
        $permission_mode
        $output_format
        $allowed_tools
        $disallowed_tools
        $tools
        $agent
        $add_dir
        $append_system_prompt
        $system_prompt
        $name
        $worktree
        $rest
    )
}

# cl with haiku model
export def clh [
	--continue(-c)                                           # Continue most recent conversation
	--safe(-s)                                               # Re-enable permission prompts (dangerous-skip is default)
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
    (_cl-run
        "haiku"
        $continue
        $safe
        $print
        $verbose
        $resume
        $effort
        $permission_mode
        $output_format
        $allowed_tools
        $disallowed_tools
        $tools
        $agent
        $add_dir
        $append_system_prompt
        $system_prompt
        $name
        $worktree
        $rest
    )
}

export alias _claude-session = jq 'select(.event == "PreToolUse")' .logs/claude-session-*.jsonl
export alias _claude-prompts = jq 'select(.event == "UserPromptSubmit") | {prompt: .raw_data.prompt, transcript: .raw_data.transcript_path, timestamp}' .logs/claude-session-*.jsonl

# Get tool usage statistics
export alias _claude-session-stats = jq -s 'group_by(.tool_name) | map({tool: .[0].tool_name, count: length})' .logs/claude-session-*.jsonl

# Ephemeral claude session with haiku model - deletes session files on exit
export def cll --wrapped [...rest] {
    let session_id = (random uuid)
    let normalized_path = $env.PWD | str replace --all "/" "-"
    let project_dir = $"~/.claude/projects/($normalized_path)" | path expand

    print $"(ansi yellow)Simple details mode(ansi reset)"
    claude --model haiku --dangerously-skip-permissions --session-id $session_id ...$rest

    for name in [$"($session_id).jsonl" $session_id] {
        let p = $project_dir | path join $name
        if ($p | path exists) {
            if ($p | path type) == "dir" {
                rm --recursive $p
            } else {
                rm $p
            }
        }
    }
}

export def cl-doc [doc: path]: nothing -> string {
    pandoc $doc -t markdown --wrap none
    | (claude
		--model haiku
		--no-session-persistence
		--tools ""
		--print (dedent `this document was a docx converted with pandoc to markdown.
		Please reformat it to proper markdown wherever possible.
		Avoid changes if intent is ambiguous, but try to convert to callouts, tables and headings where intent is clear.
		Don't make any other changes or consider any other details.
		Return the reponse as markdown in your final message, say nothing else, the result will be bash piped into a file`)
	)
}
