# Homebrew utilities — packages are managed declaratively through nix-darwin.
# These aliases are for maintenance tasks on the residual homebrew casks/brews.

export def brewclean [] {
    brew cleanup
    brew autoremove
}

export alias brewdeps = brew deps --graph --installed

# Show what's installed via brew but not declared in nix-darwin configs
export def brewdrift [] {
    let nix_dir = [$env.DOTFILES nix hosts darwin] | path join
    let all_nix = glob ($nix_dir | path join "**/*.nix") | each { open $in } | str join "\n"

    let declared_brews = (extract-nix-list $all_nix "brews")
    let declared_casks = (extract-nix-list $all_nix "casks")
    let declared_vscode = (extract-nix-list $all_nix "vscode")

    print $"(ansi cyan)## Brew drift — installed but not in nix configs(ansi reset)"

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

def extract-nix-list [content: string, key: string]: nothing -> list<string> {
    $content
    | split row $"($key) = ["
    | skip 1
    | each { $in | split row "]" | first }
    | str join "\n"
    | parse --regex '"([^"]+)"'
    | get capture0
    | uniq
}

# Nudge: direct package installs should go through nix
export def "brew install" [...args] {
    print $"(ansi yellow)packages are managed by nix-darwin — add to nix/ configs then run `make system`(ansi reset)"
}

export def "brew tap" [...args] {
    print $"(ansi yellow)taps are managed by nix-darwin — add to nix/hosts/darwin/common.nix then run `make system`(ansi reset)"
}
