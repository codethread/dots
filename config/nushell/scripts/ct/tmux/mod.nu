# :module: Tmux management module with utility functions for pane interaction and process selection

export use switch.nu
export use open-link.nu
export use notes.nu
use utils.nu

# Find the first pane running an interesting process and call tmux-fingers on
# it
export def finger-other-pane [] {
	# list of 'watch' process, and if these are present, I likely want to grab
	# a url from one of these
	let pss = [
		volta-shim
		cargo-watch
	]

	let panes = utils get-panes

	if ($panes| where zoomed == true | is-not-empty) {
		tmux display-message 'Not available in zoomed pane'
		return
	}

	match ([
		($panes | where cmd in $pss | get -o 0?.index)
		($panes | where lastActive == true | get -o 0?.index)
		($panes | where cmd != nvim | get -o 0?.index)
	] | compact) {
		[] => { tmux display-message "no-match" }
		[$pane, ..] => {
			tmux-fingers start $pane --main-action 'xargs openInVim'
			tmux select-pane -t 1
		}
	}
}
