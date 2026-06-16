# :module: Tmux popup utility for searching and opening notes in neovim

# Open a fzy find notes file in a popup (no selection starts in notes root file)
export def main [] {
	# Don't know why `cd` doesn't work to avoid replacing path string.
	let f = (rg --files-with-matches . $env.CT_NOTES
		| lines
		| each { |l| $l | path relative-to $env.CT_NOTES }
		| str join "\n"
		| fzf-tmux -p -w 80% -h 70% )

	^tmux display-popup -e $"CT_NOTES=($env.CT_NOTES)" -S 'fg=cyan' -E -w 80% -h 70% -d $env.CT_NOTES $"nvim '($f)'"
}

