def wk-session-name [path: string] {
	$path | path basename | str replace --all '.' '_'
}

def wk-post-create-runner [sessions_dir: string, session_name: string, root_dir: string, tree_dir: string, hooks: list<any>] {
	if ($hooks | is-empty) {
		return null
	}

	let base_name = $"($session_name).post-create"
	let root_path = ($root_dir | path expand)
	let created_path = ($tree_dir | path expand)
	let runner_path = ($sessions_dir | path join $"($base_name).runner.sh")
	let hook_defs = ($hooks
		| enumerate
		| each {|entry|
			let hook = $entry.item
			let idx = $entry.index
			let ext = if $hook.shell == "nu" { "nu" } else { "sh" }
			let script_path = ($sessions_dir | path join $"($base_name).($idx).($ext)")
			let script_content = if $hook.shell == "nu" {
				[$hook.command ""] | str join "\n"
			} else {
				["#!/usr/bin/env bash" "set -euo pipefail" "" $hook.command ""] | str join "\n"
			}

			$script_content | save -f $script_path

			{
				label: $hook.name
				shell: $hook.shell
				path: $script_path
			}
		}
	)

	let runner_lines = ([
		"#!/usr/bin/env bash"
		"set -euo pipefail"
		$"export WK_ROOT=($root_path | to json -r)"
		$"export WK_CREATED=($created_path | to json -r)"
		""
	] ++ ($hook_defs
		| each {|hook|
			[
				$"echo ($hook.label | to json -r)"
				(if $hook.shell == "nu" {
					$"nu ($hook.path | to json -r)"
				} else {
					$"bash ($hook.path | to json -r)"
				})
				""
			]
		}
		| flatten
	))

	($runner_lines | str join "\n") | save -f $runner_path
	$runner_path
}

def wk-run-post-create-runner [runner_path: string, tree_dir: string] {
	let created_path = ($tree_dir | path expand)
	let result = (^bash $runner_path | complete)

	if (($result.stdout | default "") != "") {
		print ($result.stdout | str trim --right)
	}

	if (($result.stderr | default "") != "") {
		print ($result.stderr | str trim --right)
	}

	if $result.exit_code != 0 {
		error make {
			msg: $"worktree post-create command failed; worktree remains at ($created_path)"
		}
	}
}

# open a directory as a tmux session, or cd when outside tmux
export def --env wk-open-dir [path: string, title: string, root_dir?: string, hooks?: list<any>] {
	let created_path = ($path | path expand)
	let root_path = if $root_dir == null { $created_path } else { $root_dir | path expand }
	let matched_hooks = ($hooks | default [])
	let session_name = (wk-session-name $created_path)
	let state_dir = ($env.XDG_STATE_HOME? | default ($env.HOME | path join ".local" "state") | path join "tmux-worktree")
	mkdir $state_dir
	let runner_path = if ($matched_hooks | is-empty) {
		null
	} else {
		wk-post-create-runner $state_dir $session_name $root_path $created_path $matched_hooks
	}

	if "TMUX" in $env {
		let has_session = (tmux has-session -t $"=($session_name)" | complete)
		if $has_session.exit_code != 0 {
			tmux new-session -d -s $session_name -n $title -c $created_path
		}
		if $runner_path != null {
			tmux new-window -d -t $session_name -n post-create -c $created_path bash $runner_path
		}
		tmux switch-client -t $session_name
	} else {
		cd $created_path
		if $runner_path != null {
			wk-run-post-create-runner $runner_path $created_path
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
