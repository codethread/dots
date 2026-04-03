return {
	-- TODO: https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md
	{
		'akinsho/toggleterm.nvim',
		version = 'v2.*',
		cmd = 'ToggleTerm',
		opts = function()
			local highlights = require 'rose-pine.plugins.toggleterm'
			return {
				-- size can be a number or function which is passed the current terminal
				size = function(term)
					if term.direction == 'horizontal' then
						return 15
					elseif term.direction == 'vertical' then
						return vim.o.columns * 0.4
					end
				end,
				shell = 'nu',
				open_mapping = [[<M-t>]],
				hide_numbers = true, -- hide the number column in toggleterm buffers
				start_in_insert = true,
				insert_mappings = true, -- whether or not the open mapping applies in insert mode
				terminal_mappings = true, -- whether or not the open mapping applies in the opened terminals
				persist_size = true,
				direction = 'horizontal',
				close_on_exit = false, -- close the terminal window when the process exits
				highlights = highlights,
				-- 		{
				-- 	 Normal = {
				-- 	   guibg = colors.dark,
				-- 	 },
				-- 	 NormalFloat = {
				-- 	   link = 'NormalDark',
				-- 	 },
				-- 	 FloatBorder = {
				-- 	   guifg = colors.dark,
				-- 	   guibg = colors.dark,
				-- 	 },
				-- },
				float_opts = {
					border = 'single',
					winblend = 3,
				},
			}
		end,
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

			-- if you only want these mappings for toggle term use term://*toggleterm#* instead
			vim.cmd 'autocmd! TermOpen term://* lua set_terminal_keymaps()'
		end,
	},
	{
		'fladson/vim-kitty',
		ft = 'kitty',
	},
}
