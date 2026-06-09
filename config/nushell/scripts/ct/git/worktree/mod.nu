use tmux.nu *

# Run a wktree command and return its structured JSON payload plus exit status.
def wktree-outcome [body: closure] {
	let result = (do $body | complete)
	if $result.stderr != "" {
		print --stderr --no-newline $result.stderr
	}
	let stdout = ($result.stdout | str trim)
	let payload = if $stdout == "" { null } else { $stdout | from json }
	{
		exit_code: $result.exit_code
		payload: $payload
	}
}

def wktree-message [payload: record fallback: string] {
	if "message" in $payload {
		$payload.message
	} else {
		$fallback
	}
}

def pick-pool-slot [branch: string candidates: list<record> force: bool] {
	let items = ($candidates | each {|candidate|
		let branch_name = ($candidate.branch | default "(detached)")
		let risk = ([
			(if $candidate.dirty { "[dirty]" } else { "" })
			(if $candidate.ahead > 0 { $"[($candidate.ahead) ahead]" } else { "" })
			(if $candidate.local_only { "[local-only]" } else { "" })
		] | where {|flag| $flag != "" } | str join " ")
		let risk_suffix = if $risk == "" { "" } else { $"  ($risk)" }
		{
			label: $"feat($candidate.slot)  ($branch_name)  ($candidate.path)($risk_suffix)"
			path: $candidate.path
			branch: $branch_name
		}
	})

	let selection = (try {
		$items | get label | input list --fuzzy $"Recycle which worktree for ($branch)?"
	} catch {
		null
	})
	if $selection == null or $selection == "" {
		return null
	}
	let selected = ($items | where label == $selection | first)
	if $force {
		return $selected
	}
	let answer = ((input $"Recycle ($selected.branch) at ($selected.path)? [y/N]: ") | str trim | str downcase)
	if $answer not-in ["y", "yes"] {
		return null
	}
	$selected
}

# Print the canonical/root worktree path for the current git repository.
export def "wk root" [] {
	^wktree root --cwd $env.PWD | str trim
}

# Print the worktree path for a branch without opening it.
# Non-pooled repos use a stable sibling path; pooled repos require the branch to already occupy a slot.
export def "wk path" [
	branch: string # branch whose worktree path should be printed
] {
	^wktree path --cwd $env.PWD --branch $branch | str trim
}

def pull-latest-default-branch [root: string] {
	let default_branch = (
		^git -C $root remote show origin
		| lines
		| where {|line| ($line | str trim | str starts-with "HEAD branch:") }
		| first
		| str replace --regex '^\s*HEAD branch:\s*' ''
		| str trim
	)
	if $default_branch == "" {
		error make { msg: "couldn't determine origin default branch" }
	}

	let current_branch = (^git -C $root branch --show-current | str trim)
	if $current_branch != $default_branch {
		error make { msg: $"--latest requires root worktree ($root) to be on ($default_branch), found ($current_branch)" }
	}

	^git -C $root pull --ff-only origin $default_branch
}

# Add or allocate a worktree for a branch, then open it in the current tmux workflow.
# New branches default to origin's default branch/trunk, even when run from another worktree.
export def --env "wk add" [
	branch: string   # branch to create or checkout
	base?: string    # branch to create from for new branches; defaults to origin's default branch/trunk
	--self           # use the current worktree branch as --base
	--latest         # pull latest origin default branch/trunk before creating the worktree
	--force          # skip recycle confirmation when the pool is full
] {
	let current_branch = if $self {
		let result = (git branch --show-current | complete)
		if $result.exit_code != 0 or ($result.stdout | str trim) == "" {
			error make { msg: "--self requires the current worktree to be on a branch" }
		}
		$result.stdout | str trim
	} else {
		null
	}
	if $self and $base != null {
		error make { msg: "provide either --self or an explicit base, not both" }
	}
	if $latest and $self {
		error make { msg: "provide either --latest or --self, not both" }
	}
	if $latest and $base != null {
		error make { msg: "provide either --latest or an explicit base, not both" }
	}

	let selected_base = if $self { $current_branch } else { $base }
	if $latest {
		pull-latest-default-branch (wk root)
	}
	let outcome = (wktree-outcome {||
		let args = [add --cwd $env.PWD --branch $branch --json]
		let args = if $selected_base == null { $args } else { $args | append [--base $selected_base] | flatten }
		let args = if $force { $args | append "--force" } else { $args }
		^wktree ...$args
	})

	if $outcome.payload == null {
		if $outcome.exit_code != 0 {
			error make { msg: "wktree add failed" }
		}
		return
	}

	match $outcome.payload.kind {
		"ready" => {
			wk-open-dir $outcome.payload.worktree_path $outcome.payload.title --runner-path ($outcome.payload.runner_script_path | default "")
		}
		"pool_full" => {
			let selected = (pick-pool-slot $branch $outcome.payload.candidates $force)
			if $selected == null {
				return
			}
			let retry = (wktree-outcome {||
				let args = [add --cwd $env.PWD --branch $branch --json --slot $selected.path --force]
				let args = if $selected_base == null { $args } else { $args | append [--base $selected_base] | flatten }
				^wktree ...$args
			})
			if $retry.payload == null {
				if $retry.exit_code != 0 {
					error make { msg: "wktree add failed" }
				}
				return
			}
			if $retry.payload.kind != "ready" {
				error make { msg: (wktree-message $retry.payload $"wktree add returned ($retry.payload.kind)") }
			}
			wk-open-dir $retry.payload.worktree_path $retry.payload.title --runner-path ($retry.payload.runner_script_path | default "")
		}
		"blocked" => {
			error make { msg: (wktree-message $outcome.payload "wktree add blocked") }
		}
		_ => {
			error make { msg: $"unexpected wktree add result: ($outcome.payload.kind)" }
		}
	}
}

# Remove a non-pooled worktree, or recycle a pooled slot back to its placeholder branch.
# Pass a branch name, or use --self to target the current worktree.
export def --env "wk remove" [
	branch?: string  # branch name used when the worktree was added
	--self           # use the current worktree
	--force          # force removal/recycle
] {
	let self_path = if $self {
		^git rev-parse --show-toplevel | str trim
	} else {
		null
	}
	let cwd = $env.PWD
	if $self_path != null {
		cd ~
	}

	let outcome = (wktree-outcome {||
		let args = [remove --cwd $cwd --json]
		let args = if $self_path != null {
			$args | append [--self $self_path] | flatten
		} else if $branch != null {
			$args | append [--branch $branch] | flatten
		} else {
			error make { msg: "provide a branch name or pass --self" }
		}
		let args = if $force { $args | append "--force" } else { $args }
		^wktree ...$args
	})

	if $outcome.payload == null {
		if $self_path != null {
			cd $cwd
		}
		if $outcome.exit_code != 0 {
			error make { msg: "wktree remove failed" }
		}
		return
	}
	if $outcome.payload.kind != "ready" {
		if $self_path != null {
			cd $cwd
		}
		error make { msg: (wktree-message $outcome.payload $"wktree remove returned ($outcome.payload.kind)") }
	}
	wk-close-dir $outcome.payload.worktree_path
	if ($env.PWD == $outcome.payload.worktree_path or ($env.PWD | str starts-with $"($outcome.payload.worktree_path)/")) {
		cd ~
	}
}

# List worktrees for the current repository, initializing configured pooled slots first.
export def "wk list" [
	--json # return structured JSON/table data instead of formatted text
] {
	if $json {
		^wktree list --cwd $env.PWD --json | from json
	} else {
		^wktree list --cwd $env.PWD
	}
}

# Fuzzy-pick a worktree in the current repository and switch/open it via the tmux workflow.
# Shows existing tmux pane previews when a worktree is already open; otherwise previews recent git log.
export def --env "wk switch" [] {
	let git_check = (git rev-parse --git-dir | complete)
	if $git_check.exit_code != 0 {
		^tmux display-message "not in a git repository"
		return
	}

	let worktrees = (wk list --json)
	let current_path = (git rev-parse --show-toplevel | complete).stdout | str trim
	let others = $worktrees | where path != $current_path

	if ($others | is-empty) {
		^tmux display-message "only one worktree (current)"
		return
	}

	# build map of pane_current_path -> pane_id from live tmux panes
	let tmux_panes = (^tmux list-panes -a -F "#{pane_id}\t#{pane_current_path}" | complete).stdout
		| lines
		| parse "{pane_id}\t{pane_path}"

	# tab fields: display \t pane_id \t path \t branch
	# fzf refs are 1-indexed ({2}=pane_id, {3}=path); nushell split column names are 0-indexed (column2=path, column3=branch)
	let candidates = $worktrees | each { |wt|
		let branch = if $wt.detached { "(detached)" } else { $wt.branch }
		let marker = if $wt.path == $current_path { "*" } else { " " }
		let matched = $tmux_panes | where { |p| $p.pane_path == $wt.path or ($p.pane_path | str starts-with $"($wt.path)/") }
		let pane_id = if ($matched | is-empty) { "" } else { $matched | first | get pane_id }
		$"($marker) ($branch)\t($pane_id)\t($wt.path)\t($branch)"
	}

	let result = (
		$candidates
		| str join "\n"
		| fzf-tmux -p -w 80% -h 70%
			--prompt "Worktree > "
			--delimiter $"\t"
			--with-nth 1
			--preview "bash -c 'p={2}; [ -n \"$p\" ] && tmux capture-pane -ep -t \"$p\" 2>/dev/null || git -C \"{3}\" log --oneline -20 2>/dev/null'"
			--preview-window "down,70%,wrap"
		| complete
	)

	match $result.exit_code {
		0 => {
			let line = $result.stdout | str trim
			let parts = $line | split column "\t"
			let path = $parts | get column2.0
			let branch = $parts | get column3.0
			wk-open-dir $path $branch
		}
		130 | 1 => {}
		_ => { print $"(ansi red)fzf error ($result.exit_code)(ansi reset)" }
	}
}
