return {
	notes_path = vim.env.CT_NOTES or (vim.fn.has('mac') == 1
		and os.getenv('HOME') .. '/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes'
		or os.getenv('HOME') .. '/notes'),
}
