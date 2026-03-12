if _G.ts2 then return {} end

local is_nixos = vim.env.IS_NIXOS == 'true'

---@diagnostic disable: missing-fields
return {
	{
		'folke/which-key.nvim',
		opts = {
			spec = {
				{ '<BS>', desc = 'Decrement Selection', mode = 'x' },
				{ '<c-space>', desc = 'Increment Selection', mode = { 'x', 'n' } },
			},
		},
	},

	{
		'nvim-treesitter/nvim-treesitter',
		event = U.LazyFile,
		lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
		init = function(plugin)
			-- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
			-- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
			-- no longer trigger the **nvim-treesitter** module to be loaded in time.
			-- Luckily, the only things that those plugins need are the custom queries, which we make available
			-- during startup.
			require('lazy.core.loader').add_to_rtp(plugin)
			require 'nvim-treesitter.query_predicates'

			if is_nixos then
				local nix_parsers = vim.fn.stdpath('data') .. '/nix-treesitter-parsers'
				if vim.uv.fs_stat(nix_parsers) then
					vim.opt.runtimepath:prepend(nix_parsers)
				end
			end
		end,
		cmd = { 'TSUpdateSync', 'TSUpdate', 'TSInstall' },
		build = not is_nixos and ':TSUpdate' or false,
		dependencies = { 'andymass/vim-matchup' },
		keys = {
			{ '<c-space>', desc = 'Increment Selection' },
			{ '<bs>', desc = 'Decrement Selection', mode = 'x' },
		},
		---@type TSConfig
		opts = {
			highlight = {
				enable = not vim.g.vscode,
				additional_vim_regex_highlighting = { 'markdown' },
			},
			indent = { enable = true },
			matchup = { enable = true },
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = '<C-space>',
					node_incremental = '<C-space>',
					scope_incremental = false,
					node_decremental = '<bs>',
				},
			},

			-- on NixOS parsers come from nix (see nix/features/common.nix)
			auto_install = not is_nixos,
			-- stylua: ignore
			ensure_installed = is_nixos and {} or vim.iter({
				-- scripting
				{ 'awk', 'bash', 'jq', 'nu' },
				-- langs
				{ 'c', 'rust', 'gleam', 'zig', 'disassembly' },
				{ 'go', 'gosum', 'gomod', 'gowork' },
				-- DB
				{ 'sql' },
				--web
				{ 'css','scss','html','jsdoc','javascript','typescript','tsx','graphql', 'styled' },
				-- webish
				{ 'embedded_template','http','prisma','proto' },
				-- config
				{ 'dockerfile','json','json5','jsonc','make','toml','yaml' },
				-- git
				{ 'diff','git_rebase','gitattributes','gitcommit' },
				-- vim
				{ 'vim','vimdoc','lua','luadoc','luap', 'query' },
				-- misc
				{ 'comment','todotxt','markdown','markdown_inline','regex' },
			}):flatten():totable(),
		},
		---@param opts TSConfig
		config = function(_, opts)
			if type(opts.ensure_installed) == 'table' then
				---@type table<string, boolean>
				local added = {}
				opts.ensure_installed = vim.tbl_filter(function(lang)
					if added[lang] then return false end
					added[lang] = true
					return true
				end, opts.ensure_installed)
			end
			require('nvim-treesitter.configs').setup(opts)
			vim.treesitter.language.register('jsonc', 'json')
			vim.treesitter.language.register('dts', 'keymap')
		end,
	},

	{
		'nvim-treesitter/nvim-treesitter',
		lazy = true,
		dependencies = 'nvim-treesitter/nvim-treesitter-textobjects',
		opts = {
			textobjects = {
				select = {
					enable = true,
					-- Automatically jump forward to textobj, similar to targets.vim
					lookahead = false,
					keymaps = {
						-- You can use the capture groups defined in textobjects.scm
						['af'] = '@function.outer',
						['if'] = '@function.inner',
						['ac'] = '@class.outer',
						['ic'] = '@class.inner',
						-- ['ai'] = '@call.outer', -- i for 'invocation'
						-- ['ii'] = '@call.inner',
						['aa'] = '@parameter.outer',
						['ia'] = '@parameter.inner',

						['ab'] = '@conditional.outer', -- b for 'branch'
						['ib'] = '@conditional.inner',

						['ai'] = '@import.outer',
						['ii'] = '@import.inner',
						-- af = '@custom-field.outer',
						-- ['if'] = '@custom-field.inner',
					},
				},
				swap = {
					enable = true,
					swap_next = {
						['<leader>}'] = '@parameter.outer',
						-- ['<leader>}'] = '@conditional.inner',
					},
					swap_previous = {
						['<leader>{'] = '@parameter.outer',
					},
				},
				lsp_interop = {
					enable = true,
					border = 'none',
					floating_preview_opts = {},
					peek_definition_code = {
						['<leader>lp'] = '@function.outer', -- TODO: YUMMY
						['<leader>lP'] = '@class.outer', -- not sure how these differ?
					},
				},
			},
		},
	},

	{
		'nvim-treesitter/nvim-treesitter-context',
		event = U.LazyFile,
		cmd = 'TSContext',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
		opts = {
			multiline_threshold = 1,
			max_lines = 2, -- How many lines the window should span. Values <= 0 mean no limit.
			-- trim_scope = 'inner', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
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
