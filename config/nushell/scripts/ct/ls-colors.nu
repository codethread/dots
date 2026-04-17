# TODO: cache vivid output to XDG_STATE_HOME keyed by theme name to avoid invoking vivid on every shell start

export-env {
	let _theme_file = ($env.XDG_STATE_HOME | path join "color-theme")
	let _is_light = ($_theme_file | path exists) and ((open $_theme_file | str trim) == "light")
	# TODO: switch to tokyonight-day once vivid ships a light tokyonight theme
	let _theme = if $_is_light { "tokyonight-day" } else { "tokyonight-moon" }
	$env.LS_COLORS = (vivid generate $_theme)
}
