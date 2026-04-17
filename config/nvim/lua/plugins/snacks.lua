---@diagnostic disable: missing-fields

return {
	'folke/snacks.nvim',
	priority = 1000,
	lazy = false,
	init = function() vim.g.snacks_animate = false end,
	--[[stylua: ignore]] --format
	keys = {
	-- { '<leader>.', function() Snacks.scratch() end       , desc = 'Toggle Scratch Buffer' },
	{ '<leader>S', function() Snacks.scratch.select() end, desc = 'Select Scratch Buffer' },
	},
	---@type snacks.Config
	opts = vim.g.vscode
			and {
				bigfile = { enabled = false },
				dashboard = { enabled = false },
				indent = { enabled = false },
				input = { enabled = false },
				notifier = { enabled = false },
				picker = { enabled = false },
				quickfile = { enabled = false },
				scroll = { enabled = false },
				statuscolumn = { enabled = false },
			} ---@type snacks.Config
		or {
			---@type table<string, snacks.win.Config>
			styles = {

				dashboard = { wo = {
					statusline = '',
				} },
				input = {
					border = 'solid',
				},
			},
			bigfile = { enabled = true },
			quickfile = {},
			gitbrowse = {},
			notifier = {
				-- NOTE: from 'rcarriga/nvim-notify',
				-- silence annoying errors from lsp's that have no hover information
				-- source https://github.com/neovim/nvim-lspconfig/issues/1931#issuecomment-1297599534
				-- local banned_messages = {
				-- 	'No information available',
				-- 	'warning: multiple different client offset_encodings detected for buffer, this is not supported yet',
				-- }
			},
			---@type snacks.dashboard.Config
			dashboard = { enabled = true },
			---@type snacks.input.Config
			input = {},
			---@class snacks.indent.Config
			indent = {
				enabled = true,
				indent = {
					char = '┊',
				},
				chunk = {
					enabled = true,
					char = {},
				},
			},
		},
}
