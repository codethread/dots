source ct/interactive/mod.nu

alias p = ^p
alias als = scope aliases

alias yy = yazi

# linux clipboard equivalents for pbcopy/pbpaste (wayland)
if ($env.IS_NIXOS) {
	alias pbcopy = wl-copy
	alias pbpaste = wl-paste
}

const atuin = ("~/.local/share/atuin/init.nu" | path expand)
source (if ($atuin | path exists) { $atuin } else { null })

const carapace = ("~/.local/cache/carapace/init.nu" | path expand)
source (if ($carapace | path exists) { $carapace } else { null })

const direnv = ("~/.local/cache/direnv/init.nu" | path expand)
source (if ($direnv | path exists) { $direnv } else { null })

def get-package-scripts [] {
	open package.json | get scripts | items { |key,_| $key }
}

def get-workspace-names [--only-scripts] {
	fd package.json
	| lines
	| par-each {|| open $in }
	| where {|pj| match ($only_scripts) {
		true => { "scripts" in $pj },
		false => { "name" in $pj }
	}
	}
	| get name
}

export extern "bun run" [
	cmd: string@get-package-scripts
] {
	^bun run $cmd
}

export extern "yarn run" [
	cmd: string@get-package-scripts
] {
	^yarn run $cmd
}

# export extern "pp run" [
# 	cmd: string@get-package-scripts
# ] {
# 	^pnpm run $cmd
# }

export extern "yarn workspace" [
	workspace: string@get-workspace-names --only-scripts
] {
	^yarn workspace $workspace
}

#---------------------------------------------#
# AEROSPACE
# -------------------------------------------#

# CLI command to get IDs of running applications
export extern "aerospace list-apps" [] {}
