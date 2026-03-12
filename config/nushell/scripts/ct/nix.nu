# Cross-platform Nix utilities — rebuild, GC, package queries
# NixOS-only commands (boot target, Wi-Fi, store info) are in nixos.nu

def _darwin_default_profile [] {
	match ($env.CT_USER? | default (match ($env.USER? | default "") {
		"adam.hall" => "work",
		"adamhall" => "work-adamhall",
		_ => "home",
	})) {
		"work-adamhall" => "work-adamhall",
		"work" => "work",
		_ => "home",
	}
}

def _default_profile [] {
	if (sys host).name == "Darwin" { (_darwin_default_profile) } else { "homelab" }
}

def _resolve_profile [profile: string] {
	if (sys host).name != "Darwin" { return $profile }

	match [$profile ($env.USER? | default "")] {
		["work" "adamhall"] => "work-adamhall",
		_ => $profile,
	}
}

def _flake_ref [profile: string] {
	$"path:($env.HOME)/PersonalConfigs/nix#($profile)"
}

# Rebuild and switch system configuration (nixos-rebuild or darwin-rebuild)
export def nrs [profile?: string] {
	let p = (_resolve_profile ($profile | default (_default_profile)))
	let flake = (_flake_ref $p)
	if (sys host).name == "Darwin" {
		print $"darwin-rebuild switch --flake '($flake)'"
		sudo darwin-rebuild switch --flake $flake
	} else {
		print $"sudo nixos-rebuild switch --flake '($flake)'"
		sudo nixos-rebuild switch --flake $flake
	}
}

# Update flake inputs
export def nfu [] {
	nix flake update --flake $"path:($env.HOME)/PersonalConfigs/nix"
}

# Delete all old generations and run garbage collection
export def nix-clean [] {
	sudo nix-collect-garbage -d
}

# Delete generations older than N days (default: 14) then GC
export def nix-clean-older [days: int = 14] {
	sudo nix-collect-garbage --delete-older-than $"($days)d"
}

# List home-manager packages for a profile
export def nix-packages [profile?: string] {
	let p = (_resolve_profile ($profile | default (_default_profile)))
	let flake = $"path:($env.HOME)/PersonalConfigs/nix"
	let config_type = if ($p in ["home" "work" "work-adamhall"]) { "darwinConfigurations" } else { "nixosConfigurations" }
	let attr = $"($flake)#($config_type).($p).config.home-manager.users.($env.USER).home.packages"
	^nix eval $attr --apply "map (p: p.name)" --json | from json | sort | uniq
}

# List system-level packages for a profile
export def nix-sys-packages [profile?: string] {
	let p = (_resolve_profile ($profile | default (_default_profile)))
	let flake = $"path:($env.HOME)/PersonalConfigs/nix"
	let config_type = if ($p in ["home" "work" "work-adamhall"]) { "darwinConfigurations" } else { "nixosConfigurations" }
	let attr = $"($flake)#($config_type).($p).config.environment.systemPackages"
	^nix eval $attr --apply "map (p: p.name)" --json | from json | sort | uniq
}

def _brew_config_attr [profile: string, attr: string] {
	let flake = $"path:($env.HOME)/PersonalConfigs/nix"
	^nix eval $"($flake)#darwinConfigurations.($profile).config.homebrew.($attr)" --json
		| from json
		| get name
}

# Validate homebrew taps/brews/casks in the nix config resolve before rebuilding (no sudo needed)
export def nrs-check [profile?: string] {
	let p = (_resolve_profile ($profile | default (_darwin_default_profile)))
	print $"Checking brew config for profile: ($p)"

	let taps = (_brew_config_attr $p "taps")
	let current_taps = ((^brew tap | complete).stdout | lines)
	mut errors = []
	let missing_taps = ($taps | where {|t| $t not-in $current_taps })
	for tap in $missing_taps {
		print $"Tapping ($tap)..."
		let result = (do { brew tap $tap } | complete)
		if $result.exit_code != 0 {
			$errors = ($errors | append $"tap failed: ($tap)")
		}
	}

	let brews = (_brew_config_attr $p "brews")
	let casks = (_brew_config_attr $p "casks")

	for name in $brews {
		let result = (do { brew info --formula $name } | complete)
		if $result.exit_code != 0 {
			$errors = ($errors | append $"brew formula not found: ($name)")
		}
	}
	for name in $casks {
		let result = (do { brew info --cask $name } | complete)
		if $result.exit_code != 0 {
			$errors = ($errors | append $"brew cask not found: ($name)")
		}
	}

	if ($errors | is-empty) {
		print $"All ($brews | length) brews and ($casks | length) casks validated OK"
	} else {
		print $"($errors | length) errors found:"
		for e in $errors { print $"  ✗ ($e)" }
		error make { msg: "brew config validation failed" }
	}
}

# Show all flake outputs
export def nix-outputs [] {
	^nix flake show $"path:($env.HOME)/PersonalConfigs/nix"
}
