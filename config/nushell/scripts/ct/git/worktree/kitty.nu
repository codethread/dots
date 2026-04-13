# open a directory as a kitty session (matching git-session naming), or cd if not in kitty
export def --env wk-open-dir [path: string, title: string] {
	if "KITTY_WINDOW_ID" in $env {
		let session_name = ($path | path basename | str downcase | str replace --all --regex '[^a-z0-9]' '-' | str replace --all --regex '-+' '-' | str replace --all --regex '^-|-$' '')
		let sessions_dir = ($env.HOME | path join ".config" "kitty" "sessions")
		mkdir $sessions_dir
		let session_file = ($sessions_dir | path join $"($session_name).session")
		$"launch --title ($session_name) --cwd \"($path)\"\n" | save -f $session_file
		kitten @ action goto_session $session_file
	} else {
		cd $path
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
