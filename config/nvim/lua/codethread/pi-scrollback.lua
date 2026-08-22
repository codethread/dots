local scrollback_file = vim.env.PI_SCROLLBACK_FILE
local save_marker = vim.env.PI_SCROLLBACK_SAVE_MARKER

if not scrollback_file or not save_marker then return end

local function is_scrollback_buffer(buffer)
	local realpath = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(buffer))
	return realpath == vim.uv.fs_realpath(scrollback_file)
end

vim.api.nvim_create_autocmd('BufReadPost', {
	callback = function(event)
		if not is_scrollback_buffer(event.buf) then return end
		local marker_line = vim.fn.search('<!-- pi:prompt:start -->', 'nw')
		if marker_line > 0 then
			vim.api.nvim_win_set_cursor(0, { marker_line + 1, 0 })
			vim.cmd.startinsert()
		end
	end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
	callback = function(event)
		if is_scrollback_buffer(event.buf) then vim.fn.writefile({ 'saved' }, save_marker) end
	end,
})
