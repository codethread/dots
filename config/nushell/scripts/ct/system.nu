# macOS system utilities and general OS functions
# Note: mac-dark-toggle, finder, loggy, alert are macOS-only (osascript, open -a, afplay)
# They are safe to import on Linux but will error if invoked

export alias mac-dark-toggle = osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'
export alias l = ls -a
export alias finder = ^open -a 'Finder' .
export alias ports = lsof -i tcp:3000

export def port-kill [...ports: int] {
	$ports | each {|port| lsof -ti $"tcp:($port)" | lines | each {|pid| kill ($pid | into int) } }
}
export alias loggy = cd `~/Library/Mobile Documents/iCloud~com~logseq~logseq/`

export def alert [msg = "Task Finished"] {
	osascript -e $'display notification "($msg)" with title "CMD"'
	afplay /System/Library/Sounds/Glass.aiff
}

# I always forget
export def symlink [original: path, symbolic: path] {
	ln -s $original $symbolic
}

# export most common envs to a zsh file for compatibility
export def dump-env [] {
	hide-all {|| zsh -c 'export' | rg "(.*)" --replace "export $0" | save -f ~/.config/zsh/.envs }
}
