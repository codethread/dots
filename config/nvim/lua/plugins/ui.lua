if vim.g.vscode then return {} end

local theme = require 'codethread.theme'

return {
	-- Keeping these around if moving to a termainl without builtin smear
	-- { 'DanilaMihailov/beacon.nvim' },
	-- { 'sphamba/smear-cursor.nvim', opts = {}, },

	{ 'norcalli/nvim-colorizer.lua', cmd = 'ColorizerToggle' },

	{ 'nvim-tree/nvim-web-devicons', opts = {}, cmd = 'NvimWebDeviconsHiTest' },
	-- TODO: i actually prefer mini.icons but telescrope needs devicons, so migrate at some point
	-- { 'nvim-mini/mini.icons', opts = {} },

	{
		'folke/tokyonight.nvim',
		enabled = theme.family() == 'tokyonight',
		priority = 1000,
		lazy = false,
		config = function()
			require('tokyonight').setup(require('codethread.theme').tokyonight_opts())
			vim.cmd 'colorscheme tokyonight'
		end,
	},

	{
		'rose-pine/neovim',
		name = 'rose-pine',
		enabled = theme.family() == 'rose-pine',
		priority = 1000,
		lazy = false,
		config = function(_, opts)
			require('rose-pine').setup(
				vim.tbl_deep_extend('force', opts or {}, require('codethread.theme').rose_pine_opts())
			)
			vim.cmd 'colorscheme rose-pine'
		end,
	},

	{ -- just keep around for pairing
		'nvim-neo-tree/neo-tree.nvim',
		branch = 'v3.x',
		dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
		cmd = 'Neotree',
		opts = { window = { mappings = { ['Z'] = 'expand_all_nodes' } } },
	},
}
