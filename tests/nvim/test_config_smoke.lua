local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality

local T = MiniTest.new_set {
	hooks = {
		pre_case = function()
			child.restart { '--clean' }
			child.lua [[vim.opt.runtimepath:append(vim.env.NVIM_SMOKE_CONFIG)]]
			child.lua [[dofile(vim.env.NVIM_SMOKE_CONFIG .. '/lua/codethread/config/options.lua')]]
		end,
		post_once = child.stop,
	},
}

T['recognizes Bun scripts as TypeScript'] = function()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { '#!/usr/bin/env bun', 'console.log("smoke")' })
	eq(child.lua_get [[vim.filetype.match({ buf = 0 })]], 'typescript')
end

for name, env in pairs {
	Rex = { TERM_PROGRAM = 'rex' },
	SSH_CONNECTION = { SSH_CONNECTION = '127.0.0.1 1234 127.0.0.1 22' },
	SSH_CLIENT = { SSH_CLIENT = '127.0.0.1 1234 22' },
	SSH_TTY = { SSH_TTY = '/dev/pts/0' },
} do
	T['uses OSC52 for ' .. name] = function()
		child.lua([[
			vim.g.clipboard = nil
			vim.env.TERM_PROGRAM = nil
			vim.env.SSH_CONNECTION = nil
			vim.env.SSH_CLIENT = nil
			vim.env.SSH_TTY = nil
			for key, value in pairs(...) do vim.env[key] = value end
			dofile(vim.env.NVIM_SMOKE_CONFIG .. '/lua/codethread/config/options.lua')
		]], { env })
		eq(child.lua_get [[vim.g.clipboard]], 'osc52')
	end
end

return T
