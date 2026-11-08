# Homebrew utilities — packages are managed declaratively through mise.
# These aliases are for maintenance tasks on the shared Homebrew casks/brews.

export def brewclean [] {
    brew cleanup
    brew autoremove
}

export alias brewdeps = brew deps --graph --installed

# Nudge: direct package installs should go through mise declarations.
export def "brew install" [...args] {
    print $"(ansi yellow)packages are managed by mise — add packages to their owning repository's mise config, then run `mise bootstrap` from that checkout(ansi reset)"
}

export def "brew tap" [...args] {
    print $"(ansi yellow)taps are managed by mise — use fully-qualified brew:owner/tap/formula entries; custom URLs belong in bootstrap.brew.taps(ansi reset)"
}
