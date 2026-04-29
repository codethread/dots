-- require 'codethread.disabled'
-- transparent
vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })

-- TODO:
-- clipboard
-- shortcuts

local function load_plugins()
	local lazypath = vim.fn.stdpath 'data' .. '/lazy'
	local theme = require 'codethread.theme'

	vim.iter({ theme.lazy_plugin_dir(), 'flash.nvim' }):each(function(mod)
		local plug = lazypath .. '/' .. mod
		vim.opt.rtp:prepend(plug)
	end)

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
				enabled = false,
			},
			char = {
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
	vim.opt.scrolloff = 0
	vim.opt.sidescrolloff = 0

	local group = vim.api.nvim_create_augroup('kitty+page', {})

	local setCursor = function()
		local line = math.min(CURSOR_LINE, vim.api.nvim_buf_line_count(0))
		vim.api.nvim_win_set_cursor(0, { line, math.max(CURSOR_COLUMN - 1, 0) })
		vim.api.nvim_feedkeys(tostring(INPUT_LINE_NUMBER) .. 'ggzt', 'n', true)
	end

	vim.keymap.set('n', 'q', '<Cmd>q<CR>')
	vim.keymap.set('n', '<ESC>', '<Cmd>q<CR>')

	vim.api.nvim_create_autocmd('VimEnter', {
		group = group,
		pattern = '*',
		once = true,
		callback = function()
			vim.schedule(function()
				setCursor()
				vim.schedule(load_plugins)
			end)
		end,
	})

	vim.api.nvim_create_autocmd('TextYankPost', {
		group = group,
		callback = function() vim.highlight.on_yank() end,
	})
end
