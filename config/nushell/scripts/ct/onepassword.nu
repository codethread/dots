# 1Password CLI utilities

export alias op-goog-token-info = op item get "cli google token"
export alias op-goog-token = op read op://perkbox/s46wd4f6paab7ao5cghok3pyy4/credential

export alias op-p-auth-info = op item get "perkbox auth header"
export alias op-p-auth-get = op read op://perkbox/jtipu4uwq4psxptikwmd7xxt3u/credential
export alias op-p-auth-set = op item edit jtipu4uwq4psxptikwmd7xxt3u $'credential=(pbpaste)'

export alias op-goog-auth-info = op item get "Perkbox Gmail"
export alias op-goog-auth = op read op://perkbox/4ajg7mmj6j23yvkq6kfai52pru/password

# get slack credentials
export def slacky [] {
	let target = "~/.local/share/slacky" | path expand
	mkdir $target
	let p = op-goog-auth
	hide-all {
		(deno run
			--allow-env
			--allow-read
			--allow-write=/var/folders
			--allow-net=127.0.0.1
			--allow-run="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
			($env.DOTFILES | path join "_scripts/getSlackCreds.ts")
			--email adam.hall@perkbox.com
			--password $p
			--domain https://perkbox.slack.com)
	} | from json
	| save ([$target slack.json] | path join)
}