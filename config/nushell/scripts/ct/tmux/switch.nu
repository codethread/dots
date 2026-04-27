# :module: Interactive tmux session switching utility with fzf preview

# Unlike tmux choose-tree, this is session-only and uses fzf-tmux with preview.
export def main [] {
	let current = (tmux display-message -p "#{session_name}" | str trim)

	let sessions = (tmux list-sessions -F "#{session_name}"
		| lines
		| where {|name| $name != $current })

	if ($sessions | is-empty) {
		tmux display-message "No other tmux sessions"
		return
	}

	let preview = ($env.HOME | path join ".config/tmux/plugins/tmux-fzf/scripts/.preview")
	let target = ($sessions
		| str join "\n"
		| fzf-tmux -p -w 80% -h 70% --preview $"($preview) {}" --preview-window "right,70%,follow,border-left"
		| complete)

	# see fzf exit status
	match [$target.exit_code, ($target.stdout | str trim)] {
		[130, _] => {} # C-c / Esc
		[1, _] => {} # no selection
		[0, $chosen] => { tmux switch-client -t $chosen }
		_ => {
			print $"(ansi red)tmux switch failed(ansi reset)"
			$target
		}
	}
}
