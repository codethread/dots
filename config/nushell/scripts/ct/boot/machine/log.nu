const pad = '    '

export def step [title: string, ...msg: string] {
	print $"(ansi green)($title | str upcase)(ansi reset) ($msg | str join ' ')"
}

export def sub-step [...msg: string] {
	print $"($pad)(ansi reset) ($msg | str join ' ')"
}

export def bash [cmd: string] {
	print $"($pad)(ansi cyan)(ansi white_bold)bash> $(ansi reset) ($cmd)(ansi reset)"
}

export def tool [title: string, ...msg: string] {
	print $"($pad)(ansi blue)($title | str upcase)(ansi reset) ($msg| str join ' ')"
}

export def skip [title: string, ...msg: string] {
	print $"($pad)(ansi magenta)($title | str upcase)(ansi reset) ($msg| str join ' ')"
}

export def warn [...msg:string --indent] {
	print $"(if $indent { $pad } else { "" })(ansi yellow)WARN:(ansi reset) ($msg|str join ' ')"
}
