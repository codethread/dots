# :module: File listing utility with git ignore awareness and custom excludes

# glob all files at a given `path`, allowing for additional excludes. Results
# are returned as relative paths
export def main [path, --excludes = [], --fresh]: nothing -> list<string> {
	if $fresh {
		let files = git ls-files | lines | where { $in | is-not-empty }
		if ($excludes | is-empty) {
			$files | sort
		} else {
			let excluded = $excludes
				| each { |pat| try { glob $pat --no-dir } catch { [] } }
				| flatten
				| path relative-to $env.PWD
			$files | where { $in not-in $excluded } | sort
		}
	} else {
		glob **/* --no-dir --exclude ([**/target/** **/.git/**] ++ $excludes)
		| path relative-to $env.PWD
		| list-not-ignored
	}
}

def list-not-ignored []: list<string> -> list<string> {
	let files = $in
	let result = $files | to text | git check-ignore --stdin | complete
	if $result.exit_code > 1 {
		error make { msg: $"git check-ignore failed: ($result.stderr)" }
	}
	let ignored = $result.stdout | lines

	$files | where { $in not-in $ignored } | sort
}
