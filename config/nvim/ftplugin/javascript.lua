vim.opt_local.spell = true
vim.opt_local.spelloptions:append 'camel'
vim.opt_local.spellcapcheck = ''

if vim.g.vscode then return end

local keymapper = require 'codethread.keymaps.keymapper'

local function fix_all()
	vim.lsp.buf.code_action {
		context = { only = { 'source.fixAll' } },
		apply = true,
	}
end

--[[stylua: ignore]] --format
keymapper.localleader {
	{ 'g' , 'Find Modules'       , function() require('codethread.find_node_module').find_node_module() end },
	{ 'cc', 'Clear logs'         , Cmd '%g/console/norm dd'                                                 },
	{ 's' , 'Swap ternary'       , function() require('swap-ternary').swap() end                            },
	{ 'a' , 'fix all'            , fix_all                                                                 },
}
