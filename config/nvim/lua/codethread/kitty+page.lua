-- require 'codethread.disabled'
-- transparent
vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })

-- TODO:
-- clipboard
-- shortcuts
-- https://sw.kovidgoyal.net/kitty/launch/#the-piping-environment

local function load_plugins()
	local lazypath = vim.fn.stdpath 'data' .. '/lazy'

	vim.iter({ 'tokyonight.nvim', 'flash.nvim' }):each(function(mod)
		local plug = lazypath .. '/' .. mod
		vim.opt.rtp:prepend(plug)
	end)

	local theme = require 'codethread.theme'
	vim.api.nvim_set_hl(0, 'FlashLabel', {
		bg = theme.flash.label_bg,
		fg = theme.flash.label_fg,
	})
	local flash = require 'flash'
	flash.setup {
		label = {
			exclude = 'xb',
		},
		search = {
			multi_window = false,
		},
		modes = {
			search = {
				enabled = false, -- i do like this but it's annoying on large files
			},
			char = {
				-- can set to false, but can actually just use f/F r t/T to repeat motions, in case of overshooting
				multi_line = true,
			},
		},
	}
	vim.keymap.set({ 'n', 'x', 'o' }, '<C-f>', flash.jump)
end

return function(INPUT_LINE_NUMBER, CURSOR_LINE, CURSOR_COLUMN)
	vim.opt.encoding = 'utf-8'
	vim.opt.clipboard = 'unnamed'
	vim.opt.compatible = false
	vim.opt.number = false
	vim.opt.relativenumber = false
	vim.opt.termguicolors = true
	vim.opt.showmode = false
	vim.opt.ruler = false
	vim.opt.laststatus = 0
	vim.o.cmdheight = 0
	vim.opt.showcmd = false
	vim.opt.scrollback = INPUT_LINE_NUMBER + CURSOR_LINE
	local term_buf = vim.api.nvim_create_buf(true, false)
	local term_io = vim.api.nvim_open_term(term_buf, {})
	vim.keymap.set('n', 'q', '<Cmd>q<CR>', { buffer = term_buf })
	vim.keymap.set('n', '<ESC>', '<Cmd>q<CR>', { buffer = term_buf })
	local group = vim.api.nvim_create_augroup('kitty+page', {})

	local setCursor = function()
		vim.api.nvim_feedkeys(tostring(INPUT_LINE_NUMBER) .. [[ggzt]], 'n', true)
		local line = vim.api.nvim_buf_line_count(term_buf)
		if CURSOR_LINE <= line then line = CURSOR_LINE end
		vim.api.nvim_feedkeys(tostring(line - 1) .. [[j]], 'n', true)
		vim.api.nvim_feedkeys([[0]], 'n', true)
		vim.api.nvim_feedkeys(tostring(CURSOR_COLUMN - 1) .. [[l]], 'n', true)
	end

	vim.api.nvim_create_autocmd('ModeChanged', {
		group = group,
		buffer = term_buf,
		callback = function()
			local mode = vim.fn.mode()
			if mode == 't' then
				vim.cmd.stopinsert()
				vim.schedule(setCursor)
			end
		end,
	})

	vim.api.nvim_create_autocmd('VimEnter', {
		group = group,
		pattern = '*',
		once = true,
		callback = function(ev)
			local current_win = vim.fn.win_getid()
			for _, line in ipairs(vim.api.nvim_buf_get_lines(ev.buf, 0, -2, false)) do
				vim.api.nvim_chan_send(term_io, line)
				vim.api.nvim_chan_send(term_io, '\r\n')
			end
			for _, line in ipairs(vim.api.nvim_buf_get_lines(ev.buf, -2, -1, false)) do
				vim.api.nvim_chan_send(term_io, line)
			end
			vim.api.nvim_win_set_buf(current_win, term_buf)
			vim.api.nvim_buf_delete(ev.buf, { force = true })
			vim.schedule(setCursor)

			vim.schedule(load_plugins)
		end,
	})

	vim.api.nvim_create_autocmd('TextYankPost', {
		group = group,
		callback = function() vim.highlight.on_yank() end,
	})
end
