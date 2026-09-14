def mill-bin-completions [] {
    mill bin list | from json | get bins | get name
}

export def --wrapped msr [bin: string@"mill-bin-completions", ...args: string] {
    mill bin run $bin ...$args
}

export def --wrapped msb [bin: string@"mill-bin-completions", ...args: string] {
    mill bin build $bin ...$args
}

export alias ai = mill bin run agent --fzf
export alias aih = mill bin run agent tui
