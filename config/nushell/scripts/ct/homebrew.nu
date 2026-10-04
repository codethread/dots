# Homebrew utilities — packages are managed declaratively through mise.
# These aliases are for maintenance tasks on the shared Homebrew casks/brews.

export def brewclean [] {
    brew cleanup
    brew autoremove
}

export alias brewdeps = brew deps --graph --installed

# Show installed packages not declared in any mise machine profile.
export def brewdrift [] {
    let root = $env.DOTFILES
    let configs = (
        (glob ($root | path join "mise*.toml"))
        ++ (glob ($root | path join ".mise/conf.d/*.toml"))
        | each { open $in }
    )
    let packages = $configs
    | each { get -o bootstrap.packages | default {} | columns }
    | flatten
    let declared_brews = $packages
    | where { $in | str starts-with "brew:" }
    | each { $in | str replace "brew:" "" | split row "/" | last }
    let declared_casks = $packages
    | where { $in | str starts-with "brew-cask:" }
    | each { $in | str replace "brew-cask:" "" | split row "/" | last }
    let declared_vscode = $configs
    | each {|cfg|
        [
            ($cfg | get -o vars.vscode_extensions | default "")
            ($cfg | get -o vars.vscode_work_extensions | default "")
        ] | str join " " | split row " " | where { $in != "" }
    }
    | flatten

    print $"(ansi cyan)## Brew drift — installed but not in mise configs(ansi reset)"

    print $"\n(ansi green)brews:(ansi reset)"
    let brew_drift = with-env { HOMEBREW_NO_AUTO_UPDATE: 1 } {
		^brew bundle dump --brews --file=-
	}
    | lines
    | each { $in | parse 'brew "{name}"' | get -o 0.name }
    | compact
    | each { $in | split row "/" | last }
    | where { $in not-in $declared_brews }
    $brew_drift | each { print $"  ($in)" } | ignore

    print $"\n(ansi green)casks:(ansi reset)"
    let cask_drift = with-env { HOMEBREW_NO_AUTO_UPDATE: 1 } {
		^brew bundle dump --casks --file=-
	}
    | lines
    | each { $in | parse 'cask "{name}"' | get -o 0.name }
    | compact
    | each { $in | split row "/" | last }
    | where { $in not-in $declared_casks }
    $cask_drift | each { print $"  ($in)" } | ignore

    print $"\n(ansi green)vscode extensions:(ansi reset)"
    let ext_drift = ^code --list-extensions
    | lines
    | where { $in not-in $declared_vscode }
    $ext_drift | each { print $"  ($in)" } | ignore
}

# Nudge: direct package installs should go through mise declarations.
export def "brew install" [...args] {
    print $"(ansi yellow)packages are managed by mise — add to .mise/conf.d/packages.toml or mise.<profile>.toml then run `mise -E <profile> bootstrap packages apply`(ansi reset)"
}

export def "brew tap" [...args] {
    print $"(ansi yellow)taps are managed by mise — use fully-qualified brew:owner/tap/formula entries; custom URLs belong in bootstrap.brew.taps(ansi reset)"
}
