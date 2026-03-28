return {
	{
		'stevearc/oil.nvim',
		lazy = false,
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
		dependencies = { 'nvim-tree/nvim-web-devicons' },
	},

	{
		'nvim-tree/nvim-web-devicons',
		opts = {},
		lazy = true,
	},

	{
		'nvim-treesitter/nvim-treesitter',
		build = ':TSUpdate',
		event = { 'BufReadPost', 'BufNewFile' },
		config = function()
			-- nvim-treesitter.configs was removed in newer versions;
			-- use vim.treesitter directly for highlight/indent
			local ok, configs = pcall(require, 'nvim-treesitter.configs')
			if ok then
				configs.setup {
					ensure_installed = {
						'bash', 'lua', 'javascript', 'typescript', 'json', 'yaml',
						'markdown', 'markdown_inline', 'python', 'toml', 'vim', 'vimdoc',
						'html', 'css', 'nix', 'diff', 'git_rebase', 'gitcommit',
					},
					highlight = { enable = true },
					indent = { enable = true },
				}
			end
		end,
	},

	{
		'nvim-telescope/telescope.nvim',
		cmd = 'Telescope',
		dependencies = { 'nvim-lua/plenary.nvim' },
		opts = {
			defaults = {
				layout_strategy = 'flex',
				sorting_strategy = 'ascending',
				layout_config = {
					prompt_position = 'top',
				},
			},
		},
	},

	{ 'nvim-lua/plenary.nvim', lazy = true },

	{
		'folke/which-key.nvim',
		event = 'VeryLazy',
		opts = {},
	},

	-- surround text objects
	{
		'kylechui/nvim-surround',
		event = { 'BufReadPost', 'BufNewFile' },
		opts = {},
	},

	-- readline keybindings in insert/command mode
	{ 'tpope/vim-rsi', event = 'InsertEnter' },

	-- case coercion (crs, crm, crc, etc.)
	{ 'tpope/vim-abolish', event = { 'BufReadPost', 'BufNewFile' } },
}
