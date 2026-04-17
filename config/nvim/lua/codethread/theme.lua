-- Single source of truth for theme colors across the nvim config.
-- Colors are sourced from the active tokyonight variant via its plugin API.
--
-- NOTE: tokyonight must be on runtimepath before this module is required.
-- It loads with priority=1000/lazy=false in normal nvim startup, so calling
-- this from plugin config functions is safe. Do not require at module top-level.

local M = {}

local function read_style()
	local state_home = vim.env.XDG_STATE_HOME or (vim.fn.expand '~' .. '/.local/state')
	local theme_file = state_home .. '/color-theme'
	if vim.fn.filereadable(theme_file) == 1 then
		local lines = vim.fn.readfile(theme_file)
		if lines[1] == 'light' then return 'day' end
	end
	return 'moon'
end

local style = read_style()
local colors = require('tokyonight.colors').setup { style = style }

local function palette(c)
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

M = vim.tbl_extend('force', M, palette(colors))

function M.style() return style end

function M.colors() return colors end

function M.on_highlights(hl, c)
	local t = palette(c)

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
		style = style,
		transparent = true,
		terminal_colors = true,
		styles = {
			comments = { italic = true },
			keywords = { italic = false },
		},
		on_highlights = M.on_highlights,
	}
end

return M
