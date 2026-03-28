return {
	{
		'rose-pine/neovim',
		name = 'rose-pine',
		priority = 1000,
		lazy = false,
		config = function()
			require('rose-pine').setup {
				variant = 'moon',
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
