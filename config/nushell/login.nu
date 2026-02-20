source ct/interactive/mod.nu

alias p = ^p
alias als = scope aliases

const atuin = ("~/.local/share/atuin/init.nu" | path expand)
source (if ($atuin | path exists) { $atuin } else { null })

const carapace = ("~/.local/cache/carapace/init.nu" | path expand)
source (if ($carapace | path exists) { $carapace } else { null })

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

export alias devbox = kitten ssh -t codethread@192.168.68.108 "tmux attach -t main || tmux new -s main"

#---------------------------------------------#
# AEROSPACE
# -------------------------------------------#

# CLI command to get IDs of running applications
export extern "aerospace list-apps" [] {}
