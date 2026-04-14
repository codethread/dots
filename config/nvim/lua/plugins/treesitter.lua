-- local is_nixos = vim.env.IS_NIXOS == 'true'
-- NixOS: re-enable is_nixos checks and nix-specific blocks below when testing on NixOS

---@diagnostic disable: missing-fields
return {
	{
		'nvim-treesitter/nvim-treesitter',
		branch = 'main',
		build = ':TSUpdate',
		dependencies = { 'andymass/vim-matchup' },
		config = function()
			-- Enable treesitter highlighting and indentation for all filetypes
			vim.api.nvim_create_autocmd('FileType', {
				callback = function()
					pcall(vim.treesitter.start)
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})

			-- NixOS: prepend nix-provided parsers to rtp before installing
			-- local nix_parsers = vim.fn.stdpath('data') .. '/nix-treesitter-parsers'
			-- if is_nixos and vim.uv.fs_stat(nix_parsers) then
			-- 	vim.opt.runtimepath:prepend(nix_parsers)
			-- end

			-- NixOS: parsers come from nix (see nix/features/common.nix), skip installation
			-- if not is_nixos then
			-- stylua: ignore
			local parsers = vim.iter({
				-- scripting
				{ 'awk', 'bash', 'jq', 'nu' },
				-- langs
				{ 'c', 'rust', 'gleam', 'zig', 'disassembly' },
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

			require('nvim-treesitter').install(parsers)
			-- end

			vim.treesitter.language.register('jsonc', 'json')
			vim.treesitter.language.register('dts', 'keymap')
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
