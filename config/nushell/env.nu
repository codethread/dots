# Inherit the login environment, including any mise-selected project PATH.
# Only human-facing additions need importing for an interactive child shell.
if $nu.is-interactive {
    let env_emitter = $env.DOTFILES | path join "config/env/emit.sh"
    let imported = (
        ^/bin/sh $env_emitter --print0 --interactive
        | split row (char nul)
        | compact --empty
        | parse --regex '^(?<key>[^=]+)=(?<value>.*)$'
        | reduce --fold {} {|row, vars| $vars | upsert $row.key $row.value }
    )
    load-env $imported
    $env.PATH = ($env.PATH | split row (char esep))
}

# Preserve Nushell-native types for conditions and conversions.
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

# mise activation is a generated module. Regenerate it for each interactive
# startup so the baked environment reflects this session; noninteractive
# shells use shims or `mise exec` and never write or import it.
if $nu.is-interactive {
    ^mise activate nu | save --force ($nu.default-config-dir | path join mise.nu)
}
