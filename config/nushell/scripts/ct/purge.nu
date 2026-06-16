# Search through projects, find the largest and present them ina fuzzy finder
# to be purged. At this point a git clean is run
#
# TODO:
# - would be charming to get the output
# - add some flags for actually deleting
# - show size in fuzzy if possible
export def main [] {
    let purged = dirs
    | path expand
    | where { path exists }
    | each {|p| ls $p
		| where type == "dir"
		| get name
	}
    | flatten
    | par-each {|d| $d | get-dir-size }
    | flatten
    | sort
    | last 30
    | get name
    | to text
    | fzf --multi

    print "To purge"
    print $purged
    let choice = (input $"(ansi red)PURGE?(ansi reset) [Y/n]: ")

    if ($choice | str trim) != "n" {
        let logfile = "/tmp/purge.log"
        $"Purge started at (date now)\n" | save -f $logfile

        $purged
        | lines
        | each {|dir|
			$"Processing: ($dir)\n" | save -a $logfile
			print $"(ansi cyan)Cleaning ($dir)(ansi reset)"

			$"Running git clean...\n" | save -a $logfile
			let result = do { git -C $dir clean -dfX } | complete
			$"Exit code: ($result.exit_code)\n" | save -a $logfile
			$"Stdout: ($result.stdout)\n" | save -a $logfile
			$"Stderr: ($result.stderr)\n" | save -a $logfile

			if ($result.exit_code != 0) {
				print $"  (ansi red)Error:(ansi reset) not a git repository or git clean failed"
			} else if ($result.stdout | str trim | is-empty) {
				print $"  (ansi yellow)Nothing to remove(ansi reset)"
			} else {
				for line in ($result.stdout | lines) {
					print $"  (ansi green)Removed:(ansi reset) ($line)"
				}
			}
			$"Done with ($dir)\n" | save -a $logfile
		}
        $"Purge completed\n" | save -a $logfile
    }
}

def get-dir-size [] {
    ^du -sh $in
    | parse "{size}\t{name}"
    | str trim
    | upsert size {|r| $r.size | into filesize }
}

def dirs [] {
    [
        ~/dev/vendor
        ~/dev/learn
        ~/dev/projects
        ~/work/services
        ~/work/lambdas
        ~/work/utilities
        ~/work/infrastructure
        ~/work/libraries
        ~/work/docs
    ]
}
