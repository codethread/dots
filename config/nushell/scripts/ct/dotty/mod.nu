# :module: Dotfile symlink management system with intelligent linking and caching
# Manages directory and file synchronization through intelligent symlink operations
# dotfiles from ~/some_dir into ~/
#
# `link` is the main command of interest
#
# Editor tooling can also be setup to run changes as needed, see `.config/nvim/lua/codethread/dotty.lua` for my reference
# - `dotty is-cwd` can help identify if dotty should be run for the given project
# - `dotty format` can display the output of `dotty link` in a nicer view for editors

use ct/core [clog is-not-empty md-list]
export use cache.nu
export use config.nu
use helpers.nu [assert-no-conflicts]
use list-files.nu

export def link [
	--no-cache(-c)
	--force(-f)
	config_path?: path # override config path for testing or bootstrapping a new system
]: nothing -> table<name: string, created: table, deleted: table> {
	let configs = config load $config_path

	$configs
	| par-each { |proj| get-project-files-to-link $proj $no_cache }
	| clog 'files' --expand
	| assert-no-conflicts --force=$force
	| par-each {|proj|
		# delete
		$proj.delete | each {|f| rm -f $f }

		# create
		$proj.files | get target | list-dirs-to-make | par-each {|dir| mkdir $dir }

		$proj.files
		| par-each {|f|
			# `try` because sometimes cache isn't up-to-date, so a link might
			# be recreated. This is trusting assert-no-conflicts to do it's job
			ln -sf $f.origin $f.target | complete | ignore
		}

		# update cache
		$proj.existing ++ ($proj.files | get file)
		| sort
		| cache store $proj.name

		$proj
		| rename --column { files: created, delete: deleted }
		| select name root created deleted
	}
	| where {|r| ($r.created | is-not-empty) or ($r.deleted | is-not-empty) }
}

# Format the output from `dotty link` into something easier to read, e.g in an
# editor cli
export def format []: table -> record<changes: bool, diff: string> {
	let links = $in
	let formatted = ($links
		| each {|proj|
			let has_created = ($proj.created | is-not-empty)
			let has_deleted = ($proj.deleted | is-not-empty)

			let created = $"Created:\n($proj.created | get file | md-list)\n"
			let deleted = $"Deleted:\n($proj.deleted | md-list)\n"

			$"## Project: ($proj.name)\n\n(if $has_created { $created } else "")(if $has_deleted { $deleted } else "")"
		}
		| str join ''
	)

	{
		changes: ($links | is-not-empty)
		diff: $formatted
	}
}

# Check if the given `dir` (defaults to PWD) is part of any dotty projects
# dir is only checked against the root of a dotty project, not a nested one
export def is-cwd [
	dir?: path # directory path to check
	--exit # returns an exit code rather than true/false
] {
	let target = if ($dir | is-not-empty) { $dir } else $env.PWD
	let proj = (config load | where origin == $target)
	match ([$exit, ($proj | is-empty)]) {
		[true, true] => { exit 1 },
		[true, false] => { exit 0 }
		[_, $is_cwd] => { not $is_cwd }
	}
}

# Remove symlinks that don't point to anything
export def prune [target: glob = ~/.config/**/*] {
	# Find broken filesystem symlinks (existing behavior)
	let broken_fs_symlinks = (
		ls -all --long ...(glob $target)
		| where type == symlink
		| where ($it.target | path exists | $in == false)
	)

	# Remove broken filesystem symlinks
	$broken_fs_symlinks | each { |f|
		print $"removing broken filesystem symlink ($f.name)";
		try { rm $f.name }
	}
}

export def teardown [] {
	config load
	| par-each {|proj|
		let files = cache load $proj.name

		$files | par-each {|f|
			let file_path = ($proj.target | path join $f)
			if ($file_path | path exists) {
				rm -f $file_path
			}
		}

		$files | each {|f| $proj.target | path join $f } | delete-empty-dirs

		cache delete $proj.name
	}
}

def delete-empty-dirs []: list<string> -> list<string> {
	list-dirs-to-make
	| par-each {|dir| ls $dir | is-empty | if $in { $dir } else null }
	| compact
	| each {|dir| rm $dir }
}

# takes a list of files and returns a list of directories that will need
# to be created for them
def list-dirs-to-make []: list<string> -> list<string>  {
	path parse
	| get parent
	| uniq
	| sort
	| reduce --fold [""] {|it, acc|
		if ($it | str starts-with ($acc | last)) {
			let final_pos = ($acc | length) - 1
			$acc | upsert $final_pos $it
		} else {
			$acc | append $it
		}
	}
}

def get-project-files-to-link [proj, no_cache] {
	# this may not have linked yet, so just to be sure
	$env.GIT_CONFIG_GLOBAL = ([$env.DOTFILES "config/git/config"] | path join)

	# cd in order to get all the gitignores correct
	cd $proj.origin
	let cache = cache load $proj.name

	let files = if ($cache | is-empty) {
		list-files $proj.origin --excludes $proj.excludes --fresh
	} else {
		list-files $proj.origin --excludes $proj.excludes
	}

	let $new_files = $files | match ($no_cache) {
		true => { $in },
		false => { where { $in not-in $cache } },
	}

	# TODO having a no_cache option messes with deleting old files
	let to_delete = $cache | where { $in not-in $files }
	let existing = (if $no_cache { [] } else { $cache | where { $in not-in $to_delete } })

	{
		name: $proj.name,
		root: $proj.origin,
		files:
		($new_files | each {|file|
			{
				file: $file,
				origin:  ($proj.origin | path join $file),
				target: ($proj.target | path join $file)
			}
		})
		delete: ($to_delete | each {|f| $proj.target | path join $f | path relative-to $env.HOME })
		existing: $existing,
	}
}

