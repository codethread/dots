if vim.g.vscode then return {} end

return U.flatten {
	require 'plugins.lang.go',
	-- require 'plugins.lang.typescript',
	-- require 'plugins.lang.typescript-tools',
	-- require 'plugins.lang.typescript-tools',
	require 'plugins.lang.rust',
	require 'plugins.lang.ts',

	{
		-- https://github.com/nushell/tree-sitter-nu/blob/main/installation/neovim.md
		-- {
		-- 	'LhKipp/nvim-nu',
		-- 	ft = 'nu',
		-- 	init = function()
		-- 		-- TODO after ts
		-- 		local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
		--
		-- 		parser_config.nu = {
		-- 			install_info = {
		-- 				url = 'https://github.com/nushell/tree-sitter-nu',
		-- 				files = { 'src/parser.c' },
		-- 				branch = 'main',
		-- 			},
		-- 			filetype = 'nu',
		-- 		}
		-- 	end,
		-- 	-- run = ':TSInstall nu',
		-- 	opts = {
		-- 		complete_cmd_names = true,
		-- 	},
		-- },

		-- help for lua, TODO need to make this work
		-- U.tools_null { 'stylua', 'luacheck' },
		-- use 'wsdjeg/luarefvim'
		-- use 'rafcamlet/nvim-luapad'
		{ 'milisims/nvim-luaref' },

		{ 'PaterJason/cmp-conjure' },
		-- (l(i(s(p))))
		{
			'Olical/conjure',
			ft = {
				'clojure',
				'fennel',
				'janet',
				'hy',
				'julia',
				'racket',
				'scheme',
				'lisp',
			},
			init = function()
				vim.g['conjure#mapping#doc_word'] = false
				vim.g['conjure#extract#tree_sitter#enabled'] = true
				-- vim.g['conjure#mapping#doc_word'] = { 'K' }
				vim.cmd [[
				  "" lua require('plugins.lang.nushell')
				  " rust and lua removed
				  "" let g:conjure#filetypes = [ 'clojure', 'fennel', 'janet', 'hy', 'julia', 'racket', 'scheme', 'lisp', "nu" ]
				  let g:conjure#filetypes = [ 'clojure', 'fennel', 'janet', 'hy', 'julia', 'racket', 'scheme', 'lisp' ]
				  let g:conjure#filetype#rust = v:false
				  " let g:conjure#filetype#nu = 'plugins.lang.nushell'

				  ]]
			end,
			config = function(_, opts)
				require('conjure.main').main()
				require('conjure.mapping')['on-filetype']()
			end,
		},

		-- {
		-- 	dir = U.machine {
		-- 		work = '~/dev/projects/skein/integrations/neovim',
		-- 		home = '~/dev/projects/skein-src/integrations/neovim',
		-- 	},
		-- 	name = 'skein.nvim',
		-- 	dependencies = { 'Olical/conjure' },
		-- 	ft = { 'clojure' },
		-- 	cmd = { 'SkeinConnect' },
		-- },

		{
			'gpanders/nvim-parinfer',
			cmd = 'ParinferOn',
			init = function()
				vim.api.nvim_create_autocmd('FileType', {
					pattern = { 'clojure', 'query' },
					group = vim.api.nvim_create_augroup('Parinfer', {}),
					callback = function()
						vim.bo[0].formatexpr = 'ParinferGetExpr()'
						vim.bo[0].formatprg = 'Parinfer'
						vim.cmd [[ParinferOn]]
					end,
				})
				-- vim.g.parinfer_force_balance = true
			end,
		},
	},
}
