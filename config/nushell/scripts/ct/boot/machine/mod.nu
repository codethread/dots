use ct/macos.nu [macos_has_full_disk_access]
use ct/editor.nu [nvim-sync]
use log.nu

# Post-nix-rebuild tasks — system rebuild is handled by boot.sh or `make system`
export def main [] {
	let is_macos = ((sys host).name == "Darwin")
	let is_nixos = ("/etc/NIXOS" | path exists)

	if not $is_macos and not $is_nixos {
		error make {msg: "boot machine supports macOS and NixOS only"}
	}

	if $is_macos {
		macos_has_full_disk_access
	}

	setup-bins

	nvim-sync
}

def setup-bins [] {
	log step Bins building bun binaries
	cd $env.DOTFILES
	cd oven
	bun run build
}
