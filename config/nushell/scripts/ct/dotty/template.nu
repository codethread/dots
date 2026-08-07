# :module: Bidirectional three-way synchronization for structured configuration files

const cache_dir = "~/.local/data/dotty-templates"

export def apply [template: record] {
    if ($template.target | path exists) and (is-symlink $template.target) {
        error make {msg: $"Template '($template.name)' target is a symlink: ($template.target)"}
    }

    let source = open $template.origin
    let current = if ($template.target | path exists) { open $template.target } else { {} }
    let cached = load-cache $template.name
    let base_source = $cached | get --optional source | default {}
    let base_target = $cached | get --optional target | default $current
    let identities = $template | get --optional array_identity | default {}
    let result = (sync-node
        ""
        (some $base_source)
        (some $base_target)
        (some $source)
        (some $current)
        $identities
    )

    if ($result.errors | is-not-empty) {
        let details = $result.errors | each {|problem| $"  - ($problem.path): ($problem.message)" } | str join "\n"
        error make {
            msg: $"Template '($template.name)' has merge conflicts:\n($details)"
            help: "Resolve the listed source or target values, then run dotty link again. No files or cache were changed."
        }
    }

    let next_source = $result.source.value
    let next_target = $result.target.value
    let source_changed = $next_source != $source
    let target_changed = $next_target != $current

    mkdir ($template.target | path dirname)
    if $source_changed { atomic-save-toml $next_source $template.origin }
    if $target_changed { atomic-save-toml $next_target $template.target }

    mkdir ($cache_dir | path expand)
    let cache_file = cache-path $template.name
    atomic-save-toml {source: $next_source, target: $next_target} $cache_file
    ^chmod 600 $cache_file

    let source_change = if $source_changed {
        [
            {file: $template.origin, origin: $template.target, target: $template.origin}
        ]
    } else { [] }
    let target_change = if $target_changed {
        [
            {file: $template.target, origin: $template.origin, target: $template.target}
        ]
    } else { [] }

    {
        name: $template.name
        root: $template.origin
        created: ($source_change ++ $target_change)
        deleted: []
    }
}

export def delete-cache [name: string] {
    let path = cache-path $name
    if ($path | path exists) { rm $path }
}

def some [value] { {present: true, value: $value} }
def missing [] { {present: false, value: null} }
def cache-path [name: string] {
    $cache_dir | path expand | path join $"($name).toml"
}
def load-cache [name: string] {
    let path = cache-path $name
    if ($path | path exists) { open $path } else { {} }
}

def atomic-save-toml [value, target: path] {
    let temp = $"($target).dotty.tmp"
    $value | to toml | save --force $temp
    mv --force $temp $target
}

def kind [node: record] {
    if not $node.present { "missing" } else {
        let description = $node.value | describe
        if ($description | str starts-with "record") {
            "record"
        } else if ($description | str starts-with "list") or ($description | str starts-with "table") {
            "list"
        } else {
            "scalar"
        }
    }
}

def node-equal [left: record, right: record] {
    ($left.present == $right.present) and ((not $left.present) or ($left.value == $right.value))
}

def child [node: record, key: string] {
    if $node.present and ((kind $node) == "record") and ($key in $node.value) {
        some ($node.value | get $key)
    } else {
        missing
    }
}

def join-path [parent: string, child: string] {
    if ($parent | is-empty) { $child } else { $"($parent).($child)" }
}

def result [source: record, target: record] { {
    source: $source
    target: $target
    errors: []
} }
def conflict [
    path: string
    message: string
    source: record
    target: record
] {
    {
        source: $source
        target: $target
        errors: [
            {
                path: (if ($path | is-empty) { "<root>" } else { $path })
                message: $message
            }
        ]
    }
}

def structured-kind [nodes: list<any>] {
    let kinds = $nodes | where present | each {|node| kind $node } | where {|value| $value in [record list]} | uniq
    if ($kinds | length) == 1 {
        $kinds | first
    } else if ($kinds | is-empty) { null } else { "mixed" }
}

# The previous source defines ownership. Changes to an owned path synchronize
# in either direction. Paths absent from both source versions remain target-only.
def sync-node [
    path: string
    bs: record
    bt: record
    ns: record
    ct: record
    identities: record
] {
    let owned = $bs.present
    let source_changed = not (node-equal $ns $bs)
    let target_changed = not (node-equal $ct $bt)
    let structure = structured-kind [$bs $bt $ns $ct]

    if not $owned and not $ns.present {
        result (missing) $ct
    } else if $structure == "mixed" {
        (conflict
            $path
            "Source and target use incompatible structured types"
            $ns
            $ct
        )
    } else if $structure == "record" {
        if $owned and $source_changed and not $ns.present {
            if $target_changed and $ct.present {
                (conflict
                    $path
                    "The source removed this value while the target changed it"
                    $ns
                    $ct
                )
            } else {
                result (missing) (missing)
            }
        } else if $owned and $target_changed and not $ct.present {
            if $source_changed and $ns.present {
                (conflict
                    $path
                    "The target removed this value while the source changed it"
                    $ns
                    $ct
                )
            } else {
                result (missing) (missing)
            }
        } else {
            sync-record $path $bs $bt $ns $ct $identities
        }
    } else if $structure == "list" {
        sync-list $path $bs $bt $ns $ct $identities
    } else if not $owned {
        if $target_changed and not (node-equal $ct $ns) {
            (conflict
                $path
                "The source claimed this path while the target changed it differently"
                $ns
                $ct
            )
        } else {
            result $ns $ns
        }
    } else if not $source_changed and not $target_changed {
        result $ns $ct
    } else if $source_changed and not $target_changed {
        result $ns $ns
    } else if $target_changed and not $source_changed {
        result $ct $ct
    } else if (node-equal $ns $ct) {
        result $ns $ct
    } else {
        (conflict
            $path
            "Both source and target changed this owned value differently"
            $ns
            $ct
        )
    }
}

def sync-record [
    path: string
    bs: record
    bt: record
    ns: record
    ct: record
    identities: record
] {
    let keys = [$bs $bt $ns $ct]
    | each {|node| if $node.present and ((kind $node) == "record") { $node.value | columns } else { [] } }
    | flatten
    | uniq
    let folded = $keys | reduce --fold {source: {} target: {} errors: []} {|key, acc|
        let synced = sync-node (join-path $path $key) (child $bs $key) (child $bt $key) (child $ns $key) (child $ct $key) $identities
        let source = if $synced.source.present { $acc.source | upsert $key $synced.source.value } else { $acc.source }
        let target = if $synced.target.present { $acc.target | upsert $key $synced.target.value } else { $acc.target }
        {source: $source target: $target errors: ($acc.errors ++ $synced.errors)}
    }
    {
        source: (some $folded.source)
        target: (some $folded.target)
        errors: $folded.errors
    }
}

def list-value [node: record] {
    if $node.present and ((kind $node) == "list") { $node.value } else { [] }
}
def all-records [values: list<any>] { ($values | is-not-empty) and ($values | all {|value| ($value | describe | str starts-with "record") }) }
def all-scalars [values: list<any>] {
    $values | all {|value| not ($value | describe | str starts-with "record") }
}

def sync-list [
    path: string
    bs: record
    bt: record
    ns: record
    ct: record
    identities: record
] {
    let base_source = list-value $bs
    let base_target = list-value $bt
    let new_source = list-value $ns
    let current = list-value $ct
    let values = $base_source ++ $base_target ++ $new_source ++ $current

    if ($values | is-empty) or (all-scalars $values) {
        # Scalar-array order is meaningful, so synchronize the array as one value.
        sync-scalar-list $path $bs $bt $ns $ct
    } else if (all-records $values) {
        let identity = $identities | get --optional $path
        if ($identity | is-empty) {
            (conflict
                $path
                "Array records need an array_identity entry in dotty.toml"
                $ns
                $ct
            )
        } else {
            let invalid = $values | where {|value| ($value | get --optional $identity | is-empty) }
            if ($invalid | is-not-empty) {
                (conflict
                    $path
                    $"Some array records do not have the identity field '($identity)'"
                    $ns
                    $ct
                )
            } else {
                (sync-record-list
                    $path
                    $base_source
                    $base_target
                    $new_source
                    $current
                    $identity
                    $identities
                )
            }
        }
    } else {
        (conflict
            $path
            "Mixed scalar and record arrays cannot be synchronized"
            $ns
            $ct
        )
    }
}

def sync-scalar-list [
    path: string
    bs: record
    bt: record
    ns: record
    ct: record
] {
    let owned = $bs.present
    let source_changed = not (node-equal $ns $bs)
    let target_changed = not (node-equal $ct $bt)

    if not $owned {
        if $target_changed and not (node-equal $ct $ns) {
            (conflict
                $path
                "The source claimed this array while the target changed it differently"
                $ns
                $ct
            )
        } else {
            result $ns $ns
        }
    } else if not $source_changed and not $target_changed {
        result $ns $ct
    } else if $source_changed and not $target_changed {
        result $ns $ns
    } else if $target_changed and not $source_changed {
        result $ct $ct
    } else if (node-equal $ns $ct) {
        result $ns $ct
    } else {
        (conflict
            $path
            "Both source and target changed this owned array differently"
            $ns
            $ct
        )
    }
}

def item-id [item: record, identity: string] {
    $item | get $identity | to nuon
}
def find-item [items: list<any>, id: string, identity: string] {
    let found = $items | where {|item| (item-id $item $identity) == $id }
    if ($found | is-empty) { missing } else { some ($found | first) }
}
def duplicate-ids [items: list<any>, identity: string] {
    $items | each {|item| item-id $item $identity } | uniq --repeated
}

def sync-record-list [
    path: string
    bs: list<any>
    bt: list<any>
    ns: list<any>
    ct: list<any>
    identity: string
    identities: record
] {
    let duplicates = (duplicate-ids $bs $identity) ++ (duplicate-ids $bt $identity) ++ (duplicate-ids $ns $identity) ++ (duplicate-ids $ct $identity) | uniq
    if ($duplicates | is-not-empty) {
        (conflict
            $path
            $"Array contains duplicate identities: ($duplicates | str join ', ')"
            (some $ns)
            (some $ct)
        )
    } else {
        let ids = ($ns ++ $ct ++ $bs ++ $bt) | each {|item| item-id $item $identity } | uniq
        let folded = $ids | reduce --fold {source: [] target: [] errors: []} {|id, acc|
            let item_path = $"($path)[($identity)=($id)]"
            let synced = sync-node $item_path (find-item $bs $id $identity) (find-item $bt $id $identity) (find-item $ns $id $identity) (find-item $ct $id $identity) $identities
            let source = if $synced.source.present { $acc.source | append $synced.source.value } else { $acc.source }
            let target = if $synced.target.present { $acc.target | append $synced.target.value } else { $acc.target }
            {source: $source target: $target errors: ($acc.errors ++ $synced.errors)}
        }
        {
            source: (some $folded.source)
            target: (some $folded.target)
            errors: $folded.errors
        }
    }
}

def is-symlink [path: path] { (do { ^test -L $path } | complete | get exit_code) == 0 }
