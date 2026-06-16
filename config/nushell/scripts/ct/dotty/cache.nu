# :module: Manage local cache for tracking previously linked files

# get a list of previously linked files
export def load [name: string]: nothing -> list<string> {
    let conf = $"~/.local/data/dotty-cache-($name).nuon" | path expand
    match ($conf | path exists) {
        true => { open $conf }
        false => { [] }
    }
}

# store the updated cache
export def store [name: string]: list<string> -> nothing {
    let data = $in
    let conf = $"~/.local/data/dotty-cache-($name).nuon" | path expand
    $data | to nuon --indent 2 | save -f $conf
}

# delete cache
export def delete [name: string]: nothing -> nothing {
    let conf = $"~/.local/data/dotty-cache-($name).nuon" | path expand
    match ($conf | path exists) {
        true => { rm $conf }
    }
}
