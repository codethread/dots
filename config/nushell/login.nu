source ct/interactive/mod.nu

alias p = ^p
alias als = scope aliases

# alias yy = yazi

# Yazi and set CWD on `q`
def --env yy [...args] {
    let tmp = (mktemp -t "yazi-cwd.XXXXXX")
    ^yazi ...$args --cwd-file $tmp
    let cwd = (open $tmp)
    if $cwd != $env.PWD and ($cwd | path exists) {
        cd $cwd
    }
    rm -fp $tmp
}

def cdy [] {
    echo $env.PWD | pbcopy
}

const atuin = "~/.local/cache/dots/shell/atuin.nu" | path expand
source (if ($atuin | path exists) { $atuin } else { null })

const carapace = "~/.local/cache/dots/shell/carapace.nu" | path expand
source (if ($carapace | path exists) { $carapace } else { null })

source direnv.nu

const strand_completions = "/opt/homebrew/Library/Taps/codethread/homebrew-millstrand/integrations/nushell/strand-completions.nu" | path expand
source (if ($strand_completions | path exists) { $strand_completions } else { null })

def get-package-scripts [] {
    open package.json | get scripts | items {|key,_| $key }
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
]

export extern "yarn run" [
	cmd: string@get-package-scripts
]

# export extern "pp run" [
# 	cmd: string@get-package-scripts
# ] {
# 	^pnpm run $cmd
# }

export extern "yarn workspace" [
	workspace: string@get-workspace-names --only-scripts
]

#---------------------------------------------#
# AEROSPACE
# -------------------------------------------#

# CLI command to get IDs of running applications
export extern "aerospace list-apps" []
