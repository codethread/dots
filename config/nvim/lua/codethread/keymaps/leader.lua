local fns = require 'codethread.fns'
-- TIPS
-- to see raw key
-- go to insert mode, type <C-v> then type, and that key will be shown

Keys.tbl('<leader>', {
	['<leader>'] = { 'Files', Cmd 'Telescope find_files' },
	[';'] = { 'M-x', Cmd 'Telescope commands' },
	[':'] = { 'M-x [hist]', Cmd 'Telescope command_history' },
	-- ['/'] = { '/ [hist]', Cmd 'Telescope search_history' },
	['/'] = { 'Claude', function() require('codethread.claude').claude_query() end },
	[','] = { '🔭 Resume', Cmd 'Telescope resume' },

	e = {
		group = 'Errors',
		h = { 'Hover', function() vim.diagnostic.open_float() end },
		l = { 'Document Diagnostics', Cmd 'Telescope diagnostics theme=ivy bufnr=0' },
		L = { 'Workspace Diagnostics', Cmd 'Telescope diagnostics' },
		n = { 'Next Diagnostic', function() require('codethread.diagnostics').next_diagnostic() end },
		p = {
			'Previous Diagnostic',
			function() require('codethread.diagnostics').previous_diagnostic() end,
		},
		t = { 'Toggle Diagnostics', Cmd 'DiagnosticToggle' },
		q = { 'Quickfix', Cmd 'lua vim.diagnostic.setloclist()' },
	},

	f = {
		group = 'Buffer',
		b = { 'Toggle', [[<C-^>]] },
		l = { 'list', Cmd 'Telescope buffers' },
		r = { 'recent', Cmd 'Telescope oldfiles' },
		R = { 'reload', Cmd 'e!' },
		k = { 'kill', function() require('mini.bufremove').delete() end },
		s = { 'Save', fns.save_buffer },
		u = { 'Unsaved', function() require('plugins.telescope.pickers').unsaved() end },
		O = { 'Delete Others', function() Snacks.bufdelete.other {} end },
	},

	F = {
		group = 'Split',
		F = { 'auto', function() require('codethread.split').split() end },
		h = { 'Left', function() require('codethread.split').split 'left' end },
		j = { 'Down', function() require('codethread.split').split 'down' end },
		k = { 'Up', function() require('codethread.split').split 'up' end },
		t = { 'Tab', function() require('codethread.split').split 'tab' end },
	},

	g = {
		group = 'Git',
		R = { 'Reset Buffer', fns.git_reset_buffer },
		b = { 'Checkout branch', Cmd 'Telescope git_branches' },
		c = { 'Checkout commit', Cmd 'Telescope git_commits' },
		d = { 'Diff', function() require('gitsigns').diffthis() end },
		g = { 'Status', function() require('neogit').open {} end },
		j = { 'Next Hunk', function() require('gitsigns').nav_hunk('next', { preview = true }) end },
		k = { 'Prev Hunk', function() require('gitsigns').nav_hunk('prev', { preview = true }) end },
		h = { 'File History', fns.toggle_file_history },
		l = { 'Blame', function() require('gitsigns').blame_line() end },
		o = { 'Open changed file', Cmd 'Telescope git_status' },
		p = { 'Preview Hunk', function() require('gitsigns').preview_hunk() end },
		r = { 'Reset Hunk', function() require('gitsigns').reset_hunk() end },
		s = { '(un)Stage Hunk', function() require('gitsigns').stage_hunk() end },
		v = { 'Ghub view', Snacks.gitbrowse.open },

		w = {
			group = 'Worktree',
			a = { 'Split buffer', fns.worktree_open_alt },
		},
	},
	G = {
		group = 'Global',
		L = { 'Lazy', Cmd 'Lazy' },
		M = { 'Mason', Cmd 'Mason' },
		m = { 'messages', Cmd 'Bufferize messages' },
	},
	h = {
		group = 'Help',
		h = { 'Help', Cmd 'Telescope help_tags' },
		H = { 'Help Grep', Cmd 'Telescope helpgrep' }, -- TODO: steal code and use my own grepper
		m = { 'Man pages', Cmd 'Telescope man_pages' },
		v = { 'Settings', Cmd 'Telescope vim_options' },
		t = { 'Telescope', Cmd 'Telescope builtin' },
		c = { 'Telescope', Cmd 'Telescope highlights' },
	},
	j = { 'file', fns.test_current_file },
	-- NOTE: this is a terrible keymap
	k = { '🐉 Folds', function() require('codethread.fold').fold_hyrda:activate() end },
	l = {
		group = 'Lsp',
		a = { 'Code Action', Cmd 'lua vim.lsp.buf.code_action()' },
		c = { 'CodeLens Action', Cmd 'lua vim.lsp.codelens.run()' },
		d = { 'Declaration', Cmd 'lua vim.lsp.buf.declaration({ reuse_win = true })' },
		i = { 'Info', Cmd 'LspInfo' },
		l = { 'Workspace Symbols', Cmd 'Telescope lsp_dynamic_workspace_symbols' },
		r = { 'Rename', Cmd 'lua vim.lsp.buf.rename()' },
		s = { 'Document Symbols', Cmd 'Telescope aerial' },
		I = { 'Installer Info', Cmd 'LspInstallInfo' },
	},
	---
	m = { '🐉 Mover', function() require('codethread.movement').mover_hydra:activate() end },
	w = {
		group = 'Window',
		N = { 'New Tab', Cmd 'tabnew' },
		k = { 'Close', Cmd 'close' },
		l = { 'List Tabs', function() require('telescope-tabs').list_tabs() end }, -- TODO: put through telescope
		n = { 'Next Tab', Cmd 'tabNext' }, -- TODO: put through telescope
		p = { 'Previous Tab', Cmd 'tabprevious' }, -- TODO: put through telescope
		w = { 'Split', Cmd 'vsplit' }, -- TODO: put through telescope
		s = { 'Swap', Cmd 'SwapSplit' },
		e = { '🐉 Tabs', function() require('codethread.movement').tab_hydra:activate() end },
	},
	s = {
		group = 'Search',
		b = { 'Checkout branch', Cmd 'Telescope git_branches' },
		c = { 'Colorscheme', Cmd 'Telescope colorscheme' },
		f = { 'Buffer', Cmd 'Telescope current_buffer_fuzzy_find mirror=true' },
		F = {
			'Buffers',
			function() require('telescope.builtin').live_grep { grep_open_files = true } end,
		},
		r = { 'Open Recent File', Cmd 'Telescope oldfiles' },
		R = { 'Registers', Cmd 'Telescope registers' },
		k = { 'Keymaps', Cmd 'Telescope keymaps' },
		m = { 'Multi-grep', function() require('plugins.telescope.pickers').multi_grep {} end },
		C = { 'Commands', Cmd 'Telescope commands' },
		-- p ={ Cmd 'Telescope live_grep_args', 'Live Grep' },
		p = { 'Live Grep', function() require('plugins.telescope.pickers.rg').live_grepper {} end },
		-- TODO fix for being in a nested dir
		w = {
			'Word',
			function()
				require('telescope-live-grep-args.shortcuts').grep_word_under_cursor {
					cwd = vim.fs.root(0, '.git'),
				}
			end,
		},
		l = { 'Symbol', Cmd 'Telescope lsp_document_symbols' },
		L = { 'Global Symbols', ':Telescope lsp_workspace_symbols query=' },
		-- s = { 'Spectre', Cmd 'Spectre' },
		s = { 'Find/Replace', function() require('grug-far').open() end },
		t = { 'Todos', Cmd 'TodoTelescope keywords=TODO,FIX,XXX,HACK' },
		y = { 'Clipboard', Cmd 'Telescope neoclip' },
	},
	o = {
		group = 'Open',
		a = { 'Aerial', Cmd 'AerialToggle! left' },
		-- if you can't beat 'em
		-- c = { 'Gui', Cmd 'silent !code %' },
		-- c = { 'Gui', Cmd 'silent !cursor %' },
		d = { 'Dir', Cmd 'Oil' },
		f = { 'Open finder', function() vim.ui.open(vim.fn.expand '%:p:h') end },
		g = { 'git remote', function() Snacks.gitbrowse.open() end },
		l = { 'open log file', function() require('codethread.logger').select() end },
		n = { 'Notifcation History', Cmd 'LogOpen notifications' },
		N = { 'Hide Notifications', function() Snacks.notifier.hide() end },
		m = { 'markdown', Cmd 'PeekOpen' },
		o = {
			'Notes',
			function()
				Snacks.scratch.open { ft = 'markdown', template = '# Notes', win = { position = 'right' } }
			end,
		},
		S = { 'Sessions', function() require('persistence').select() end },
	},
	t = {
		group = 'Toggle',
		i = { 'Inlay Hints', Snacks.toggle.indent },
		-- i = { 'Inlay Hints', Cmd "lua print'nothing setup'" },
		m = { 'Markdown Preview', Cmd 'Markview Toggle' },
		[' '] = { 'Whitespace', fns.toggle_listchars },
		l = { 'Linewrap', fns.toggle_linewrap },
	},

	d = {
		group = 'Debug',
		b = { 'Toggle Breakpoint', function() require('dap').toggle_breakpoint() end },
		B = {
			'Conditional Breakpoint',
			function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
		},
		c = { 'Continue', function() require('dap').continue() end },
		e = { 'Eval', function() require('dapui').eval() end, mode = { 'n', 'v' } },
		l = { 'Run Last', function() require('dap').run_last() end },
		r = { 'Open REPL', function() require('dap').repl.open() end },
		t = { 'Terminate', function() require('dap').terminate() end },
		u = { 'Toggle UI', function() require('dapui').toggle() end },
	},

	u = {
		group = 'Utils',
		f = { 'format buffer', "mbggVG=='b" },
		s = { 'autocorrect', '1z=' },
		b = { 'Box', function() require('codethread.box').box() end },
		r = { 'reload snippets', fns.reload_snippets },
		j = { 'json format', Cmd '%!jq .' },
	},
	y = {
		group = 'Yank',
		a = { 'path [absolute]', fns.yank_absolute_path },
		y = { 'path [project_root]', fns.yank_current_file },
		l = { 'last', fns.save_register_to_clipboard },
		r = { 'path [home_root]', fns.yank_home_relative_path },
		g = { 'path [gitlab]', fns.yank_gitlab_url },
		s = { 'Search', Cmd 'Telescope neoclip' },
	},
})

return {
	W = { Cmd 'Maximize', 'Window Maximise' },

	n = {
		name = 'notes',
		n = { Cmd 'vsplit brain.md', 'open' },
		-- a = {
		-- 	name = 'add',
		-- 	a = { Cmd 'ObsidianNew', 'New' },
		-- 	t = { function() require('plugins.notes.fns').create_markdown_toc() end, 'ToC' },
		-- },
		-- b = { Cmd 'ObsidianBacklinks', 'Backlinks' },
		-- i = { Cmd 'ObsidianTemplate', 'Template' },
		-- l = { Cmd 'ObsidianLinks', 'Links' },
		-- n = { Cmd 'ObsidianQuickSwitch', 'Find' },
		-- o = {
		-- 	name = 'open',
		-- 	o = { Cmd 'ObsidianOpen', 'Obsidian' },
		-- 	t = { Cmd 'ObsidianToday', 'Today' },
		-- 	h = { function() require('plugins.notes.fns').notes_path_to '!home.md' end, 'Home' },
		-- 	p = {
		-- 		function() require('plugins.notes.fns').notes_path_to '!projects.md' end,
		-- 		'Projects',
		-- 	},
		-- 	q = { function() require('plugins.notes.fns').notes_path_to 'dump.md' end, 'Dump' },
		-- },
		-- q = {
		-- 	--- TODO: make this more like an input simpilar to emacs
		-- 	function() require('plugins.notes.fns').notes_path_to 'dump.md' end,
		-- 	'quick capture',
		-- },
		-- r = { function() require('plugins.notes.fns').rename() end, 'Rename' },
		-- s = { Cmd 'ObsidianSearch', 'Search' },
		-- t = { Cmd 'ObsidianTags', 'Tags' },
	},

	t = {
		name = 'Terminal',
		n = { Cmd 'lua _NODE_TOGGLE()', 'Node' },
		t = { Cmd 'ToggleTerm direction=float', 'Float' },
		h = { Cmd 'ToggleTerm size=10 direction=horizontal', 'Horizontal' },
		v = { Cmd 'ToggleTerm size=80 direction=vertical', 'Vertical' },
	},
}
