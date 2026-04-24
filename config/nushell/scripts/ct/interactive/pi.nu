# :module: pi wrappers and helpers for tty usage

export def pii --wrapped [...rest] {
	pi --agent main --provider openai-codex --model gpt-5.4-mini:low ...$rest
}

export def pim --wrapped [...rest] {
	pi --agent main --provider openai-codex --model gpt-5.5:low ...$rest
}

export def pih --wrapped [...rest] {
	pi --agent main --provider openai-codex --model gpt-5.5:high ...$rest
}

export def pio --wrapped [...rest] {
	pi --agent main --provider github-copilot --model claude-opus-4.7:high ...$rest
}

# Hardcoded model matrix for `pi-par`. Tweak this list to compare different
# providers/models side-by-side.
const pi_par_models = [
	"openai-codex/gpt-5.4"
	"openai-codex/gpt-5.4-mini"
	"github-copilot/claude-sonnet-4.6"
	"github-copilot/gemini-3.1-pro-preview"
]

const pi_par_opus_model = "github-copilot/claude-opus-4.6"

def shell-quote [value: string] {
	let escaped = (
		$value
		| str replace --all '\\' '\\\\'
		| str replace --all '"' '\\"'
		| str replace --all '$' '\\$'
		| str replace --all '`' '\\`'
	)

	$'"($escaped)"'
}

# Split the current tmux window into panes and run the same prompt through the
# hardcoded pi model matrix in parallel. Pass --opus to include opus too.
export def pi-par [
	--opus(-o)
	...prompt_parts: string
] {
	if ($env.TMUX? | is-empty) {
		error make { msg: "pi-par must be run inside tmux" }
	}

	let prompt = ($prompt_parts | str join " " | str trim)
	if $prompt == "" {
		error make { msg: "usage: pi-par [--opus] <prompt>" }
	}

	let models = if $opus {
		$pi_par_models | append $pi_par_opus_model
	} else {
		$pi_par_models
	}

	let current_pane = (^tmux display-message -p "#{pane_id}" | str trim)
	let current_path = (^tmux display-message -p "#{pane_current_path}" | str trim)

	let extra_panes = (
		$models
		| skip 1
		| each { |_| ^tmux split-window -P -F "#{pane_id}" -c $current_path | str trim }
	)
	let panes = ([$current_pane] | append $extra_panes)
	let quoted_prompt = (shell-quote $prompt)

	for idx in 0..(($models | length) - 1) {
		let pane = ($panes | get $idx)
		let spec = ($models | get $idx)
		let parts = ($spec | split row "/")
		let provider = ($parts | get 0)
		let model = ($parts | get 1)
		let command = $"clear; pi --provider ($provider) --model ($model) ($quoted_prompt)"

		^tmux send-keys -t $pane C-c
		^tmux send-keys -t $pane -l $command
		^tmux send-keys -t $pane Enter
	}

	^tmux select-layout tiled
	^tmux select-pane -t $current_pane
}
