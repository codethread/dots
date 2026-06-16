use ct/core [dedent]

export def main [] {
    {
        pre_execution: [] # run before the repl input is run
        pre_prompt: [] # run before the prompt is shown
        env_change: {
            PWD: [
                ...(fe-stuff)
                ...(be-stuff)
            ]
        }
        # display_output: "if (term size).columns >= 100 { table -e } else { table }" # run to display the output of a pipeline
        command_not_found: [] # return an error message when a command is not found
    }
}

const fes = [~/work/app]

def fe-stuff [] {
    [
        {|before, after|
            if (is-fe $before) { print $"(ansi yellow) FE environment unloaded(ansi reset)" }
        }
        # {
        # 	condition: {|before, after| is-fe $after },
        # 	code: 'alias "git push" = gitlab push'
        # },
        {|before, after|
            if (is-fe $after) { print $"(ansi blue) FE environment loaded(ansi reset)" }
        }
    ]
}

def be-stuff [] {
    [
        {|before, after|
            if (is-be $before) { print $"(ansi yellow) BE environment unloaded(ansi reset)" }
        }
        {
            condition: {|before, after| is-be $after }
            code: (dedent '
				git config url."ssh://git@git.perkbox.io/".insteadOf https://git.perkbox.io/
				git config url."https://github.com/".insteadOf git://github.com/
				')
        }
        {|before, after|
            if (is-be $after) { print $"(ansi blue) BE environment loaded(ansi reset)" }
        }
    ]
}

def is-fe [dir?: path] {
    if ($dir | is-empty) { return false }
    $fes | path expand | where {|p| $dir | str starts-with $p } | is-not-empty
}

def is-be [dir?: path] {
    if ($dir | is-empty) { return false }
    glob ~/work/* --no-file --depth 1 --exclude [app] | where {|p| $dir | str starts-with $p } | is-not-empty
}
