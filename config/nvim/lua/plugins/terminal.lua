return {
	-- TODO: https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md
	{
		'akinsho/toggleterm.nvim',
		version = 'v2.*',
		cmd = 'ToggleTerm',
		opts = {
			size = function(term)
				if term.direction == 'horizontal' then
					return 15
				elseif term.direction == 'vertical' then
					return vim.o.columns * 0.4
				end
			end,
			shell = 'nu',
			open_mapping = [[<M-t>]],
			hide_numbers = true,
			start_in_insert = true,
			insert_mappings = true,
			terminal_mappings = true,
			persist_size = true,
			direction = 'horizontal',
			close_on_exit = false,
			float_opts = {
				border = 'single',
				winblend = 3,
			},
		},
		init = function()
			function _G.set_terminal_keymaps()
				local opts = { buffer = 0, noremap = true }
				vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
				vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
				vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-W>h]], opts)
				vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-W>j]], opts)
				vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-W>k]], opts)
				vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-W>l]], opts)
			end
			vim.cmd 'autocmd! TermOpen term://* lua set_terminal_keymaps()'
		end,
	},
	{
		'fladson/vim-kitty',
		ft = 'kitty',
	},
}
