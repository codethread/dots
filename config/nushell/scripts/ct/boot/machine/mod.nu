use ct/macos.nu [macos_has_full_disk_access]
use ct/editor.nu [nvim-sync]

# Extra first-boot checks after mise has applied the workstation.
export def main [] {
    if (sys host).name != "Darwin" {
        error make {msg: "boot machine supports macOS only"}
    }

    macos_has_full_disk_access

    nvim-sync
}
