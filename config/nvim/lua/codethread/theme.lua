-- Single source of truth for theme colors across the nvim config.
--
-- Tokyo Night stays the default, but keep the Rose Pine setup here too so the
-- active family can be switched without recovering per-plugin config.

local M = {}

local DEFAULT_FAMILY = 'rose-pine'
local families = {
	['rose-pine'] = true,
	tokyonight = true,
}

local rose_pine_colors = {
	moon = {
		base = '#232136',
		surface = '#2a273f',
		overlay = '#393552',
		muted = '#6e6a86',
		subtle = '#908caa',
		text = '#e0def4',
		love = '#eb6f92',
		gold = '#f6c177',
		rose = '#ea9a97',
		pine = '#3e8fb0',
		foam = '#9ccfd8',
		iris = '#c4a7e7',
		highlight_low = '#2a283e',
		highlight_med = '#44415a',
		highlight_high = '#56526e',
	},
	dawn = {
		-- base = '#faf4ed',
		base = '#fdf9f5',
		surface = '#fffaf3',
		overlay = '#f2e9e1',
		muted = '#9893a5',
		subtle = '#797593',
		text = '#575279',
		love = '#b4637a',
		-- gold = '#ea9d34',
		gold = '#a86a00',
		-- rose = '#d7827e',
		rose = '#b85c58',
		pine = '#286983',
		foam = '#56949f',
		iris = '#907aa9',
		highlight_low = '#f4ede8',
		highlight_med = '#dfdad9',
		highlight_high = '#cecacd',
	},
}

local rose_pine_highlight_groups = {
	NonText = { fg = 'base' },
	ColorColumn = { bg = 'rose' },
	CursorLine = { bg = 'foam', blend = 10 },
	StatusLine = { fg = 'foam', bg = 'foam', blend = 10 },

	['@variable'] = { italic = false },
	['@variable.builtin'] = { fg = 'text', bold = true },
	['@keyword.bang'] = { fg = 'love', underline = true },
	['@keyword.return'] = { fg = 'iris' },
	['@keyword.export'] = { fg = 'love' },
	['@keyword.default'] = { fg = 'love', bold = true },
	['@lsp.mod.async.typescript'] = { bold = true, undercurl = true },
	['@markup'] = { fg = 'rose' },
	['@markup.italic'] = { italic = true },
	['@markup.heading.1'] = { fg = 'gold', underline = true },
	['@markup.heading.2'] = { fg = 'rose', bold = true },
	['@text.emphasis'] = { italic = true },
	Comment = { italic = true },
	htmlItalic = { italic = true },
	mkdCode = { italic = true },
}

-- Custom per-language highlight themes (see the required module for the spec).
local rose_pine_clojure_groups = require 'codethread.clojure'

local function read_state(name)
	local state_home = vim.env.XDG_STATE_HOME or (vim.fn.expand '~' .. '/.local/state')
	local path = state_home .. '/' .. name
	if vim.fn.filereadable(path) == 1 then
		local lines = vim.fn.readfile(path)
		return vim.trim(lines[1] or '')
	end
end

function M.mode() return read_state 'color-theme' == 'light' and 'light' or 'dark' end

function M.family()
	local family = vim.env.CT_THEME_FAMILY or read_state 'color-theme-family'
	return families[family] and family or DEFAULT_FAMILY
end

function M.colorscheme() return M.family() == 'rose-pine' and 'rose-pine' or 'tokyonight' end

function M.lazy_plugin_dir() return M.family() == 'rose-pine' and 'rose-pine' or 'tokyonight.nvim' end

local function tokyonight_style() return M.mode() == 'light' and 'day' or 'moon' end

local function rose_pine_variant() return M.mode() == 'light' and 'dawn' or 'moon' end

function M.style() return M.family() == 'rose-pine' and rose_pine_variant() or tokyonight_style() end

function M.colors()
	if M.family() == 'rose-pine' then return rose_pine_colors[rose_pine_variant()] end
	return require('tokyonight.colors').setup { style = tokyonight_style() }
end

local function tokyonight_palette(c)
	return {
		statusline = {
			normal_fg = c.blue,
			normal_b = c.fg,
			normal_c = c.comment,
			insert_fg = c.teal,
			visual_fg = c.magenta,
			replace_fg = c.green,
			command_fg = c.red,
			inactive_fg = c.dark3,
			winbar_fg = c.blue1,
		},
		flash = {
			label_bg = c.bg_dark,
			label_fg = c.fg,
		},
		notes = {
			todo_fg = c.orange,
			done_fg = c.cyan,
			right_arrow_fg = c.orange,
			tilde_fg = c.red,
			bullet_fg = c.cyan,
			ref_text_fg = c.purple,
			ext_link_icon_fg = c.purple,
			tag_fg = c.cyan,
			block_id_fg = c.cyan,
			highlight_bg = c.yellow,
			highlight_fg = c.bg,
		},
		whitespace = {
			hidden = c.bg_dark,
			visible = c.green,
		},
		telescope = {
			border = c.bg_dark,
			normal_bg = c.bg_dark,
			normal_fg = c.fg,
			selection_bg = c.bg_highlight,
			selection_fg = c.fg,
			selection_caret = c.red,
			multi_selection_bg = c.bg_visual,
			title = c.red,
			prompt_title = c.magenta,
			preview_title = c.purple,
			prompt_bg = c.bg,
			prompt_fg = c.fg,
			prompt_counter = c.comment,
		},
		snacks = {
			debug_bg = c.bg,
			debug_fg = c.fg,
			indent = c.bg_highlight,
			indent_chunk = c.purple,
			indent_scope = c.purple,
		},
		syntax = {
			nontext = c.bg,
			colorcolumn = c.magenta,
			cursorline = c.teal,
			variable_builtin = c.fg,
			keyword_bang = c.red,
			keyword_return = c.purple,
			keyword_export = c.red,
			keyword_default = c.red,
			markup = c.magenta,
			markup_heading_1 = c.yellow,
			markup_heading_2 = c.magenta,
		},
	}
end

local function rose_pine_palette(c)
	return {
		statusline = {
			normal_fg = c.rose,
			normal_b = c.text,
			normal_c = c.subtle,
			insert_fg = c.foam,
			visual_fg = c.iris,
			replace_fg = c.pine,
			command_fg = c.love,
			inactive_fg = c.subtle,
			winbar_fg = c.pine,
		},
		flash = {
			label_bg = c.surface,
			label_fg = c.text,
		},
		notes = {
			todo_fg = c.love,
			done_fg = c.foam,
			right_arrow_fg = c.gold,
			tilde_fg = c.love,
			bullet_fg = c.foam,
			ref_text_fg = c.iris,
			ext_link_icon_fg = c.iris,
			tag_fg = c.foam,
			block_id_fg = c.foam,
			highlight_bg = c.rose,
			highlight_fg = c.base,
		},
		whitespace = {
			hidden = c.surface,
			visible = c.pine,
		},
		telescope = {
			border = c.surface,
			normal_bg = c.surface,
			normal_fg = c.text,
			selection_bg = c.overlay,
			selection_fg = c.text,
			selection_caret = c.love,
			multi_selection_bg = c.highlight_med,
			title = c.love,
			prompt_title = c.rose,
			preview_title = c.iris,
			prompt_bg = c.base,
			prompt_fg = c.text,
			prompt_counter = c.subtle,
		},
		snacks = {
			debug_bg = c.base,
			debug_fg = c.text,
			indent = c.overlay,
			indent_chunk = c.iris,
			indent_scope = c.iris,
		},
		syntax = {
			nontext = c.base,
			colorcolumn = c.rose,
			cursorline = c.foam,
			variable_builtin = c.text,
			keyword_bang = c.love,
			keyword_return = c.iris,
			keyword_export = c.love,
			keyword_default = c.love,
			markup = c.rose,
			markup_heading_1 = c.gold,
			markup_heading_2 = c.rose,
		},
	}
end

local function active_palette()
	if M.family() == 'rose-pine' then return rose_pine_palette(M.colors()) end
	return tokyonight_palette(M.colors())
end

function M.on_highlights(hl, c)
	local t = tokyonight_palette(c)

	hl.NonText = { fg = t.syntax.nontext }
	hl.ColorColumn = { bg = t.syntax.colorcolumn }
	hl.CursorLine = { bg = t.syntax.cursorline, blend = 10 }
	hl.StatusLine = { fg = t.syntax.cursorline, bg = t.syntax.cursorline, blend = 10 }

	hl['@variable'] = { italic = false }
	hl['@variable.builtin'] = { fg = t.syntax.variable_builtin, bold = true }
	hl['@keyword.bang'] = { fg = t.syntax.keyword_bang, underline = true }
	hl['@keyword.return'] = { fg = t.syntax.keyword_return }
	hl['@keyword.export'] = { fg = t.syntax.keyword_export }
	hl['@keyword.default'] = { fg = t.syntax.keyword_default, bold = true }
	hl['@lsp.mod.async.typescript'] = { bold = true, undercurl = true }
	hl['@markup'] = { fg = t.syntax.markup }
	hl['@markup.italic'] = { italic = true }
	hl['@markup.heading.1'] = { fg = t.syntax.markup_heading_1, underline = true }
	hl['@markup.heading.2'] = { fg = t.syntax.markup_heading_2, bold = true }
	hl['@text.emphasis'] = { italic = true }
	hl.Comment = { italic = true }
	hl.htmlItalic = { italic = true }
	hl.mkdCode = { italic = true }

	hl.TelescopeBorder = { fg = t.telescope.border, bg = t.telescope.border }
	hl.TelescopeNormal = { fg = t.telescope.normal_fg, bg = t.telescope.normal_bg }
	hl.TelescopeSelection = { fg = t.telescope.selection_fg, bg = t.telescope.selection_bg }
	hl.TelescopeSelectionCaret = {
		fg = t.telescope.selection_caret,
		bg = t.telescope.selection_bg,
	}
	hl.TelescopeMultiSelection = {
		fg = t.telescope.normal_fg,
		bg = t.telescope.multi_selection_bg,
	}
	hl.TelescopeTitle = { fg = t.telescope.title }
	hl.TelescopePromptTitle = { fg = t.telescope.prompt_title }
	hl.TelescopePreviewTitle = { fg = t.telescope.preview_title }
	hl.TelescopePromptNormal = { fg = t.telescope.prompt_fg, bg = t.telescope.prompt_bg }
	hl.TelescopePromptBorder = { fg = t.telescope.prompt_bg, bg = t.telescope.prompt_bg }
	hl.TelescopePromptCounter = { fg = t.telescope.prompt_counter }

	hl.SnacksDebugPrint = { bg = t.snacks.debug_bg, fg = t.snacks.debug_fg }
	hl.SnacksIndent = { fg = t.snacks.indent }
	hl.SnacksIndentChunk = { fg = t.snacks.indent_chunk }
	hl.SnacksIndentScope = { fg = t.snacks.indent_scope }

	hl.FlashLabel = { bg = t.flash.label_bg, fg = t.flash.label_fg }
end

function M.tokyonight_opts()
	return {
		style = tokyonight_style(),
		transparent = true,
		terminal_colors = true,
		styles = {
			comments = { italic = true },
			keywords = { italic = false },
		},
		on_highlights = M.on_highlights,
	}
end

function M.rose_pine_highlights()
	return vim.tbl_extend('force', vim.deepcopy(rose_pine_highlight_groups), rose_pine_clojure_groups)
end

function M.rose_pine_opts()
	return {
		variant = rose_pine_variant(),
		styles = { italic = true, transparency = true },
		enable = {
			terminal = true,
			legacy_highlights = false,
			migrations = false,
		},
		palette = {
			-- Override the builtin palette per variant
			moon = rose_pine_colors.moon,
			dawn = rose_pine_colors.dawn,
		},
		dim_inactive_windows = false,
		extend_background_behind_borders = true,
		highlight_groups = M.rose_pine_highlights(),
	}
end

function M.toggleterm_highlights()
	if M.family() == 'rose-pine' then return require 'rose-pine.plugins.toggleterm' end
end

setmetatable(M, {
	__index = function(_, key) return active_palette()[key] end,
})

return M
