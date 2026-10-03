use ct/macos.nu [macos_has_full_disk_access]
use ct/editor.nu [nvim-sync]
use log.nu

# Extra first-boot checks after mise has applied the workstation.
export def main [] {
    if (sys host).name != "Darwin" {
        error make {msg: "boot machine supports macOS only"}
    }

    macos_has_full_disk_access

    setup-bins

    nvim-sync
}

def setup-bins [] {
    log step Bins building bun binaries
    cd $env.DOTFILES
    cd oven
    bun run build
}
