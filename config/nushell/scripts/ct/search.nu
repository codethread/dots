# Search and file discovery utilities

export def pj [...deps: string] {
    let search = $deps | str join "|" | $"\"\(($in)\)\""
    print $search
    rg --glob "**/package.json" $search
}

# print out a table where each cell is clearly marked, helpful when understanding empty lists
export alias table-debug = table --theme thin

# just a better name for ls
export alias vo = ls
