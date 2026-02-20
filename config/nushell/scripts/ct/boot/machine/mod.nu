use ct/dotty
use ct/macos.nu [macos_has_full_disk_access ]
use ct/brew
use ct/core [dedent]
use ct/editor.nu [nvim-sync]
use ct/git [git_is_dirty]
use homebrew.nu
use log.nu
use rustup.nu
use macos.nu

export def main [
	--skip-brew # skip installation and syncing of brew packages
	--clean # install fresh dirs
	--force # clean even with uncommitted changes
	--shell # rebuild shell tools like carapace
] {
	macos_has_full_disk_access

	log step  Dotty setting up dotfiles
	dotty link

	# setup some folder structures how I like them
	mkdir -v ~/dev/vendor/ ~/dev/learn/ ~/dev/projects/ ~/.local/cache/docs

	clone_tools --clean=$clean --force=$force

	if not $skip_brew {
		homebrew
	} else {
		log skip  "Homebrew"
	}

	setup-bins

	rustup

	setup-tooling --force=$shell

	try { macos }

	nvim-sync
}

# Install various projects I use either for boot or general use (not available
# through brew)
def clone_tools [
	--clean # install fresh dirs
	--force # clean even with uncommitted changes
] {
	log step Vendor setting up vendored projects

	let tools = [
		[git,                                   dir,          install];
		[git@github.com:nushell/nu_scripts.git, ~/dev/vendor, {||}]
		[git@github.com:gitwatch/gitwatch.git, ~/dev/vendor, {|| ln -f -s ~/dev/vendor/gitwatch/gitwatch.sh ~/.local/bin/gitwatch }]
		[git@github.com:codethread/alfred.git, ~/sync, {|| }]
		[git@github.com:codethread/todoist.git, ~/dev/vendor, {||
			try {
				git checkout codethread
				go install
			}
		}]
		[git@github.com:apple/container.git, ~/dev/vendor, {||
			# only needed till they fix --publish and stopping
			# kitty @ launch --type=os-window sh -c "BUILD_CONFIGURATION=release make all test integration && BUILD_CONFIGURATION=release make install"
			# echo "DONE!" | save --append ~/.container.log;
		}]
	]

	$tools | each { |t|
		cd $t.dir
		let project = ($t.git | parse --regex '.*?:(?<owner>.+?)/(?<repo>.+?)(?:\.git)?$' | first)
		let is_cloned = ($project.repo | path exists)

		if $clean and $is_cloned {
			print $"(ansi cyan)Cleaning(ansi reset) ($project.repo)"
			cd $project.repo

			if (git_is_dirty) and not $force {
				print $"(ansi yellow)WARN(ansi reset) ($project.repo) has unstaged changes"
				print "Uninstall manually first or run with --force"
				print ""
				return
			}

			cd -;
			rm -rf $project.repo
		}

		if not $is_cloned {
			print $"(ansi green)Cloning(ansi reset) ($t.git) into ($t.dir)"
			git clone -q $t.git
		}

		cd $project.repo
		print $"(ansi green)Running(ansi reset) install script for ($project.repo) at ($env.PWD)"
		do $t.install
		# job spawn -t $project.repo $t.install
	}
}

def setup-tooling [--force] {
	log step Tooling installing

	let carapace = ("~/.local/cache/carapace/init.nu" | path expand)
	if not ($carapace | path exists) or $force {
		log tool carapace setup
		mkdir ($carapace | path dirname)
		carapace _carapace nushell | save --force $carapace
	}

	let atuin = ("~/.local/share/atuin/init.nu" | path expand)
	if not ($atuin | path exists) or $force {
		log tool atuin setup
		mkdir ($atuin | path dirname)
		atuin init nu | save --force $atuin
	}
}

def setup-bins [] {
	log step Bins building bun binaries
	cd $env.DOTFILES
	cd oven
	bun run build
}
