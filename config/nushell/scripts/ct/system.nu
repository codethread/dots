# macOS system utilities and general OS functions
# Note: mac-dark-toggle, finder, loggy, alert are macOS-only (theme, open -a, osascript, afplay)
# They are safe to import on Linux but will error if invoked

export alias mac-dark-toggle = theme toggle
export alias l = ls -a
export alias finder = ^open -a 'Finder' .
export alias ports = lsof -i tcp:3000

export def port-kill [...ports: int] {
    $ports | each {|port| lsof -ti $"tcp:($port)" | lines | each {|pid| kill ($pid | into int) } }
}
export alias loggy = cd `~/Library/Mobile Documents/iCloud~com~logseq~logseq/`

export def alert [msg: string = "Task Finished"] {
    osascript -e $'display notification "($msg)" with title "CMD"'
    afplay /System/Library/Sounds/Glass.aiff
}

# I always forget
export def symlink [original: path, symbolic: path] {
    ln -s $original $symbolic
}

# export most common envs for POSIX-shell compatibility
export def dump-env [] {
    hide-all {|| bash -lc 'export' | save -f ~/.config/bash/env.local }
}
