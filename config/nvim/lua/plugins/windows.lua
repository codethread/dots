if vim.g.vscode then return {} end

return {
	{ 'xorid/swap-split.nvim', cmd = 'SwapSplit' },

	{ 'shortcuts/no-neck-pain.nvim', cmd = { 'NoNeckPain' } },

	{ 'declancm/maximize.nvim', opts = {}, cmd = { 'Maximize' } },

	{
		'smart-splits-nvim/smart-splits.nvim',
		version = '^3.0.0',
		lazy = false,
		dependencies = {
			{ 'smart-splits-nvim/backend-tmux', main = 'smart-splits-backend-tmux', opts = {} },
			{ 'rawnly/smart-splits-backend-rex', opts = {} },
		},
		-- these keymaps will also accept a range,
		-- for example `10<A-h>` will `resize_left` by `(10 * config.resize.amount)`
		--[[stylua: ignore]] --format
		keys = {
			{ '<A-h>', function() require('smart-splits').resize_left() end },
			{ '<A-j>', function() require('smart-splits').resize_down() end },
			{ '<A-k>', function() require('smart-splits').resize_up() end },
			{ '<A-l>', function() require('smart-splits').resize_right() end },

			{ '<C-h>', function() require('smart-splits').move_cursor_left() end },
			{ '<C-j>', function() require('smart-splits').move_cursor_down() end },
			{ '<C-k>', function() require('smart-splits').move_cursor_up() end },
			{ '<C-l>', function() require('smart-splits').move_cursor_right() end },
			{ '<C-\\>', '<C-w>p', desc = 'Previous Neovim window' },
		},
		opts = {
			log = { level = 'warn' },
			mux = {
				backend = function()
					return { require 'smart-splits-backend-tmux', require 'codethread.rex' }
				end,
			},
			-- Ignore utility windows during navigation and resizing.
			ignored_buftypes = {
				'nofile',
				'quickfix',
				'prompt',
			},
			ignored_filetypes = { 'NvimTree' },
		},
	},
}
