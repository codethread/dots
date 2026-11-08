local config_root = assert(vim.env.NVIM_SMOKE_CONFIG, 'NVIM_SMOKE_CONFIG is required')
local dependency_root = assert(vim.env.NVIM_SMOKE_DEP, 'NVIM_SMOKE_DEP is required')
local test_file = assert(vim.env.NVIM_SMOKE_TEST, 'NVIM_SMOKE_TEST is required')

vim.opt.runtimepath:append(config_root)
vim.opt.runtimepath:append(dependency_root)

require('mini.test').setup {
	collect = {
		find_files = function() return { test_file } end,
	},
}
