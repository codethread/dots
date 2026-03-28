-- Core editor options (subset of main config)
vim.opt.shell = 'bash'
vim.env.SHELL = 'bash'
vim.opt.termguicolors = true
vim.opt.hidden = true
vim.opt.encoding = 'utf-8'
vim.opt.fileencoding = 'utf-8'
vim.opt.pumheight = 10
vim.opt.ruler = true
vim.opt.laststatus = 3
vim.opt.wrap = false
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 0
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.softtabstop = 2
vim.opt.smarttab = true
vim.opt.expandtab = false
vim.opt.confirm = true

vim.opt.listchars = {
	tab = '» ',
	eol = '¬',
	space = '␣',
	extends = '>',
	precedes = '<',
	trail = '~',
}

vim.opt.fillchars:append { eob = ' ' }

vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.cursorline = false
vim.opt.showtabline = 2

vim.opt.updatetime = 300
vim.opt.timeoutlen = 500
if vim.env.SSH_TTY then vim.g.clipboard = 'osc52' end
vim.opt.signcolumn = 'yes'
vim.opt.scrolloff = 4

vim.opt.hlsearch = false
vim.o.smartcase = true
vim.opt.showmode = false

if vim.fn.executable('rg') == 1 then
	vim.opt.grepprg = 'rg --vimgrep --no-heading --smart-case'
	vim.opt.grepformat = '%f:%l:%c:%m,%f:%l:%m'
end

vim.cmd [[
  set iskeyword+=-
  set mouse=a
]]
