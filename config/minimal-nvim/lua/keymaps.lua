local map = vim.keymap.set

-- Insert mode escapes
map('i', 'jk', '<ESC>', { desc = 'esc' })
map('i', 'jj', '<C-w>', { desc = 'backspace word' })

-- Centered navigation
map('n', 'n', 'nzzzv', { desc = 'Center next' })
map('n', 'N', 'Nzzzv', { desc = 'Center prev' })
map('n', 'J', 'mzJ`z', { desc = 'Center join' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Center up' })
map('n', '<C-d>', '<C-d>zz', { desc = 'Center down' })
map('n', 'ZQ', '<cmd>qa!<cr>', { desc = 'Quit no save' })

-- Paste without register in visual
map('x', '<leader>p', '"_dP', { desc = 'paste without register' })

-- Delete without register
map('n', 'x', '"_d', { desc = 'delete no register' })
map('n', 'X', '"_D', { desc = 'delete line no register' })

-- Move text in visual mode
map('v', '<Down>', ":m '>+1<CR>gv=gv", { desc = 'move down' })
map('v', '<Up>', ":m '<-2<CR>gv=gv", { desc = 'move up' })

-- Clipboard yank
map('v', '<leader>y', '"+y', { desc = 'yank to clipboard' })

-- Leader maps not owned by plugins
map('n', '<leader>fb', '<C-^>', { desc = 'Toggle buffer' })
map('n', '<leader>fs', '<cmd>w<cr>', { desc = 'Save' })
map('n', '<leader>fR', '<cmd>e!<cr>', { desc = 'Reload' })

map('n', '<leader>ww', '<cmd>vsplit<cr>', { desc = 'Vsplit' })
map('n', '<leader>wk', '<cmd>close<cr>', { desc = 'Close window' })
map('n', '<leader>wN', '<cmd>tabnew<cr>', { desc = 'New tab' })
map('n', '<leader>wn', '<cmd>tabNext<cr>', { desc = 'Next tab' })
map('n', '<leader>wp', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

-- Quickfix toggle
local qf_open = false
map('n', '<C-q>', function()
	if qf_open then vim.cmd 'cclose' else vim.cmd 'copen' end
	qf_open = not qf_open
end, { desc = 'Toggle quickfix' })

-- Folds (simple, no ufo)
map('n', '-', 'zc', { desc = 'close fold' })
map('n', '=', 'zo', { desc = 'open fold' })
map('n', '_', 'zC', { desc = 'close all folds under cursor' })
map('n', '+', 'zO', { desc = 'open all folds under cursor' })
