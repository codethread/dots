-- :module: Neovim configuration entry point and module loader
-- require 'codethread.alt'
require 'codethread.keymaps.leader'
require 'codethread.keymaps.normal'
require 'codethread.keymaps.commands'
require 'codethread.keymaps.projects'

if not vim.g.vscode then
	require 'codethread.movement'
	require 'codethread.xstate'
	require 'codethread.nushell'
	require 'codethread.diagnostics'
	local pomo = require 'codethread.pomo'
	local is_work = U.machine {
		work = true,
	}

	if is_work == true then pomo.setup() end
end
