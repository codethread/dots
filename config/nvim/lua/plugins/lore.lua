return U.F {
	{ 'farmergreg/vim-lastplace' },
	{ 'anuvyklack/hydra.nvim' },

	{ 'echasnovski/mini.bufremove', cond = not vim.g.vscode },

	{
		'mbbill/undotree',
		event = U.LazyFile,
		init = function()
			vim.cmd [[
				" add undo break points on key stroke to make undo more granular
				inoremap , ,<c-g>u
				inoremap . .<c-g>u
				inoremap ( (<c-g>u
				inoremap { {<c-g>u
				]]

			vim.keymap.set('n', 'U', Cmd 'UndotreeToggle', {})
			vim.opt.swapfile = false
			vim.opt.backup = false
			vim.opt.writebackup = false -- This is recommended by coc

			vim.cmd [[
			if has("persistent_undo")
			let target_path = expand('~/.local/share/nvim/undodir')

			" create the directory and any parent directories
			" if the location does not exist.
			if !isdirectory(target_path)
			call mkdir(target_path, "p", 0700)
			endif

			let &undodir=target_path
			set undofile
			endif
			]]
		end,
	},

	{
		'wakatime/vim-wakatime',
		cond = os.getenv 'WAKATIME_HOME' ~= nil and not vim.g.vscode,
		event = U.LazyFile,
	},

	{ 'AndrewRadev/bufferize.vim', cmd = 'Bufferize' },

	{
		-- store clipboard for easy recall
		'AckslD/nvim-neoclip.lua',
		event = 'TextYankPost',
		config = function()
			require('neoclip').setup()
			if vim.g.vscode then
				vim.api.nvim_create_user_command('Yanks', function()
					local _storage = require('neoclip.storage').get().yanks
					vim.ui.select(_storage, {
						prompt = 'hey',
						format_item = function(item) return table.concat(item.contents, '\\n') end,
					}, function(choice) vim.print(choice) end)
				end, {})
			else
				require('telescope').load_extension 'neoclip'
			end
		end,
	},

	{
		'MagicDuck/grug-far.nvim',
		cond = not vim.g.vscode,
		cmd = { 'GrugFar' },
		opts = {},
	},

	{
		'folke/which-key.nvim',
		lazy = false,
		priority = 100,
		opts = {
			plugins = {
				-- presets = {
				-- 	operators = false,
				-- 	motions = false,
				-- 	text_objects = false,
				-- },
			},
			icons = {
				mappings = false, -- turns of icons
			},
			sort = { 'order' },
			expand = 1,
		},
	},

	-- Lua
	{
		'folke/persistence.nvim',
		cond = not vim.g.vscode,
		event = 'BufReadPre', -- this will only start session saving when an actual file was opened
		opts = {
			branch = false,
		},
	},

	{
		'chrishrb/gx.nvim',
		dependencies = { 'nvim-lua/plenary.nvim' }, -- Required for Neovim < 0.10.0
		keys = { { 'gx', '<cmd>Browse<cr>', mode = { 'n', 'x' } } },
		cmd = { 'Browse' },
		init = function()
			vim.g.netrw_nogx = 1 -- disable netrw gx
		end,
		opts = {},
	},
}
