local function picker(name)
	return function() require('plugins.fzf.pickers')[name]() end
end

return {
	{
		'ibhagwan/fzf-lua',
		cmd = { 'FzfLua', 'FzfMG' },
		keys = {
			{ '<leader><leader>', '<cmd>FzfLua files<cr>', desc = 'Files' },
			{ '<leader>;', '<cmd>FzfLua commands<cr>', desc = 'Commands' },
			{ '<leader>,', '<cmd>FzfLua resume<cr>', desc = 'Resume' },
			{ '<leader>fl', '<cmd>FzfLua buffers<cr>', desc = 'List buffers' },
			{ '<leader>fr', picker 'oldfiles', desc = 'Recent files' },
			{ '<leader>fu', picker 'unsaved', desc = 'Unsaved buffers' },
			{ '<leader>sf', '<cmd>FzfLua blines<cr>', desc = 'Buffer search' },
			{ '<leader>sk', '<cmd>FzfLua keymaps<cr>', desc = 'Keymaps' },
			{ '<leader>sl', '<cmd>FzfLua lsp_document_symbols<cr>', desc = 'Document symbols' },
			{
				'<leader>sL',
				function() require('fzf-lua').lsp_live_workspace_symbols { cwd_only = true } end,
				desc = 'Workspace symbols',
			},
			{ '<leader>sm', picker 'multi_grep', desc = 'Multi grep' },
			{ '<leader>sp', picker 'live_grep', desc = 'Live grep' },
			{ '<leader>sr', '<cmd>FzfLua registers<cr>', desc = 'Registers' },
			{ '<leader>hh', '<cmd>FzfLua helptags<cr>', desc = 'Help' },
		},
		opts = function()
			return {
				'ivy',
				files = { hidden = true, follow = true },
				grep = { hidden = true },
				helptags = {
					actions = { enter = require('fzf-lua.actions').help_vert },
				},
			}
		end,
		config = function(_, opts)
			require('fzf-lua').setup(opts)
			vim.api.nvim_create_user_command('FzfMG', function()
				require('plugins.fzf.pickers').multi_grep()
			end, {})
			vim.keymap.set({ "i" }, "<C-x><C-f>",
  function()
    FzfLua.complete_file({
      cmd = "rg --files",
      winopts = { preview = { hidden = true } }
    })
  end, { silent = true, desc = "Fuzzy complete file" })
		end,
	},
}
