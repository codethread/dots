local treesitter_parsers = {
	'bash', 'lua', 'javascript', 'typescript', 'json', 'yaml',
	'markdown', 'markdown_inline', 'python', 'toml', 'vim', 'vimdoc',
	'html', 'css', 'nix', 'diff', 'git_rebase', 'gitcommit',
}

return {
	{
		'stevearc/oil.nvim',
		-- Oil recommends eager loading so directory buffers work as the default explorer.
		lazy = false,
		keys = {
			{ '<leader>od', '<cmd>Oil<cr>', desc = 'Dir (oil)' },
		},
		opts = {
			default_file_explorer = true,
			view_options = { show_hidden = true },
			columns = { 'icon' },
			skip_confirm_for_simple_edits = true,
			use_default_keymaps = true,
			keymaps = {
				['<C-s>'] = false,
				['<C-h>'] = false,
				['<C-t>'] = false,
				['<TAB>'] = 'actions.preview',
				['<C-c>'] = false,
				['<C-l>'] = false,
				['<left>'] = 'actions.parent',
				['<right>'] = 'actions.select',
				['_'] = false,
				['`'] = false,
				['~'] = 'actions.open_cwd',
				['g.'] = 'actions.toggle_hidden',
				['!'] = 'actions.open_cmdline',
			},
		},
		dependencies = {
			{ 'nvim-mini/mini.icons', opts = {} },
		},
	},

	-- nvim-treesitter explicitly does not support lazy-loading.
	{
		'nvim-treesitter/nvim-treesitter',
		lazy = false,
		build = function()
			local treesitter = require 'nvim-treesitter'
			treesitter.update():wait(300000)
			treesitter.install(treesitter_parsers):wait(300000)
		end,
		config = function()
			vim.api.nvim_create_autocmd('FileType', {
				pattern = {
					'bash', 'sh', 'lua', 'javascript', 'typescript', 'json', 'yaml',
					'markdown', 'python', 'toml', 'vim', 'help', 'html', 'css', 'nix',
					'diff', 'gitrebase', 'gitcommit',
				},
				callback = function() vim.treesitter.start() end,
			})
		end,
	},

	{
		'folke/which-key.nvim',
		event = 'VeryLazy',
		opts = {},
	},

	{
		'kylechui/nvim-surround',
		keys = { 'ys', 'yss', 'yS', 'ySS', 'ds', 'cs', { 'S', mode = 'x' } },
		opts = {},
	},

	{ 'tpope/vim-rsi', event = { 'InsertEnter', 'CmdlineEnter' } },
	{
		'tpope/vim-abolish',
		cmd = { 'Abolish', 'Subvert' },
		keys = { 'cr' },
	},
}
