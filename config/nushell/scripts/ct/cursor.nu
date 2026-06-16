# TODO: might nuke all user settings
const USER_CONF: path = echo `~/Library/Application Support/Cursor/User` | path expand

export alias _cursor_open_config = nvim $USER_CONF

# script to walk through linking cursor config to vscode.
export def _cursor_link [
	--with-import # will prompt to import via cursor
] {
    let cursor_files = [[cursor, code]; [(get-file cursor settings.json), (get-file dots settings.json)], [(get-file cursor keybindings.json), (get-file dots keybindings.json)]]

    # check-assumptions $cursor_files

    prompt-to-close

    if $with_import {
        echo "Removing existing settings to avoid code settings getting altered"

        ($cursor_files | get cursor | where { $in | path exists } | each {|f|
			print $"(ansi green)Removing(ansi reset) ($f)"
			rm $f --force
		})

        prompt-to-import
        input "Confirm you have imported settings <enter>:"
        input "Sure?"

        prompt-to-close
    }

    echo "Linking settings and keybindings"

    ($cursor_files | each {|f|
		let cursor = $f.cursor
		let code = $f.code
		print $"(ansi magenta)Deleting(ansi reset) ($cursor)"
		rm $cursor --force
		print $"(ansi green)Linking(ansi reset) ($cursor) ($code)"
		try { ln -s $code $cursor }
	})

    print $"(ansi green)Linking(ansi reset) extensions"
    let cursor_ext = echo "~/.cursor/extensions" | path expand
    let code_ext = echo "~/.vscode/extensions" | path expand
    mkdir (dirname $code_ext) (dirname $cursor_ext)
    ln -s $code_ext $cursor_ext

    ignore
}

def prompt-to-close [] {
    let get_cursor = {||
        ps | where name == Cursor | is-not-empty
    }
    mut cursor_running = do $get_cursor
    while $cursor_running {
        input "Cursor running. Close it then <enter>"
        $cursor_running = do $get_cursor
    }
}

def prompt-to-import [] {
    let get_cursor = {||
        ps | where name == Cursor | is-empty
    }
    if (do $get_cursor) {
        print "Cursor closed, opening..."
        cursor
    }

    mut cursor_running = (do $get_cursor)
    while $cursor_running {
        print "Cursor not running. waiting..."
        sleep 3sec
        $cursor_running = do $get_cursor
    }

    print $"Cursor open, go (ansi magenta)import your settings(ansi reset)"
}

def check-assumptions [files: list<string>] {
    let target = $USER_CONF

    if not ($target | path exists) { return }

    let existing = ls $target

    if ($files | length) != ($existing | length) {
        print $"(ansi yellow)WARNING: additional files that may need porting"
        print "Existing" $existing
        print "Expected" $files
    }
}

# app dots | cursor
# file settings | keybindings
def get-file [app: string, file: string] {
    let base = [Library `Application Support`]
    match $app {
        dots => ([$env.DOTFILES ...$base Code User $file])
        cursor => ([~ ...$base Cursor User $file])
    } | path join | path expand -n
}
