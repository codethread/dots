# detect the default branch for the current repo from git's remote HEAD metadata
export def wk-default-branch [] {
	let sym = (git symbolic-ref refs/remotes/origin/HEAD | complete)
	if $sym.exit_code == 0 {
		$sym.stdout | str trim | str replace "refs/remotes/origin/" ""
	} else {
		let remote = (git remote show origin | complete)

		if $remote.exit_code == 0 {
			let head_line = ($remote.stdout
				| lines
				| find "HEAD branch:"
				| first
			)

			if ($head_line | is-not-empty) {
				$head_line | str trim | str replace "HEAD branch: " ""
			} else {
				error make { msg: "couldn't determine remote default branch from git remote show origin" }
			}
		} else {
			error make { msg: "couldn't determine remote default branch; pass a base branch explicitly" }
		}
	}
}

export def wk-canonical-root [] {
	let listing = (git worktree list --porcelain | complete)

	if $listing.exit_code != 0 {
		error make { msg: "couldn't list git worktrees" }
	}

	let roots = ($listing.stdout | lines | where {|line| $line | str starts-with "worktree " })

	if ($roots | is-empty) {
		error make { msg: "couldn't determine canonical worktree" }
	}

	$roots | first | str replace "worktree " ""
}

export def wk-encode-branch [branch: string] {
	let parts = ($branch | split row "/" | where {|part| $part != "" })

	if ($parts | is-empty) {
		error make { msg: $"invalid branch name: ($branch)" }
	}

	$parts | str join "--"
}

export def wk-worktree-path [branch: string] {
	let canonical_root = wk-canonical-root
	let encoded_branch = wk-encode-branch $branch
	$"($canonical_root)__($encoded_branch)"
}

export def wk-config-path [] {
	let config_home = if "XDG_CONFIG_HOME" in $env {
		$env.XDG_CONFIG_HOME
	} else {
		$env.HOME | path join ".config"
	}

	$config_home | path join "ct-worktrees" "trees.toml"
}

export def wk-post-create-hooks [] {
	let config_path = wk-config-path

	if not ($config_path | path exists) {
		return []
	}

	let config = (open $config_path)

	($config | get -o post_create | default [])
	| where {|hook| (($hook | get -o root | default null) != null) and (($hook | get -o command | default null) != null) }
	| each {|hook|
		let shell = (($hook | get -o shell | default "bash") | str downcase)
		if ($shell in ["bash" "nu"]) {
			{
				name: ($hook | get -o name | default $hook.root)
				root: ($hook.root | path expand)
				shell: $shell
				command: $hook.command
			}
		} else {
			error make { msg: $"invalid worktree post-create shell: ($shell)" }
		}
	}
}

export def wk-matching-post-create-hooks [root_dir: string] {
	let root_path = ($root_dir | path expand)
	wk-post-create-hooks | where {|hook| $hook.root == $root_path }
}

export def wk-list-data [] {
	let listing = (git worktree list --porcelain | complete)

	if $listing.exit_code != 0 {
		error make { msg: "couldn't list git worktrees" }
	}

	let canonical_root = wk-canonical-root
	let blocks = ($listing.stdout | str trim | split row "\n\n" | where {|block| ($block | str trim) != "" })

	$blocks | each {|block|
		mut item = {
			path: null
			head: null
			branch: null
			branch_ref: null
			detached: false
			bare: false
			locked: false
			lock_reason: null
			prunable: false
			prunable_reason: null
			canonical: false
		}

		for line in ($block | lines) {
			if ($line | str starts-with "worktree ") {
				let path = ($line | str replace "worktree " "")
				$item = ($item | upsert path $path | upsert canonical ($path == $canonical_root))
			} else if ($line | str starts-with "HEAD ") {
				$item = ($item | upsert head ($line | str replace "HEAD " ""))
			} else if ($line | str starts-with "branch ") {
				let branch_ref = ($line | str replace "branch " "")
				$item = ($item
					| upsert branch_ref $branch_ref
					| upsert branch ($branch_ref | str replace "refs/heads/" "")
				)
			} else if ($line == "detached") {
				$item = ($item | upsert detached true)
			} else if ($line == "bare") {
				$item = ($item | upsert bare true)
			} else if ($line | str starts-with "locked") {
				let reason = ($line | str replace "locked " "")
				$item = ($item
					| upsert locked true
					| upsert lock_reason (if $reason == $line { null } else { $reason })
				)
			} else if ($line | str starts-with "prunable") {
				let reason = ($line | str replace "prunable " "")
				$item = ($item
					| upsert prunable true
					| upsert prunable_reason (if $reason == $line { null } else { $reason })
				)
			}
		}

		$item
	}
}
