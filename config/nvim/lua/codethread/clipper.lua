--- Helpers for clipboard/register behavior.
---
--- Use the `+` register everywhere for the system clipboard. In SSH sessions this
--- is handled by Neovim's OSC52 provider, which sends clipboard writes through the
--- terminal to the local/client clipboard.
local M = {}

M.system_register = '+'

function M.copy(text, opts)
	opts = opts or {}
	if type(text) ~= 'string' then
		vim.notify('clipboard content must be a string', vim.log.levels.ERROR)
		return nil
	end

	vim.fn.setreg(M.system_register, text, opts.regtype or 'v')

	if opts.notify ~= false then vim.notify(opts.message or 'saved to clipboard') end
	return text
end

function M.copy_register(register, opts)
	register = register or '"'
	local regtype = vim.fn.getregtype(register)
	local content = vim.fn.getreg(register)
	return M.copy(content, vim.tbl_extend('force', opts or {}, { regtype = regtype }))
end

function M.copy_visual_selection(opts)
	local start_pos = vim.fn.getpos [[v]]
	local end_pos = vim.fn.getpos [[.]]
	local mode = vim.fn.mode()

	-- Lua callbacks for visual mappings run after Vim has started resolving the
	-- mapping, so `gv` can reselect the previous visual area. Read the live visual
	-- endpoints directly instead of yanking through the unnamed register.
	if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
		start_pos = vim.fn.getpos [['<]]
		end_pos = vim.fn.getpos [['>]]
		mode = vim.fn.visualmode()
	end

	local start_row, start_col = start_pos[2], start_pos[3]
	local end_row, end_col = end_pos[2], end_pos[3]

	if start_row > end_row or (start_row == end_row and start_col > end_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end

	local lines
	local regtype = 'v'
	if mode == 'V' then
		lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
		regtype = 'V'
	elseif mode == '\22' then
		lines = vim
			.iter(vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false))
			:map(function(line) return string.sub(line, start_col, end_col) end)
			:totable()
		regtype = mode .. tostring(end_col - start_col + 1)
	else
		lines = vim.api.nvim_buf_get_text(0, start_row - 1, start_col - 1, end_row - 1, end_col, {})
	end

	return M.copy(table.concat(lines, '\n'), vim.tbl_extend('force', opts or {}, { regtype = regtype }))
end

function M.paste(opts)
	opts = opts or {}
	return vim.fn.getreg(opts.register or M.system_register)
end

return M
