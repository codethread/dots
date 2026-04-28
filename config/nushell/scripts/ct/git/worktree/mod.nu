use helpers.nu *
use tmux.nu *

# print the stable root path for the current repo
export def "wk root" [] {
	wk-canonical-root
}

# print the stable sibling worktree path for a branch
export def "wk path" [
	branch: string
] {
	wk-worktree-path $branch
}

# add a sibling worktree at <canonical-root>__<encoded-branch>
# if branch exists (local or remote) it is checked out; otherwise created from base
export def --env "wk add" [
	branch: string   # branch to create or checkout
	base?: string    # base branch to create from (default: repo default branch)
] {
	let repo_root = wk-canonical-root
	let tree_dir = wk-worktree-path $branch

	# fetch all remote refs so branch existence checks are current
	print $"(ansi green)fetching origin(ansi reset)"
	git fetch origin

	let base_branch = if $base == null { wk-default-branch } else { $base }

	let local_branches = (git branch --format="%(refname:short)" | complete).stdout | lines | str trim
	let remote_branches = (git branch -r --format="%(refname:short)" | complete).stdout | lines | str trim

	if $branch in $local_branches {
		print $"(ansi green)checking out existing local branch ($branch)(ansi reset)"
		git worktree add $tree_dir $branch
	} else if $"origin/($branch)" in $remote_branches {
		print $"(ansi green)checking out existing remote branch ($branch)(ansi reset)"
		git worktree add --no-track -b $branch $tree_dir $"origin/($branch)"
	} else {
		print $"(ansi green)creating ($branch) from origin/($base_branch)(ansi reset)"
		git worktree add --no-track -b $branch $tree_dir $"origin/($base_branch)"
	}

	if $"origin/($branch)" in $remote_branches {
		print $"(ansi green)updating ($branch) from origin(ansi reset)"
		let ff = (git -C $tree_dir merge --ff-only $"origin/($branch)" | complete)
		if $ff.exit_code == 0 {
			print $"(ansi green)updated ($branch) to latest origin/($branch)(ansi reset)"
		} else {
			print $"(ansi yellow)warning:(ansi reset) couldn't fast-forward ($branch) to origin/($branch)"
			if (($ff.stderr | str trim) != "") {
				print ($ff.stderr | str trim)
			}
		}
	}

	let post_create_hooks = (wk-matching-post-create-hooks $repo_root)
	wk-open-dir $tree_dir $branch $repo_root $post_create_hooks
}

# remove a worktree by branch name and delete its branch
export def --env "wk remove" [
	branch?: string  # branch name used when the worktree was added
	--self           # use the current branch
	--force          # pass force through to worktree + branch removal
] {
	let tree_dir = if $self {
		# resolve to worktree root so removal works from any subdirectory
		let rev = (git rev-parse --show-toplevel | complete)
		if $rev.exit_code != 0 {
			error make { msg: "couldn't resolve current worktree root" }
		}
		$rev.stdout | str trim
	} else if $branch != null {
		wk-worktree-path $branch
	} else {
		error make { msg: "provide a branch name or pass --self" }
	}
	let repo_root = wk-canonical-root
	if $tree_dir == $repo_root {
		error make { msg: "cannot remove the canonical worktree" }
	}

	let worktree = (wk-list-data | where path == $tree_dir)
	if ($worktree | is-empty) {
		error make { msg: $"couldn't find worktree at ($tree_dir)" }
	}
	let target_branch = ($worktree | first | get branch)

	# cd home only when currently inside the target worktree, so the shell
	# isn't stranded in a deleted directory after removal
	if ($env.PWD == $tree_dir or ($env.PWD | str starts-with $"($tree_dir)/")) {
		cd ~
	}

	if $force {
		git -C $repo_root worktree remove --force $tree_dir
	} else {
		git -C $repo_root worktree remove $tree_dir
	}

	if $target_branch != null {
		if $force {
			git -C $repo_root branch -D $target_branch
		} else {
			git -C $repo_root branch -d $target_branch
		}
	}

	wk-close-dir $tree_dir
}

export def "wk list" [
	--json
] {
	if $json {
		wk-list-data | to json
	} else {
		git worktree list
	}
}

# fuzzy-pick and switch to a worktree in the current repository
export def --env "wk switch" [] {
	let git_check = (git rev-parse --git-dir | complete)
	if $git_check.exit_code != 0 {
		^tmux display-message "not in a git repository"
		return
	}

	let worktrees = wk-list-data
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
	# fzf refs are 1-indexed ({2}=pane_id, {3}=path); nushell split column is 0-indexed (column2=path, column3=branch)
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
			let repo_root = wk-canonical-root
			wk-open-dir $path $branch $repo_root []
		}
		130 | 1 => {}
		_ => { print $"(ansi red)fzf error ($result.exit_code)(ansi reset)" }
	}
}
