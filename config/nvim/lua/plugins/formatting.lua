if vim.g.vscode then return {} end

---@type conform.FiletypeFormatter
------Create a table of formatters for conform
------@param formatters conform.FiletypeFormatter
------@param extended { [string]: string }
---local function create_formatters(formatters, extended)
---	-- require('conform')
---
---end

if vim.g.vscode then return {} end

local prettier_format = {
	-- 'biome',
	'prettierd',
	'prettier',
	stop_after_first = true,
}

return {
	{
		-- format on save etc
		'stevearc/conform.nvim',
		event = { 'BufWritePre' },
		cmd = { 'ConformInfo' },
		init = function()
			vim.api.nvim_create_user_command('Format', function(args)
				local range = nil
				if args.count ~= -1 then
					local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
					range = {
						start = { args.line1, 0 },
						['end'] = { args.line2, end_line:len() },
					}
				end
				require('conform').format { async = true, lsp_format = 'fallback', range = range }
			end, { range = true })
		end,
		---@module "conform"
		---@type conform.setupOpts
		opts = {
			formatters_by_ft = {
				lua = { 'stylua' },
				go = { 'goimports', 'gofmt' },
				rust = { 'rustfmt' },
				zig = { 'zigfmt' },

				-- TODO: migrate null-ls
				-- formatting.rustfmt.with {
				-- 	extra_args = function(params)
				-- 		local Path = require 'plenary.path'
				-- 		local cargo_toml = Path:new(params.root .. '/' .. 'Cargo.toml')
				--
				-- 		if cargo_toml:exists() and cargo_toml:is_file() then
				-- 			for _, line in ipairs(cargo_toml:readlines()) do
				-- 				local edition = line:match [[^edition%s*=%s*%"(%d+)%"]]
				-- 				if edition then return { '--edition=' .. edition } end
				-- 			end
				-- 		end
				-- 		-- default edition when we don't find `Cargo.toml` or the `edition` in it.
				-- 		return { '--edition=2021' }
				-- 	end,
				-- },
				--

				javascript = prettier_format,
				javascriptreact = prettier_format,
				typescript = prettier_format,
				typescriptreact = prettier_format,
				css = prettier_format,
				html = prettier_format,
				json = { lsp_format = 'prefer', stop_after_first = true },
				jsonc = { lsp_format = 'prefer', stop_after_first = true },
				yaml = prettier_format,
				markdown = prettier_format,
				graphql = prettier_format,
				svelte = prettier_format,

				sh = { 'shfmt' },
				bash = { 'shfmt' },
				zsh = { 'shfmt' },

				c = { 'clang_format' },

				proto = { 'buf' },

				edn = { 'cljfmt' },
				clojure = { 'cljfmt' },

				-- applied as fallback
				['_'] = { 'trim_whitespace' },
			},
			format_on_save = { -- table must be present
				timeout_ms = 500,
				lsp_format = 'fallback',
				-- by default all formatters will be run, this flips that
				-- and can then opt in in `formatters_by_ft`
				stop_after_first = true,
			},
			formatters = {
				shfmt = {
					prepend_args = { '-i', '2' },
				},
			},
		},
	},
}
