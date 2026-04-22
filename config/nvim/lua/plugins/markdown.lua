if vim.g.vscode then return {} end

return U.F {
	{
		'mzlogin/vim-markdown-toc',
		init = function() vim.cmd [[let g:vmt_auto_update_on_save = 0]] end,
		lazy = false,
		cmd = { 'GenTocGFM', 'GenTocGitLab', 'UpdateToc' },
	},

	{
		'codethread/peek.nvim',
		branch = 'mermaids',
		build = 'deno task --quiet build:fast',
		opts = {
			app = os.getenv 'IS_NIXOS' == 'true' and 'ssh' or 'webview',
			theme = require('codethread.theme').mode(),
		},
		init = function()
			vim.api.nvim_create_user_command('PeekOpen', function() require('peek').open() end, {})
			vim.api.nvim_create_user_command('PeekClose', function() require('peek').close() end, {})
		end,
	},

	{
		'MeanderingProgrammer/render-markdown.nvim',
		enabled = false,
		-- also 'OXY2DEV/markview.nvim',
		ft = 'markdown',
		---@module 'render-markdown'
		---@type render.md.UserConfig
		opts = {
			completions = { lsp = { enabled = true } },
		},
	},
}
