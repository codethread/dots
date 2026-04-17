local M = {}

---Escape % in str so it doesn't get picked as stl item.
---@param str string
---@return string
local function stl_escape(str)
	if type(str) ~= 'string' then return str end
	return str:gsub('%%', '%%%%')
end

local custom_options = {
	symbols = {
		modified = '  ',
		readonly = ' ',
		unnamed = '[No Name]',
		newfile = '[New]',
	},
	file_status = true,
	newfile_status = false,
	path = 1,
	shorting_target = 0,
}

local function is_new_file()
	local filename = vim.fn.expand '%'
	return filename ~= '' and vim.bo.buftype == '' and vim.fn.filereadable(filename) == 0
end

local function filename_and_parent(path, sep)
	local segments = vim.split(path, sep)
	if #segments == 0 then
		return path
	elseif #segments == 1 then
		return segments[#segments]
	else
		return table.concat({ segments[#segments - 1], segments[#segments] }, sep)
	end
end

local mode_maps = {
	['INSERT'] = '',
	['NORMAL'] = '',
	['VISUAL'] = '',
	['V-BLOCK'] = '',
	['V-LINE'] = '',
	['TERMINAL'] = '❯',
	-- ["TERMINAL"] = "",
}

M.mode_map = function(str) return mode_maps[str] or str end

M.theme = function()
	local t = require('codethread.theme')
	local bg_base = 'NONE'
	local bg = 'NONE'

	do
		local base_statusline_highlights = {
			'StatusLine', 'StatusLineNC', 'Tabline',
			'TabLineFill', 'TabLineSel', 'Winbar', 'WinbarNC',
		}
		for _, hl_group in pairs(base_statusline_highlights) do
			vim.api.nvim_set_hl(0, hl_group, { bg = 'none' })
		end
	end

	return {
		normal = {
			a = { bg = bg, fg = t.statusline.normal_fg, gui = 'bold' },
			b = { bg = bg, fg = t.statusline.normal_b },
			c = { bg = bg, fg = t.statusline.normal_c, gui = 'italic' },
		},
		insert  = { a = { bg = bg, fg = t.statusline.insert_fg,  gui = 'bold' } },
		visual  = { a = { bg = bg, fg = t.statusline.visual_fg,  gui = 'bold' } },
		replace = { a = { bg = bg, fg = t.statusline.replace_fg, gui = 'bold' } },
		command = { a = { bg = bg, fg = t.statusline.command_fg, gui = 'bold' } },
		inactive = {
			a = { bg = bg_base, fg = t.statusline.inactive_fg, gui = 'bold' },
			b = { bg = bg_base, fg = t.statusline.inactive_fg },
			c = { bg = bg_base, fg = t.statusline.inactive_fg, gui = 'italic' },
		},
		inactive_winbar = {
			a = { bg = bg_base, fg = t.statusline.winbar_fg, gui = 'bold' },
			b = { bg = bg_base, fg = t.statusline.winbar_fg },
			c = { bg = bg_base, fg = t.statusline.winbar_fg, gui = 'italic' },
		},
		winbar = {
			a = { bg = bg_base, fg = t.statusline.winbar_fg, gui = 'bold' },
			b = { bg = bg_base, fg = t.statusline.winbar_fg },
			c = { bg = bg_base, fg = t.statusline.winbar_fg, gui = 'italic' },
		},
	}
end

M.update_status = function()
	local path_separator = '/'
	local data
	local note_info = require 'plugins.notes.constants'
	-- absolute path, with tilde
	local tildePath = vim.fn.expand '%:p:~'
	if note_info.has_notes and vim.startswith(tildePath, note_info.cwd) then
		data = string.gsub(tildePath, note_info.cwd, '📖')
	elseif custom_options.path == 1 then
		-- relative path
		data = vim.fn.expand '%:~:.'
	elseif custom_options.path == 2 then
		-- absolute path
		data = vim.fn.expand '%:p'
	elseif custom_options.path == 3 then
		data = tildePath
	elseif custom_options.path == 4 then
		-- filename and immediate parent
		data = filename_and_parent(vim.fn.expand '%:p:~', path_separator)
	else
		-- just filename
		data = vim.fn.expand '%:t'
	end

	if data == '' then data = custom_options.symbols.unnamed end

	data = stl_escape(data)

	local symbols = {}
	if custom_options.file_status then
		if vim.bo.modified then table.insert(symbols, custom_options.symbols.modified) end
		if vim.bo.modifiable == false or vim.bo.readonly == true then
			table.insert(symbols, custom_options.symbols.readonly)
		end
	end

	if custom_options.newfile_status and is_new_file() then
		table.insert(symbols, custom_options.symbols.newfile)
	end

	return data .. (#symbols > 0 and ' ' .. table.concat(symbols, '') or '')
end

---show the current file name and the parent directory (if available)
M.filename_winbar = function()
	local symbols = {
		modified = '  ',
		readonly = ' ',
	}

	local ft = vim.bo.filetype
	local pwd = vim.fn.getcwd()
	local modified = vim.bo[0].modified and symbols.modified or ''
	if ft == 'oil' then return vim.fn.expand('%'):gsub('oil://' .. pwd .. '/', '') .. modified end
	local paths = vim.split(vim.fn.expand('%'):gsub(pwd, ''), '/')
	if #paths == 1 then return paths[1] .. modified end
	if #paths == 2 then return paths[#paths - 1] .. '/' .. paths[#paths] .. modified end
	return '.../' .. paths[#paths - 1] .. '/' .. paths[#paths] .. modified
end

M.unsaved_buffers = function()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local is_modified = vim.api.nvim_buf_get_option(buf, 'modified')
		local cur = vim.api.nvim_get_current_buf()
		if is_modified and cur ~= buf then
			return 'Unsaved buffers' -- any message or icon
		end
	end
	return ''
end

return M
