if vim.g.vscode then return {} end

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
		priority = 1000,
		lazy = false,
		config = function()
			require('tokyonight').setup(require('codethread.theme').tokyonight_opts())
			vim.cmd 'colorscheme tokyonight'
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
