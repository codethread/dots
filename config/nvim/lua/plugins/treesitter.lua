local uv = vim.uv or vim.loop
local nix_parsers_dir = vim.fn.stdpath 'data' .. '/nix-treesitter-parsers'
local use_nix_parsers = uv.fs_stat(nix_parsers_dir) ~= nil

---@diagnostic disable: missing-fields
return {
	{
		'nvim-treesitter/nvim-treesitter',
		branch = 'main',
		build = use_nix_parsers and nil or ':TSUpdate',
		dependencies = { 'andymass/vim-matchup' },
		config = function()
			-- Prefer the Home Manager linked runtime when present. Neovim discovers both
			-- parser/*.so and queries/**/*.scm from runtimepath, so if this directory
			-- exists we let Nix own parser management entirely.
			if use_nix_parsers and not vim.tbl_contains(vim.opt.rtp:get(), nix_parsers_dir) then
				vim.opt.rtp:prepend(nix_parsers_dir)
			end

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
				-- config
				{ 'dockerfile','json','json5','jsonc','make','toml','yaml' },
				-- git
				{ 'diff','git_rebase','gitattributes','gitcommit' },
				-- vim
				{ 'vim','vimdoc','lua','luadoc','luap','query' },
				-- misc
				{ 'comment','todotxt','markdown','markdown_inline','regex' },
			}):flatten():totable()

			if not use_nix_parsers then
				require('nvim-treesitter.configs').setup {
					parser_install_dir = vim.fn.stdpath 'data' .. '/site',
					ensure_installed = parsers,
					auto_install = false,
				}
			end

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
