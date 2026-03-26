use helpers.nu *
use kitty.nu *

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
		git worktree add -b $branch $tree_dir $"origin/($branch)"
	} else {
		print $"(ansi green)creating ($branch) from origin/($base_branch)(ansi reset)"
		git worktree add -b $branch $tree_dir $"origin/($base_branch)"
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

	wk-open-dir $tree_dir $branch
}

# remove a worktree by branch name (does not delete the branch)
export def "wk remove" [
	branch: string   # branch name used when the worktree was added
] {
	let tree_dir = wk-worktree-path $branch
	git worktree remove $tree_dir
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
