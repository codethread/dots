# open a directory in a new kitty tab, or cd into it if not running inside kitty
export def --env wk-open-dir [path: string, title: string] {
	if "KITTY_WINDOW_ID" in $env {
		kitten @ launch --type=tab --cwd $path --tab-title $title
	} else {
		cd $path
	}
}
