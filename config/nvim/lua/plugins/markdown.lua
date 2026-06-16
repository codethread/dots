if vim.g.vscode then return {} end

local is_ssh = (vim.env.SSH_CONNECTION or vim.env.SSH_CLIENT or vim.env.SSH_TTY) ~= nil

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
			app = is_ssh and 'ssh' or 'webview',
			theme = require('codethread.theme').mode(),
		},
		init = function()
			local peek_apps = { 'webview', 'browser', 'ssh' }

			vim.api.nvim_create_user_command('PeekOpen', function(args)
				local app = args.args ~= '' and args.args or nil
				require('peek').open(app and { app = app } or nil)
			end, {
				nargs = '?',
				complete = function(arg_lead)
					return vim.tbl_filter(function(app) return vim.startswith(app, arg_lead) end, peek_apps)
				end,
			})
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
