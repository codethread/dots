def wk-session-name [path: string] {
	$path
	| path basename
	| str downcase
	| str replace --all --regex '[^a-z0-9]' '-'
	| str replace --all --regex '-+' '-'
	| str replace --all --regex '^-|-$' ''
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

# open a directory as a kitty session (matching git-session naming), or cd if not in kitty
export def --env wk-open-dir [path: string, title: string, root_dir?: string, hooks?: list<any>] {
	let created_path = ($path | path expand)
	let root_path = if $root_dir == null { $created_path } else { $root_dir | path expand }
	let matched_hooks = ($hooks | default [])

	if "KITTY_WINDOW_ID" in $env {
		let session_name = (wk-session-name $created_path)
		let sessions_dir = ($env.HOME | path join ".config" "kitty" "sessions")
		mkdir $sessions_dir
		let session_file = ($sessions_dir | path join $"($session_name).session")
		let runner_path = (wk-post-create-runner $sessions_dir $session_name $root_path $created_path $matched_hooks)
		let launch_line = if $runner_path == null {
			$"launch --title ($title | to json -r) --cwd ($created_path | to json -r)"
		} else {
			$"launch --title ($title | to json -r) --cwd ($created_path | to json -r) --hold bash ($runner_path | to json -r)"
		}

		[$launch_line ""] | str join "\n" | save -f $session_file
		kitten @ action goto_session $session_file
	} else {
		cd $created_path
		let runner_path = if ($matched_hooks | is-empty) {
			null
		} else {
			let session_name = (wk-session-name $created_path)
			let sessions_dir = ($env.HOME | path join ".config" "kitty" "sessions")
			mkdir $sessions_dir
			wk-post-create-runner $sessions_dir $session_name $root_path $created_path $matched_hooks
		}

		if $runner_path != null {
			wk-run-post-create-runner $runner_path $created_path
		}
	}
}

# close any kitty tabs that have windows rooted inside path
export def wk-close-dir [path: string] {
	if "KITTY_WINDOW_ID" not-in $env { return }
	let listing = (kitten @ ls | complete)
	if $listing.exit_code != 0 { return }
	let tab_ids = ($listing.stdout
		| from json
		| each {|os_win|
			$os_win.tabs | where {|tab|
				$tab.windows | any {|win| $win.cwd == $path or ($win.cwd | str starts-with $"($path)/") }
			} | get id
		}
		| flatten
	)
	for id in $tab_ids {
		kitten @ close-tab --match $"id:($id)"
	}
}
