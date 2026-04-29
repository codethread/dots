def wk-session-name [path: string] {
	$path | path basename | str replace --all '.' '_'
}

# open a directory as a tmux session, or cd when outside tmux
export def --env wk-open-dir [
	path: string
	title: string
	--runner-path: string
] {
	let created_path = ($path | path expand)
	let session_name = (wk-session-name $created_path)
	let runner = if ($runner_path | is-empty) { null } else { $runner_path }

	if "TMUX" in $env {
		let has_session = (tmux has-session -t $"=($session_name)" | complete)
		if $has_session.exit_code != 0 {
			tmux new-session -d -s $session_name -n $title -c $created_path
		}
		if $runner != null {
			tmux new-window -d -t $session_name -n post-create -c $created_path bash $runner
		}
		tmux switch-client -t $session_name
	} else {
		cd $created_path
		if $runner != null {
			^bash $runner
		}
	}
}

# close tmux sessions rooted at path
export def wk-close-dir [path: string] {
	if "TMUX" not-in $env { return }
	let target_path = ($path | path expand)
	let sessions = (tmux list-sessions -F "#{session_name}\t#{session_path}" | lines)
	for row in $sessions {
		let parsed = ($row | split row "\t")
		if ($parsed | length) < 2 { continue }
		let name = ($parsed | get 0)
		let session_path = ($parsed | get 1 | path expand)
		if $session_path == $target_path or ($session_path | str starts-with $"($target_path)/") {
			tmux kill-session -t $name
		}
	}
}
