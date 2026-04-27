export def nup [arg] { prev $arg }

export def plugs [] {
	help commands | where command_type == "plugin"
}

export def cmds [] {
	help commands | where command_type == "custom" | reject params
}

# checks if `cmd` is an alias or command and returns appropriate info
export def what [...cmd: string] {
	help --find ($cmd | str join " ")
}

export def nud [] {
	let val = $in;
	print $val;
	$val
}

export def pathis [] {
	$env.PATH
}

export def is-not-empty [] {
	is-empty | not $in
}

# logger: print arguments
export def clog [
	title = "log"
	--expand # expand piped input (assumes table input)
	...args
] {
	let val = $in;

	if ($env.CT_LOG? | default '0' | into bool) {
		print $"---- ($title) -----"

		$args | each { print $in }

		if $expand {
			print ($val | table --expand --flatten)
		} else {
			print $val
		}
	}

	$val
}

export def is_work [] {
	($env.CT_USER) == 'work'
}

export def is_home [] {
	($env.CT_USER) == 'home'
}

# print a string, removing all space from the begining of each line
export def dedent [str: string] {
	echo $str
	| lines --skip-empty
	| str trim
	| str join "\n"
}

# format a list as a markdown list
export def md-list []: list<string> -> string {
	str join "\n- " | "- " ++ $in
}

# run a closure and hide nearly all environment variables
export def hide-all [closure: closure] {
	let allow = [TMUX
		TERM
		SHELL
		PWD
		USER
		XPC
		PATH
		HOME
		DOTFILES
		EDITOR

		CT_USER
		CT_NOTES

		RUSTUP_HOME
		CARGO_HOME
		CARGO_BIN

		WAKATIME_HOME

		FZF

		GOBIN
		GOPATH

		VOLTA
		HUSKY
	]

	let hidden = ($env
		| transpose name value
		| where {|e|
			$allow | any {|s| $e.name starts-with $s } | $in == false
		}
		| get name)

	hide-env ...$hidden
	do $closure
}


export alias cd0 = cd (tmux-session --print 0)
export alias cd1 = cd (tmux-session --print 1)
export alias cd2 = cd (tmux-session --print 2)
export alias cd3 = cd (tmux-session --print 3)
export alias cd4 = cd (tmux-session --print 4)
export alias cd5 = cd (tmux-session --print 5)
export alias cd6 = cd (tmux-session --print 6)
export alias cd7 = cd (tmux-session --print 7)
export alias cd8 = cd (tmux-session --print 8)
export alias cd9 = cd (tmux-session --print 9)
