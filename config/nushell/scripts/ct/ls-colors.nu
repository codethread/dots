# TODO: cache vivid output to XDG_STATE_HOME keyed by theme name to avoid invoking vivid on every shell start

export-env {
	let _theme_file = ($env.XDG_STATE_HOME | path join "color-theme")
	let _family_file = ($env.XDG_STATE_HOME | path join "color-theme-family")
	let _is_light = ($_theme_file | path exists) and ((open $_theme_file | str trim) == "light")
	let _family = if ($_family_file | path exists) { open $_family_file | str trim } else { "tokyonight" }
	let _theme = match [$_family $_is_light] {
		["rose-pine" true] => "rose-pine-dawn"
		["rose-pine" false] => "rose-pine-moon"
		["tokyonight" true] => "tokyonight-day"
		_ => "tokyonight-moon"
	}
	$env.LS_COLORS = (vivid generate $_theme)
}
