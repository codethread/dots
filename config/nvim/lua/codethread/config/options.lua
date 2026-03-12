-- :module: Neovim global editor configuration settings
-- TODO: change cursor, line is easy to miss
-- terminal
-- vim.opt.shell = vim.env.SHELL or 'sh'
vim.opt.shell = 'bash'
vim.env.SHELL = 'bash'
vim.opt.termguicolors = true -- adds more colors
vim.opt.hidden = true -- Required to keep multiple buffers open multiple buffers
vim.opt.encoding = 'utf-8' -- The encoding displayed
vim.opt.pumheight = 10 -- Makes popup menu smaller
-- vim.opt.pumborder = 'rounded'
-- vim.opt.winborder = 'double'
vim.opt.fileencoding = 'utf-8' -- The encoding written to file
vim.opt.spellfile = vim.fn.expand '~' .. '/.config/.en.utf-8.add'
vim.opt.ruler = true -- Show the cursor position all the time
vim.opt.laststatus = 3
vim.opt.wrap = false -- Display long lines as just one line
vim.opt.splitbelow = true -- Horizontal splits will automatically be below
vim.opt.splitright = true -- Vertical splits will automatically be to the right
vim.opt.tabstop = 4 -- Insert X spaces for a tab
vim.opt.shiftwidth = 0 -- Indent to whatever tabstop is
vim.opt.smartindent = true -- Makes indenting smart
vim.opt.autoindent = true -- Good auto indent
vim.opt.softtabstop = 2 -- Set the behavior of tab
vim.opt.smarttab = true -- Makes tabbing smarter will realize you have 2 vs 4
vim.opt.expandtab = false -- Converts tabs to spaces
-- vim.opt.inccommand = 'split'
vim.opt.confirm = true

-- if wanting to show white space in some way
vim.opt.listchars = {
	tab = '» ',
	eol = '¬',
	space = '␣',
	extends = '>',
	precedes = '<',
	trail = '~',
}
-- :set list

-- change ~ eol chars
vim.opt.fillchars:append { eob = ' ' }

vim.opt.relativenumber = true
vim.opt.number = true -- Line numbers
vim.opt.cursorline = false -- Enable highlighting of the current line
vim.opt.showtabline = 2 -- Always show window tabs

vim.opt.updatetime = 300 -- Faster completion
vim.opt.timeoutlen = 500 -- By default timeoutlen is 1000 ms
-- vim.opt.formatoptions-=cro                  -- Stop newline continution of comments
-- vim.opt.clipboard:append("unnamed") -- Copy paste between vim and everything else
vim.opt.signcolumn = 'yes'
-- always keep some space around the window
vim.opt.scrolloff = 4
vim.o.winblend = 0

vim.opt.hlsearch = false -- don't keep / highlights after searching
vim.o.smartcase = true

vim.opt.showmode = false -- We don't need to see things like -- INSERT -- anymore

if vim.version().minor < 12 then
	-- vim.opt.diffopt = 'internal,filler,closeoff,indent-heuristic,linematch:60,algorithm:histogram'
	vim.opt.diffopt = 'internal,algorithm:histogram,indent-heuristic,linematch:32,filler,context:3'
else
	vim.op.diffopt:append 'inline:word'
end

-- can use abolish-grep with this
-- e.g. :S /plugin/ *
-- e.g. :S /plugin/ *.lua (globs other than * don't seem to work with ripgrep, but that's probably just my config)
-- set grepprg=rg\ --hidden\ --glob\ '!.git'\ --vimgrep\ --with-filename
-- stolen https://github.com/williamboman/nvim-config/blob/main/after/plugin/options.lua
vim.opt.grepprg = 'rg --vimgrep --no-heading --smart-case'
vim.opt.formatoptions:remove 't'
vim.opt.formatoptions:remove 'o'
vim.opt.grepformat = '%f:%l:%c:%m,%f:%l:%m'

vim.cmd [[
  set iskeyword+=-                      	" treat dash separated words as a word text object"
  set mouse=a                             " Enable your mouse


  " hi Search gui=undercurl guibg=none guifg=inherit guisp=green "underlineline", "undercurl", "underdot", and "underdash" fall back
]]

-- au! BufWritePost $MYVIMRC source %      " auto source when writing to init.vm alternatively you can run :source $MYVIMRC

vim.filetype.add {
	pattern = {
		['.*'] = {
			function(_, bufnr)
				local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
				if vim.regex([[^#!.*bun]]):match_str(content) ~= nil then return 'typescript' end
			end,
			{ priority = -math.huge },
		},
	},
	extension = {
		nuon = 'nu',
		tmux = 'tmux',
		['tsconfig.json'] = 'jsonc',
		mdc = 'markdown',
	},
}
