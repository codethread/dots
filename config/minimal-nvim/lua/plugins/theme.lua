-- Mirrors the main config's check without depending on it, so this stays standalone
local function mode()
	local state_home = vim.env.XDG_STATE_HOME or (vim.fn.expand '~' .. '/.local/state')
	local path = state_home .. '/color-theme'
	if vim.fn.filereadable(path) == 1 then
		local lines = vim.fn.readfile(path)
		if vim.trim(lines[1] or '') == 'light' then return 'light' end
	end
	return 'dark'
end

return {
	{
		'rose-pine/neovim',
		name = 'rose-pine',
		priority = 1000,
		lazy = false,
		config = function()
			vim.o.background = mode()
			require('rose-pine').setup {
				variant = mode() == 'light' and 'dawn' or 'moon',
				styles = { italic = true, transparency = true },
				enable = {
					terminal = true,
					legacy_highlights = false,
					migrations = false,
				},
				dim_inactive_windows = false,
				extend_background_behind_borders = true,
				highlight_groups = {
					NonText = { fg = 'base' },
					ColorColumn = { bg = 'rose' },
					CursorLine = { bg = 'foam', blend = 10 },
					StatusLine = { fg = 'foam', bg = 'foam', blend = 10 },

					['@variable'] = { italic = false },
					['@variable.builtin'] = { fg = 'text', bold = true },

					['@keyword.return'] = { fg = 'iris' },
					['@keyword.export'] = { fg = 'love' },

					['@markup'] = { fg = 'rose' },
					['@markup.italic'] = { italic = true },
					['@markup.heading.1'] = { fg = 'gold', underline = true },
					['@markup.heading.2'] = { fg = 'rose', bold = true },

					['@text.emphasis'] = { italic = true },
					Comment = { italic = true },
				},
			}
			vim.cmd [[colorscheme rose-pine]]
		end,
	},
}
