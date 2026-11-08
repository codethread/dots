local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality

local T = MiniTest.new_set {
	hooks = {
		pre_case = function()
			child.restart { '--clean' }
			child.lua([[vim.opt.runtimepath:append(vim.env.NVIM_SMOKE_CONFIG)]])
			child.lua([[dofile(vim.env.NVIM_SMOKE_CONFIG .. '/lua/codethread/config/options.lua')]])
		end,
		post_once = child.stop,
	},
}

T['recognizes Bun scripts as TypeScript'] = function()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { '#!/usr/bin/env bun', 'console.log("smoke")' })
	eq(child.lua_get([[vim.filetype.match({ buf = 0 })]]), 'typescript')
end

return T
