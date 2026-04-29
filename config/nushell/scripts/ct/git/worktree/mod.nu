use tmux.nu *

# Run a wktree command that writes a JSON plan to a temp file, then return the parsed plan.
def wktree-plan [body: closure] {
	let result_file = (mktemp -t wktree-plan.XXXXXX)
	do $body $result_file | ignore
	let exit_code = ($env.LAST_EXIT_CODE? | default 0)
	if $exit_code != 0 {
		rm -f $result_file
		return null
	}
	let plan = (open --raw $result_file | from json)
	rm -f $result_file
	$plan
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

# Add or allocate a worktree for a branch, then open it in the current tmux workflow.
# New branches default to origin's default branch/trunk, even when run from another worktree.
export def --env "wk add" [
	branch: string   # branch to create or checkout
	base?: string    # branch to create from for new branches; defaults to origin's default branch/trunk
	--self           # use the current worktree branch as --base
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

	let plan = (wktree-plan {|result_file|
		let selected_base = if $self { $current_branch } else { $base }
		let args = [add --cwd $env.PWD --branch $branch --result-file $result_file]
		let args = if $selected_base == null { $args } else { $args | append [--base $selected_base] | flatten }
		let args = if $force { $args | append "--force" } else { $args }
		^wktree ...$args
	})

	if $plan == null { return }
	wk-open-dir $plan.worktree_path $plan.title --runner-path ($plan.runner_script_path | default "")
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

	let plan = (wktree-plan {|result_file|
		let args = [remove --cwd $cwd --result-file $result_file]
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

	if $plan == null { return }
	wk-close-dir $plan.worktree_path
	if ($env.PWD == $plan.worktree_path or ($env.PWD | str starts-with $"($plan.worktree_path)/")) {
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
	# fzf refs are 1-indexed ({2}=pane_id, {3}=path); nushell split column is 1-indexed (column3=path, column4=branch)
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
			let path = $parts | get column3.0
			let branch = $parts | get column4.0
			wk-open-dir $path $branch
		}
		130 | 1 => {}
		_ => { print $"(ansi red)fzf error ($result.exit_code)(ansi reset)" }
	}
}
