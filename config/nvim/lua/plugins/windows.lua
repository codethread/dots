if vim.g.vscode then return {} end

return {
	{ 'xorid/swap-split.nvim', cmd = 'SwapSplit' },

	{ 'shortcuts/no-neck-pain.nvim', cmd = { 'NoNeckPain' } },

	{ 'declancm/maximize.nvim', opts = {}, cmd = { 'Maximize' } },

	{
		'mrjones2014/smart-splits.nvim',
		lazy = false,
		-- these keymaps will also accept a range,
		-- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
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
			{ '<C-\\>', function() require('smart-splits').move_cursor_previous() end },
		},
		opts = {
			log_level = 'warn',
			multiplexer_integration = 'tmux',
			-- Ignored buffer types (only while resizing)
			ignored_buftypes = {
				'nofile',
				'quickfix',
				'prompt',
			},
			-- Ignored filetypes (only while resizing)
			ignored_filetypes = { 'NvimTree' },
			-- disable_multiplexer_nav_when_zoomed = true,
		},
	},
}
