# Stable scalar environment and PATH come from the shared Bash contract.
$env.DOTFILES = ($env.DOTFILES? | default ($nu.home-dir | path join "dev/dots"))
let env_emitter = $env.DOTFILES | path join "config/env/emit.sh"

let base_args = if $nu.is-interactive {
    [$env_emitter "--print0" "--interactive"]
} else {
    [$env_emitter "--print0"]
}

let imported = (
    ^/bin/sh ...$base_args
    | split row (char nul)
    | compact --empty
    | parse --regex '^(?<key>[^=]+)=(?<value>.*)$'
    | reduce --fold {} {|row, vars| $vars | upsert $row.key $row.value }
)
load-env $imported
$env.PATH = ($env.PATH | split row (char esep))

# Preserve Nushell-native types for conditions and conversions.
$env.IS_NIXOS = $env.IS_NIXOS == "true"
$env.IS_WORK = $env.IS_WORK == "true"
$env.KSM_WORK = $env.KSM_WORK == "true"
$env.ENV_CONVERSIONS = {
    CT_LOG: {
        from_string: {|s|
            $s | into bool
        }
        to_string: {|v| $"($v)" }
    }
}

# Nushell-only discovery paths.
$env.NU_LIB_DIRS = [
    ($nu.default-config-dir | path join "scripts")
    ($env.DOTFILES | path join "config/nushell/scripts")
    ($nu.home-dir | path join "dev/vendor/nu_scripts/sourced")
]
$env.NU_PLUGIN_DIRS = [$env.CARGO_BIN]
$env.PATH = ($env.PATH | uniq)
