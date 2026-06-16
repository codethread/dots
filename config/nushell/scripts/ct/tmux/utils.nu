# :module: Tmux utility functions for session and pane management

export def to-session [] {
    str replace '.' '_'
}

export def get-panes [] {
    tmux list-panes -F "#{pane_index} #{pane_current_command} #{pane_active} #{pane_last} #{pane_current_path} #{window_zoomed_flag}"
    | str trim
    | split row "\n"
    | each { |p|
		(match ($p | split row " ") {
			[$index, $cmd, $active, $lastActive, $currentPath, $zoomed] => {
				{
					index: $index
					cmd: $cmd
					active: ($active == "1")
					lastActive: ($lastActive == "1")
					currentPath: $currentPath
					zoomed: ($zoomed == "1")
				}
			},
		})
	}
}
