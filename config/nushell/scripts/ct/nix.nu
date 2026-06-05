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

def _flake_path [] {
	(_dotfiles_root | path join "nix")
}

def _flake_ref [profile: string] {
	$"path:((_flake_path))#($profile)"
}

def _hm_user_for_profile [profile: string] {
	match $profile {
		"work" => "adam.hall",
		"work-adamhall" => "adamhall",
		_ => "codethread",
	}
}

def _smoke-check [check: string, ok: bool, detail: string] {
	{
		check: $check
		ok: $ok
		detail: ($detail | str trim)
	}
}

def _which-path [cmd: string] {
	try {
		(which $cmd | get 0.path)
	} catch {
		null
	}
}

def _path-has [entry: string] {
	let want = ($entry | path expand)
	($env.path | any {|p| ($p | path expand) == $want })
}

def _expected-config-check [check: string, actual: string, expected: string] {
	if not ($actual | path exists) {
		(_smoke-check $check false $"missing: ($actual)")
	} else {
		let resolved = ($actual | path expand)
		let want = ($expected | path expand)
		let detail = if $resolved == $want { $resolved } else { $"($resolved)\n    expected: ($want)" }
		(_smoke-check $check ($resolved == $want) $detail)
	}
}

def _nix_eval_check [check: string, attr: string] {
	let result = (do {
		^nix eval $attr --apply "map (p: p.name)" --json
	} | complete)

	if $result.exit_code == 0 {
		let count = ($result.stdout | from json | length)
		(_smoke-check $check true $"count=($count)")
	} else {
		let detail = (
			[$result.stdout $result.stderr]
			| each {|s| ($s | default "" | str trim) }
			| where {|s| $s != "" }
			| str join " / "
		)
		(_smoke-check $check false $detail)
	}
}

# Resolved flake host/profile name for the current machine
export def nrs-flake-host [profile?: string] {
	_resolve_profile ($profile | default (_default_profile))
}

# Rebuild and switch system configuration (nixos-rebuild or darwin-rebuild)
export def nrs [profile?: string, --update(-u)] {
	if $update { nfu }
	let p = (_resolve_profile ($profile | default (_default_profile)))
	let flake = (_flake_ref $p)
	if (sys host).name == "Darwin" {
		print $"sudo -H darwin-rebuild switch --flake '($flake)'"
		sudo -H darwin-rebuild switch --flake $flake
	} else {
		print $"sudo nixos-rebuild switch --flake '($flake)'"
		sudo nixos-rebuild switch --flake $flake
		_kernel_reboot_check
	}
}

# Warn if the running kernel differs from the one NixOS will boot into
def _kernel_reboot_check [] {
	let running = (^uname -r)
	let booted = (ls /run/current-system/kernel-modules/lib/modules | get name | path basename | first)
	if $running != $booted {
		print $"\n(ansi yellow_bold)⚠ Reboot advised(ansi reset): running kernel (ansi d)($running)(ansi reset) differs from new kernel (ansi d)($booted)(ansi reset)"
	}
}

# Update flake inputs
export def nfu [] {
	nix flake update --flake $"path:((_flake_path))"
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
	let flake = $"path:((_flake_path))"
	let config_type = if ($p in ["home" "work" "work-adamhall"]) { "darwinConfigurations" } else { "nixosConfigurations" }
	let attr = $"($flake)#($config_type).($p).config.home-manager.users.($env.USER).home.packages"
	^nix eval $attr --apply "map (p: p.name)" --json | from json | sort | uniq
}

# List system-level packages for a profile
export def nix-sys-packages [profile?: string] {
	let p = (_resolve_profile ($profile | default (_default_profile)))
	let flake = $"path:((_flake_path))"
	let config_type = if ($p in ["home" "work" "work-adamhall"]) { "darwinConfigurations" } else { "nixosConfigurations" }
	let attr = $"($flake)#($config_type).($p).config.environment.systemPackages"
	^nix eval $attr --apply "map (p: p.name)" --json | from json | sort | uniq
}

export def nix-update-llm [] {
	let flake = $"path:((_flake_path))"
	nix flake update llm-agents --flake $flake
}

def _brew_config_attr [profile: string, attr: string] {
	let flake = $"path:((_flake_path))"
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
	^nix flake show $"path:((_flake_path))"
}

# Smoke-test that the local Nix-managed environment and linked configs are present.
export def nix-smoke [
	profile?: string # defaults to the current machine profile
	--skip-flake # skip nix eval checks against the flake
] {
	let p = (_resolve_profile ($profile | default (_default_profile)))
	let flake = $"path:((_flake_path))"
	let config_type = if ($p in ["home" "work" "work-adamhall"]) { "darwinConfigurations" } else { "nixosConfigurations" }
	let hm_user = (_hm_user_for_profile $p)
	let dotfiles = ($env.DOTFILES? | default ($env.HOME | path join "dev" "dots"))
	let xdg_config = ($env.XDG_CONFIG_HOME? | default ($env.HOME | path join ".config"))
	let is_nixos = ("/etc/NIXOS" | path exists)

	mut checks = [
		(_smoke-check "PATH has ~/.local/bin" (_path-has ($env.HOME | path join ".local/bin")) ($env.HOME | path join ".local/bin"))
		(_smoke-check "PATH has /nix/var/nix/profiles/default/bin" (_path-has "/nix/var/nix/profiles/default/bin") "/nix/var/nix/profiles/default/bin")
		(_smoke-check $"PATH has /etc/profiles/per-user/($env.USER)/bin" (_path-has $"/etc/profiles/per-user/($env.USER)/bin") $"/etc/profiles/per-user/($env.USER)/bin")
	]

	if $is_nixos {
		$checks = ($checks ++ [
			(_smoke-check "PATH has /run/current-system/sw/bin" (_path-has "/run/current-system/sw/bin") "/run/current-system/sw/bin")
			(_smoke-check "PATH has /run/wrappers/bin" (_path-has "/run/wrappers/bin") "/run/wrappers/bin")
		])
	}

	for cmd in [nix nu nvim tmux git rg fd jq bun claude codex pi playwright-cli cc-sandbox] {
		let resolved = (_which-path $cmd)
		$checks = ($checks | append (_smoke-check $"binary: ($cmd)" ($resolved != null) ($resolved | default "missing")))
	}

	let platform_cmd = if $is_nixos { "nixos-rebuild" } else { "darwin-rebuild" }
	let platform_path = (_which-path $platform_cmd)
	$checks = ($checks | append (_smoke-check $"binary: ($platform_cmd)" ($platform_path != null) ($platform_path | default "missing")))

	for file_check in [
		{
			check: "config: pi settings"
			actual: ($env.HOME | path join ".pi/agent/settings.json")
			expected: ($dotfiles | path join "pi/settings.json")
		}
		{
			check: "config: nushell env"
			actual: ($xdg_config | path join "nushell/env.nu")
			expected: ($dotfiles | path join "config/nushell/env.nu")
		}
		{
			check: "config: nushell config"
			actual: ($xdg_config | path join "nushell/config.nu")
			expected: ($dotfiles | path join "config/nushell/config.nu")
		}
		{
			check: "config: codex"
			actual: ($xdg_config | path join "codex/config.toml")
			expected: ($dotfiles | path join "config/codex/config.toml")
		}
		{
			check: "config: kitty"
			actual: ($xdg_config | path join "kitty/kitty.conf")
			expected: ($dotfiles | path join "config/kitty/kitty.conf")
		}
		{
			check: "config: ghostty startup"
			actual: ($xdg_config | path join "ghostty/startup.sh")
			expected: ($dotfiles | path join "config/ghostty/startup.sh")
		}
	] {
		$checks = ($checks | append (_expected-config-check $file_check.check $file_check.actual $file_check.expected))
	}

	# settings.json is Nix-store-managed (read-only), not dotty-symlinked — just check it exists
	let claude_settings = ($env.HOME | path join ".claude/settings.json")
	$checks = ($checks | append (_smoke-check "config: claude settings (nix)" ($claude_settings | path exists) $claude_settings))

	if not $skip_flake {
		let home_attr = $"($flake)#($config_type).($p).config.home-manager.users.($hm_user).home.packages"
		let sys_attr = $"($flake)#($config_type).($p).config.environment.systemPackages"
		$checks = ($checks ++ [
			(_nix_eval_check "flake eval: home packages" $home_attr)
			(_nix_eval_check "flake eval: system packages" $sys_attr)
		])
	}

	let report = (
		$checks
		| each {|check| $check | upsert status (if $check.ok { "ok" } else { "fail" }) }
		| select check status detail
	)

	$report | table -e

	let failures = ($checks | where ok == false)
	if ($failures | is-not-empty) {
		print $"\n(ansi red_bold)Failed checks:(ansi reset)"
		for f in $failures {
			print $"  (ansi red)✗(ansi reset) ($f.check): ($f.detail)"
		}
		error make { msg: "nix smoke failed" }
	}

	$report
}
