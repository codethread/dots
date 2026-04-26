# NixOS-only utilities — boot target, store info, Wi-Fi helpers

def _dotfiles_root [] {
	let fallback = ($env.DOTFILES? | default ($env.HOME | path join "dev" "dots"))
	let git_root = (do { ^git rev-parse --show-toplevel } | complete)

	if $git_root.exit_code == 0 {
		let root = ($git_root.stdout | str trim)
		if (($root | path join "nix") | path exists) and (($root | path join "config/nushell/env.nu") | path exists) {
			return $root
		}
	}

	$fallback
}

def _flake_ref [profile: string] {
	$"path:((_dotfiles_root | path join 'nix'))#($profile)"
}

# Rebuild and set boot target (use when switching would change critical components e.g. dbus)
export def nrb [profile: string = "homelab"] {
	sudo nixos-rebuild boot --flake (_flake_ref $profile)
}

# Show current store size and generation count
export def nix-store-info [] {
	print $"Store size: (^du -sh /nix/store | cut -f1)"
	nix-env --list-generations --profile /nix/var/nix/profiles/system
}

# Wi-Fi helpers (NetworkManager)
export def nix-wifi-setup [
	--ssid: string = "pie-fi"
	--env-file: path = "/etc/codethread/nm.env"
	--var: string = "PIFI_PSK"
] {
	let psk = (input --suppress-output $"Wi-Fi password for ($ssid): ")
	if ($psk | str length) == 0 {
		error make { msg: "Wi-Fi password cannot be empty" }
	}

	let env_dir = ($env_file | path dirname)
	^sudo mkdir -p $env_dir
	$"($var)=($psk)\n" | ^sudo tee $env_file | ignore
	^sudo chmod 600 $env_file
}

export def nix-wifi-restart [] {
	^sudo systemctl restart NetworkManager-ensure-profiles.service
}

export def nix-wifi-setup-debug [
	--env-file: path = "/etc/codethread/nm.env"
] {
	^sudo systemctl status NetworkManager-ensure-profiles.service -n 50 --no-pager
	^sudo journalctl -u NetworkManager-ensure-profiles.service -b --no-pager | ^tail -n 80
	^sudo ls -l $env_file
	^sudo cut -d= -f1 $env_file
}
