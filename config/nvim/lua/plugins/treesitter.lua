---@diagnostic disable: missing-fields
return {
	{
		'nvim-treesitter/nvim-treesitter',
		branch = 'main',
		lazy = false,
		build = ':TSUpdate',
		dependencies = { 'andymass/vim-matchup' },
		config = function()
			-- Enable treesitter highlighting and indentation for all filetypes with a parser.
			vim.api.nvim_create_autocmd('FileType', {
				group = vim.api.nvim_create_augroup('CodeThreadTreesitter', { clear = true }),
				callback = function()
					local ok = pcall(vim.treesitter.start)
					if not ok then return end

					if vim.bo.filetype == 'clojure' then
						-- Clojure has no Treesitter indent queries. Copy the current
						-- indentation first, then let Parinfer adjust it.
						vim.bo.indentexpr = ''
						vim.bo.autoindent = true
					else
						vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})

			-- stylua: ignore
			local parsers = vim.iter({
				-- scripting
				{ 'awk', 'bash', 'jq', 'nu' },
				-- langs
				{ 'c', 'clojure', 'rust', 'gleam', 'zig', 'disassembly', 'devicetree' },
				{ 'go', 'gosum', 'gomod', 'gowork' },
				-- DB
				{ 'sql' },
				-- web
				{ 'css','scss','html','jsdoc','javascript','typescript','tsx','graphql','styled' },
				-- webish
				{ 'embedded_template','http','prisma','proto' },
				-- config (the json parser also handles jsonc)
				{ 'dockerfile','json','json5','make','nix','toml','yaml' },
				-- git
				{ 'diff','git_rebase','gitattributes','gitcommit' },
				-- vim
				{ 'vim','vimdoc','lua','luadoc','luap','query' },
				-- misc
				{ 'comment','todotxt','markdown','markdown_inline','regex' },
			}):flatten():totable()

			-- Install missing parsers asynchronously; :TSUpdate handles plugin upgrades.
			-- The default data/site directory keeps config queries first on runtimepath.
			require('nvim-treesitter').install(parsers)

			vim.treesitter.language.register('devicetree', 'keymap')
		end,
	},

	{
		'nvim-treesitter/nvim-treesitter-textobjects',
		branch = 'main',
		main = 'nvim-treesitter-textobjects',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
		opts = {
			select = {
				enable = true,
				lookahead = false,
				keymaps = {
					['af'] = '@function.outer',
					['if'] = '@function.inner',
					['ac'] = '@class.outer',
					['ic'] = '@class.inner',
					['aa'] = '@parameter.outer',
					['ia'] = '@parameter.inner',
					['ab'] = '@conditional.outer', -- b for 'branch'
					['ib'] = '@conditional.inner',
					['ai'] = '@import.outer',
					['ii'] = '@import.inner',
				},
			},
			swap = {
				enable = true,
				swap_next = { ['<leader>}'] = '@parameter.outer' },
				swap_previous = { ['<leader>{'] = '@parameter.outer' },
			},
			lsp_interop = {
				enable = true,
				border = 'none',
				floating_preview_opts = {},
				peek_definition_code = {
					['<leader>lp'] = '@function.outer',
					['<leader>lP'] = '@class.outer',
				},
			},
		},
	},

	{
		'nvim-treesitter/nvim-treesitter-context',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
		opts = {
			multiline_threshold = 1,
			max_lines = 2,
		},
	},

	{
		'mawkler/jsx-element.nvim',
		dependencies = {
			'nvim-treesitter/nvim-treesitter',
			'nvim-treesitter/nvim-treesitter-textobjects',
		},
		ft = { 'typescriptreact', 'javascriptreact', 'javascript' },
		opts = {},
	},

	{ 'fei6409/log-highlight.nvim', event = 'BufRead *.log', ft = 'log', opts = {} },
}
