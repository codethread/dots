# this exists as a fallback for conditional sourcing to have something to source in an else branch
# e.g
# const empty = ($nu.default-config-dir | path join "empty.nu")
# const privates = ("~/.privates.nu" | path expand)
# source (if ($privates | path exists) { $privates } else { $empty })

def foo [] {
    print hey
}
