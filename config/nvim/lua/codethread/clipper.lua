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
	local previous_register = vim.fn.getreg('"')
	local previous_register_type = vim.fn.getregtype('"')

	vim.cmd 'normal! gvy'
	local content = vim.fn.getreg('"')
	local regtype = vim.fn.getregtype('"')

	vim.fn.setreg('"', previous_register, previous_register_type)
	return M.copy(content, vim.tbl_extend('force', opts or {}, { regtype = regtype }))
end

function M.paste(opts)
	opts = opts or {}
	return vim.fn.getreg(opts.register or M.system_register)
end

return M
