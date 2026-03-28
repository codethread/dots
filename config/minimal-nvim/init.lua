-- Lightweight neovim config for container/minimal use
-- Use with NVIM_APPNAME=minimal-nvim

vim.keymap.set('', '<Space>', '<Nop>')
vim.g.mapleader = ' '
vim.keymap.set('', ',', '<Nop>')
vim.g.maplocalleader = ','

require 'options'

do -- bootstrap lazy.nvim
	local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
	if not (vim.uv or vim.loop).fs_stat(lazypath) then
		local out = vim.fn.system {
			'git', 'clone', '--filter=blob:none', '--branch=stable',
			'https://github.com/folke/lazy.nvim.git', lazypath,
		}
		if vim.v.shell_error ~= 0 then
			vim.api.nvim_echo({
				{ 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
				{ out, 'WarningMsg' },
			}, true, {})
			vim.fn.getchar()
			os.exit(1)
		end
	end
	vim.opt.rtp:prepend(lazypath)
end

require('lazy').setup({
	spec = { { import = 'plugins' } },
	defaults = { lazy = true },
	install = { colorscheme = { 'rose-pine' } },
	performance = {
		rtp = {
			disabled_plugins = {
				'gzip', 'matchit', 'matchparen', 'netrwPlugin',
				'tarPlugin', 'tohtml', 'tutor', 'zipPlugin',
			},
		},
	},
})

require 'keymaps'
