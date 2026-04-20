if vim.g.vscode then return {} end

return {
	{ 'xorid/swap-split.nvim', cmd = 'SwapSplit' },

	{ 'shortcuts/no-neck-pain.nvim', cmd = { 'NoNeckPain' } },

	{ 'declancm/maximize.nvim', opts = {}, cmd = { 'Maximize' } },

	{
		'mrjones2014/smart-splits.nvim',
		lazy = false,
		build = './kitty/install-kittens.bash',
		init = function()
			do -- handle kitty keybinding passthrough
				local function on_init() io.stdout:write '\x1b]1337;SetUserVar=IS_NVIM=MQo\007' end
				local function on_exit() io.stdout:write '\x1b]1337;SetUserVar=IS_NVIM\007' end

				on_init()
				vim.api.nvim_create_autocmd('VimResume', { callback = on_init })
				vim.api.nvim_create_autocmd({ 'VimSuspend', 'VimLeavePre' }, { callback = on_exit })
			end
		end,
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
			multiplexer_integration = 'kitty',
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
