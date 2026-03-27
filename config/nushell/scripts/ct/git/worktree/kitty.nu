# open a directory in a new kitty tab, or cd into it if not running inside kitty
export def --env wk-open-dir [path: string, title: string] {
	if "KITTY_WINDOW_ID" in $env {
		kitten @ launch --type=tab --cwd $path --tab-title $title
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
