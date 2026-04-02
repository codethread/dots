@category mine
export def git_current_branch [] {
	# (gstat).branch
	git rev-parse --abbrev-ref HEAD
}

export def git_main_branch [] {
	git symbolic-ref refs/remotes/origin/HEAD | str trim | split row "/" | last
}

# login with glab cli
export def glogin [] {
	$env.CLI_GITLAB_TOKEN | glab auth login --stdin --hostname git.perkbox.io
}

export def gpristine [] {
	git reset --hard
	git clean -d --force -x
}

# export alias gcm = git checkout (git_main_branch)
export def gcm [...words: string] {
	let msg = ($words | str join " ")
	print $msg
	git commit --message $"($msg)"
}

export def gignore [] {
	git rm -r --cached .; git add .; git commit -m '.gitignore is now working'
}

export def grb [] {
	let count = (git log --oneline $"(git_main_branch)...HEAD" | lines | length)
	git rebase -i $"HEAD~($count)"
}

export def git_branch_diff [] {
	git rev-list --left-right --count $"(git_main_branch)...HEAD" | parse --regex '(?<behind>\w+).+(?<ahead>\w+)' | first
}

export def gmom [] {
	let main = (git_main_branch)
	git merge $"origin/($main)"
}

export def groh [] {
	git fetch origin
	git reset $"origin/$(git_current_branch)" --hard
}

export def gtv [] {
	git tag | lines | sort
}

export def gpoat [] {
	git push origin --all; git push origin --tags
}

export def gfuck [] {
	git fetch origin
	git reset --hard $"origin/(git_current_branch)"
}

export def gwip [msg = "wip"] {
	git add .;
	git commit -nm $msg;
}

export def gnah [--force] {
	if $force {
		git stash
	} else {
		git reset --hard
		git clean -df
	}
}

export def gnew [name: string] {
	if ($name | split chars | length) > 52 {
		error make { msg: "branch name can't exceed 52 chars!", label: { text: "branch", span: (metadata $name).span } }
	}
	let trunk = (git_main_branch)
	let target = $"($trunk):($trunk)"
	if ($trunk == (git_current_branch)) {
		print $"pulling ($trunk)"
		git pull
	} else {
		print $"fetching ($target)"
		git fetch origin $target
	}
	git checkout --no-track -b $name $trunk
	# git branch --unset-upstream err+out> /dev/null
}

export def gmm [] {
	let main = (git_main_branch)
	# fetch and update main
	git fetch origin $"($main):($main)"
	git rebase $main
}


export def gls [] {
	let line = (git log --oneline --decorate --color=always --format="%C(yellow)[%h] %C(magenta)%<(15)(%an)%C(auto): %s" | fzf --ansi --no-sort --reverse --tiebreak=index)
	print $line
}

export def gundo [] {
	git reset --soft HEAD~1
	git restore --staged .
}

export def gchanged [
	branch?: string
	--commit # just list for the current commit
] {
	match [$commit, $branch] {
	[true, _] => { git diff --name-only --diff-filter=d },
	[_, $b] if $b != null => { git diff --name-only --diff-filter=d $"($b)...HEAD" },
	_ => { git diff --name-only --diff-filter=d $"origin/(git_main_branch)...HEAD" },
}
}

export def git_reset_files [...files: string] {
	$files | each {|f|
		let c = $"git checkout origin/develop ($f)"
		print $c
		zsh -c $c
	}
}

export def git_pick_files [branch: string]: list<string> -> nothing {
	each {|f|
		let c = $"git checkout origin/($branch) ($f)"
		print $c
		zsh -c $c
	}
	ignore
}

export def git_squash [
	branch: string
	--this-branch # if true, will squash into the current branch, otherwise will checkout trunk
] {
	if $this_branch { error make { msg: 'not yet implemented' } }

	let main = (git_main_branch)
	git checkout $main
	git pull

	git merge --squash $branch

	let msg = git log --reverse --format=%H $"HEAD..($branch)" | lines | first
	git commit -C $msg
}

export def cdd --env [] {
	cd (git rev-parse --show-toplevel)
}

export def cdm --env [] {
	let root = (git worktree list --porcelain | lines | where {|l| $l | str starts-with "worktree "} | first | str replace "worktree " "")
	cd $root
}

# check for unstaged or uncommitted changes
export def git_is_dirty [] {
	git status --short | is-not-empty
}

export def loc [--git] {
	(if ($git) {
		git ls-tree -r (git_current_branch) --name-only
	} else {
			fd --type f --hidden --exclude '{.git}'
		})
	| lines | each {|f|
		wc -l $f | str trim | parse "{n} {f}" | get n | first| into int
	} | collect | math sum
}
