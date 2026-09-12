# Generate and install Bash completions through Carapace.
# Examples: setup completions br; setup completions gh
export def --wrapped "setup completions" [
    binary: string
    ...generation_args: string # Optional override for an unusual generation command
] {
    if not ($binary =~ '^[a-zA-Z0-9_][a-zA-Z0-9_.+-]*$') {
        error make {msg: "Pass a binary name, not a path."}
    }

    let args = if ($generation_args | is-empty) {
        # Discover the conventional subcommand from help, rather than passing
        # arbitrary positional arguments to a binary that may not support it.
        let help = do { run-external $binary ...["--help"] } | complete
        let text = $help.stdout + "\n" + $help.stderr
        let verb = if $text =~ '(?m)^\s*completions(?:\s|:)' {
            "completions"
        } else if $text =~ '(?m)^\s*completion(?:\s|:)' {
            "completion"
        } else {
            error make {msg: $"No completion subcommand found. Pass its generation arguments explicitly: setup completions ($binary) <args>"}
        }
        let subhelp = do { run-external $binary ...[$verb "--help"] } | complete
        let text = $subhelp.stdout + "\n" + $subhelp.stderr
        if $text =~ '(?m)^\s*(?:-\w,\s*)?--shell(?:\s|=)' {
            [$verb --shell bash]
        } else {
            [$verb bash]
        }
    } else { $generation_args }
    let generated = do { run-external $binary ...$args } | complete
    if $generated.exit_code != 0 {
        error make {msg: $"Completion generation failed: ($generated.stderr | str trim)"}
    }
    if ($generated.stdout | str trim | is-empty) {
        error make {msg: "Completion generation returned no Bash script."}
    }
    let checked = do {
        $generated.stdout | ^bash -n
    } | complete
    if $checked.exit_code != 0 {
        error make {msg: $"Not a valid Bash script: ($checked.stderr | str trim)"}
    }

    let origin = $env.DOTFILES | path join config carapace | path expand
    let destination = $env.XDG_CONFIG_HOME? | default ($nu.home-dir | path join .config)
    | path join carapace
    | path expand
    let files = [
        "bridge/bash/.bashrc"
        $"bridge/bash/($binary).bash"
        $"specs/($binary).yaml"
    ]
    let links = $files | each {|file|
        {source: ($origin | path join $file), target: ($destination | path join $file)}
    }
    for link in $links {
        if ($link.target | path exists --no-symlink) and (($link.target | path expand) != ($link.source | path expand)) {
            error make {msg: $"Refusing to replace unrelated config: ($link.target)"}
        }
    }

    mkdir ($origin | path join bridge bash) ($origin | path join specs)
    let wrapper = $origin | path join $"bridge/bash/($binary).bash"
    let spec = $origin | path join $"specs/($binary).yaml"
    let bridge = '$carapace.bridge.Bash([' + $binary + '])'
    $generated.stdout | save --force $wrapper
    {
        name: $binary
        description: $"Bash completions for ($binary)"
        parsing: disabled
        completion: {
            positionalany: [$bridge]
        }
    } | to yaml | save --force $spec

    for link in $links {
        if not ($link.target | path exists --no-symlink) {
            mkdir ($link.target | path dirname)
            let linked = ^ln -s $link.source $link.target | complete
            if $linked.exit_code != 0 {
                error make {msg: $"Could not link ($link.target): ($linked.stderr | str trim)"}
            }
        }
    }
    {binary: $binary, bash: $wrapper, spec: $spec}
}
