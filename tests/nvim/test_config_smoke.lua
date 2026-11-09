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

T['CodeDiff'] = MiniTest.new_set {
	hooks = {
		pre_case = function()
			child.lua [[
				_G.U = { machine = function(values) return values.home end }
				for _, spec in ipairs(require('plugins.git')) do
					if spec[1] == 'esmuellert/codediff.nvim' then _G.codediff_spec = spec end
				end
				package.loaded.codediff = {
					setup = function(opts) _G.codediff_opts = opts end,
				}
			]]
		end,
	},
}

T['CodeDiff']['chooses the initial layout from editor columns'] = function()
	for _, case in ipairs {
		{ 120, 'inline' },
		{ 199, 'inline' },
		{ 200, 'side-by-side' },
		{ 300, 'side-by-side' },
	} do
		child.o.columns = case[1]
		child.lua [[_G.codediff_spec.config(nil, _G.codediff_spec.opts)]]
		eq(child.lua_get [[_G.codediff_opts.diff.layout]], case[2])
		eq(child.lua_get [[_G.codediff_opts.keymaps.view.toggle_stage]], '<leader>c')
	end
	-- Reconfiguration replaces the resize handler rather than accumulating callbacks.
	eq(child.lua_get [[#vim.api.nvim_get_autocmds({ group = 'CodeDiffLayout' })]], 1)
end

T['CodeDiff']['updates the default after resizing in either direction'] = function()
	child.o.columns = 199
	child.lua [[_G.codediff_spec.config(nil, _G.codediff_spec.opts)]]
	child.o.columns = 240
	child.api.nvim_exec_autocmds('VimResized', {})
	eq(child.lua_get [[_G.codediff_opts.diff.layout]], 'side-by-side')
	child.o.columns = 199
	child.api.nvim_exec_autocmds('VimResized', {})
	eq(child.lua_get [[_G.codediff_opts.diff.layout]], 'inline')
	eq(child.lua_get [[_G.codediff_opts.keymaps.view.toggle_stage]], '<leader>c')
end

return T
