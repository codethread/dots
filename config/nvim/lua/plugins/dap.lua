if vim.g.vscode then return {} end

return {
	{
		'mfussenegger/nvim-dap',
		dependencies = {
			'nvim-neotest/nvim-nio',
			{
				'rcarriga/nvim-dap-ui',
				dependencies = { 'nvim-neotest/nvim-nio' },
				config = function()
					local dap, dapui = require 'dap', require 'dapui'
					dapui.setup {}

					local function close_dap_windows()
						for _, win in ipairs(vim.api.nvim_list_wins()) do
							local buf = vim.api.nvim_win_get_buf(win)
							local ft = vim.bo[buf].filetype
							if ft:match '^dapui_' or ft:match '^dap_' then vim.api.nvim_win_close(win, true) end
						end
						dapui.close()
					end

					-- Auto close UI on session end
					dap.listeners.before.event_terminated['dapui_config'] = close_dap_windows
					dap.listeners.before.event_exited['dapui_config'] = close_dap_windows

					vim.api.nvim_create_user_command('DapWin', function(opts)
						local el = dapui.elements[opts.args]
						if not el then
							vim.notify('Unknown element: ' .. opts.args, vim.log.levels.ERROR)
							return
						end

						-- vsplit if only one window, otherwise use current
						if #vim.api.nvim_tabpage_list_wins(0) == 1 then vim.cmd 'vsplit' end

						vim.api.nvim_win_set_buf(0, el.buffer())
					end, {
						nargs = 1,
						complete = function(arg_lead)
							local elements =
								{ 'scopes', 'stacks', 'watches', 'breakpoints', 'repl', 'console', 'disassembly' }
							return vim.tbl_filter(function(e) return e:find(arg_lead, 1, true) == 1 end, elements)
						end,
					})
				end,
			},
			{
				'theHamsta/nvim-dap-virtual-text',
				dependencies = { 'nvim-treesitter/nvim-treesitter' },
				opts = {},
			},
			{
				'Jorenar/nvim-dap-disasm',
				dependencies = 'rcarriga/nvim-dap-ui',
				opts = {
					columns = { 'instruction' },
				},
			},
		},
		keys = {
			{ '<F5>', function() require('dap').continue() end, desc = 'Debug: Continue' },
			{ '<F10>', function() require('dap').step_over() end, desc = 'Debug: Step Over' },
			{ '<F11>', function() require('dap').step_into() end, desc = 'Debug: Step Into' },
			{ '<F12>', function() require('dap').step_out() end, desc = 'Debug: Step Out' },
			-- leader keys defined in codethread/keymaps/leader.lua
			{
				'<leader>db',
				function() require('dap').toggle_breakpoint() end,
				desc = 'Toggle Breakpoint',
			},
		},
		config = function()
			local dap = require 'dap'

			local function find_js_debug()
				-- Mason location
				local mason_path = vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js'
				if vim.fn.filereadable(mason_path) == 1 then return mason_path end
				-- nix: js-debug-adapter puts the entry point at the bin path
				local nix_bin = vim.fn.exepath('js-debug-adapter')
				if nix_bin ~= '' then return nix_bin end
				return mason_path -- fallback
			end

			-- codelldb adapter (Zig, C, C++, Rust)
			-- exepath resolves from PATH, works whether installed by Mason or nix
			dap.adapters.codelldb = {
				type = 'server',
				port = '${port}',
				executable = {
					command = vim.fn.exepath('codelldb'),
					args = { '--port', '${port}' },
				},
			}

			-- Zig configuration
			dap.configurations.zig = {
				{
					name = 'Launch',
					type = 'codelldb',
					request = 'launch',
					program = function()
						return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/zig-out/bin/', 'file')
					end,
					cwd = '${workspaceFolder}',
					stopOnEntry = false,
					args = {},
				},
			}

			-- C/C++ configuration
			dap.configurations.c = dap.configurations.zig
			dap.configurations.cpp = dap.configurations.zig

			-- js-debug-adapter (TypeScript, JavaScript)
			dap.adapters['pwa-node'] = {
				type = 'server',
				host = 'localhost',
				port = '${port}',
				executable = {
					command = 'node',
					args = {
						find_js_debug(),
						'${port}',
					},
				},
			}

			local js_config = {
				{
					type = 'pwa-node',
					request = 'launch',
					name = 'Launch file',
					program = '${file}',
					cwd = '${workspaceFolder}',
				},
				{
					type = 'pwa-node',
					request = 'attach',
					name = 'Attach',
					processId = require('dap.utils').pick_process,
					cwd = '${workspaceFolder}',
				},
			}

			dap.configurations.javascript = js_config
			dap.configurations.typescript = js_config
			dap.configurations.javascriptreact = js_config
			dap.configurations.typescriptreact = js_config

			-- Signs for breakpoints
			vim.fn.sign_define(
				'DapBreakpoint',
				{ text = 'B', texthl = 'DapBreakpoint', linehl = '', numhl = '' }
			)
			vim.fn.sign_define(
				'DapBreakpointCondition',
				{ text = 'C', texthl = 'DapBreakpointCondition', linehl = '', numhl = '' }
			)
			vim.fn.sign_define(
				'DapStopped',
				{ text = '>', texthl = 'DapStopped', linehl = 'DapStopped', numhl = '' }
			)
		end,
	},

	-- Ensure debug adapters are installed via Mason (skipped on NixOS where they come from nix)
	{
		'WhoIsSethDaniel/mason-tool-installer.nvim',
		opts = function(_, opts)
			local is_nixos = vim.fn.filereadable('/etc/NIXOS') == 1
			if is_nixos then return end
			opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
				'codelldb',
				'js-debug-adapter',
			})
		end,
	},
}
