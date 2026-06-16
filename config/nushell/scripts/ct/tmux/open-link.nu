# :module: Intelligent file opening utility for tmux and neovim with dynamic path resolution

use utils.nu get-panes

# Open a file path in nvim if nvim is open in the main pane
export def main [...path] {
    let home = $env.HOME
    # Don't grab the tmux border char.
    let chosen = $path | str trim | str replace "│" ""

    let panes = get-panes

    let is_active = $panes | where { $in.cmd == 'nvim' and $in.active == true } | is-empty | $in == false

    let filePWD = (match ($is_active) {
		true =>  { $panes | where lastActive == true | first | get currentPath },
		false => { $panes | where active == true | first | get currentPath }
	})

    let editorPWD = $panes | where cmd == 'nvim' | first | get currentPath

    let diff = $editorPWD | path relative-to $filePWD

    (match ($chosen | split row ":") {
		[$file, $line, $col] => {
			let path = [$editorPWD $diff $file] | path join
			tmux send-keys -t 1 :e Space `+call\` Space $"cursor\(($line),($col)\)" Space $path Enter
		},
		[$file, $line] => {
			let path = [$editorPWD $diff $file] | path join
			# tmux send-keys -t 1 :e Space +$line Space $path Enter
			tmux send-keys -t 1 :e Space $"+($line)" Space $path Enter
		},
		[$file] => {
			let path = [$editorPWD $diff $file] | path join
			tmux send-keys -t 1 :e Space $path Enter
		},
		[] => { tmux display-message "no path selected"},
	})

    tmux select-pane -t 1
}
