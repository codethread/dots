# Generate Bash completions and Carapace specs for mise deployment.
# Examples: setup completions gh; setup completions uv generate-shell-completion bash
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

    {binary: $binary, bash: $wrapper, spec: $spec}
}
