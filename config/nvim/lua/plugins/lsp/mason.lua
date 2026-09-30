return {
	{
		'williamboman/mason.nvim',
		cmd = 'Mason',
		opts = {
			ui = {
				icons = {
					package_installed = '✓',
					package_pending = '➜',
					package_uninstalled = '✗',
				},
			},
		},
		config = function(_, opts)
			require('mason').setup(opts)
			local registry = require 'mason-registry'

			-- Notify on installation events
			registry:on(
				'package:handle',
				vim.schedule_wrap(
					function(pkg, _)
						vim.notify(string.format('Installing %s', pkg.name), 'info', {
							title = 'Mason',
							timeout = 1500,
						})
					end
				)
			)

			registry:on(
				'package:install:success',
				vim.schedule_wrap(
					function(pkg, _)
						vim.notify(string.format('Successfully installed %s', pkg.name), 'info', {
							title = 'Mason',
							timeout = 1500,
						})
					end
				)
			)
		end,
	},

	{
		'WhoIsSethDaniel/mason-tool-installer.nvim',
		dependencies = { 'williamboman/mason.nvim' },
		event = { 'BufReadPre', 'BufNewFile' },
		opts = {
			ensure_installed = {
				-- LSP servers managed by mason-lspconfig are defined in lspconfig.lua
				-- Add formatters, linters, and other tools here
				'stylua', -- Lua formatter (if you use it)
			},
			auto_update = false, -- Don't auto-update on startup (can be slow)
			run_on_start = true, -- Install missing tools on startup
			start_delay = 3000, -- Delay before starting installation (ms)
			debounce_hours = 24, -- Only check for updates once per day
		},
		config = function(_, opts)
			require('mason-tool-installer').setup(opts)

			-- Verify installations completed successfully
			vim.api.nvim_create_autocmd('User', {
				pattern = 'MasonToolsUpdateCompleted',
				callback = function()
					-- Optional: verify critical tools are installed
					local vtsls_installed = vim.fn.executable('vtsls') == 1
					if not vtsls_installed then
						vim.notify(
							'vtsls installation may have failed. Check :Mason',
							vim.log.levels.WARN,
							{ title = 'Mason' }
						)
					end
				end,
			})
		end,
	},
}
