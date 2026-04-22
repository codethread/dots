if vim.g.vscode then return {} end

return {
	{
		'NeogitOrg/neogit',
		lazy = true,
		dependencies = { 'dlyongemallo/diffview.nvim' },
		init = function()
			vim.api.nvim_create_autocmd('User', {
				pattern = 'NeogitPushComplete',
				group = vim.api.nvim_create_augroup('MyCustomNeogitEvents', { clear = true }),
				callback = function() require('neogit').close() end,
			})
		end,
		---@class NeogitConfig
		opts = {
			disable_commit_confirmation = true,
			integrations = {
				telescope = true,
				diffview = true,
			},
			graph_style = 'unicode',
			console_timeout = U.machine {
				home = 2000,
				work = 5000,
			},
		},
	},
	{
		'dlyongemallo/diffview.nvim',
		lazy = false,
		cmd = {
			'DiffviewFileHistory',
			'DiffviewOpen',
		},
		opts = {
			view = {
				default = {
					-- Config for changed files, and staged files in diff views.
					layout = 'diff2_horizontal',
				},
				merge_tool = {
					-- Config for conflicted files in diff views during a merge or rebase.
					layout = 'diff3_horizontal',
					disable_diagnostics = true, -- Temporarily disable diagnostics for conflict buffers while in the view.
				},
				file_history = {
					-- Config for changed files in file history views.
					layout = 'diff2_horizontal',
				},
			},
		},
	},
	{
		'lewis6991/gitsigns.nvim',
		event = { 'BufReadPre', 'BufNewFile' },
		opts = {},
	},
}
