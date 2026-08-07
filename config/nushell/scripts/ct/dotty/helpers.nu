# :module: Utility functions for preventing symlink conflicts and path overlaps

# Check that files won't be overriten during the linking stage, exit with an error if not
export def assert-no-conflicts [
	--force # delete existing files without confirmation
]: table -> table {
    let proj = $in

    let files = $proj
    | get files
    | each {|| get target }
    | reduce --fold [] {|it,acc| $it ++ $acc }

    let repeated_files = $files | uniq --repeated
    match ($repeated_files | is-empty) {
        false => {
            let msg = $"multiple files attempted to write to ($repeated_files | str join ","). Process cancelled"
            error make -u {msg: $msg}
        }
        _ => { $files }
    }

    let existing_files = $files | par-each {|file| { file: $file, exists: (file-exists $file) } } | where exists == true | get file

    if ($existing_files | is-not-empty) and $force {
        $existing_files | each {|f| rm $f }
    } else if ($existing_files | is-not-empty) {
        let msg = $"target files already exist; pass --force to remove them:\n($existing_files | to text)"
        error make -u {msg: $msg}
    }

    $proj
}

def file-exists [file: path] {
    ($file | path exists) and (is-symlink $file | not $in)
}

def is-symlink [file: path] {
    ($file | path exists) and (do { ^test -L $file } | complete | get exit_code) == 0
}
