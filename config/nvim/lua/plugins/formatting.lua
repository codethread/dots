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

local function has_config(bufnr, names)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local start = filename ~= '' and vim.fs.dirname(filename) or vim.uv.cwd()

	return vim.fs.find(names, {
		path = start,
		upward = true,
		type = 'file',
	})[1] ~= nil
end

local function package_uses_prettier(bufnr)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local start = filename ~= '' and vim.fs.dirname(filename) or vim.uv.cwd()

	for _, package_json in ipairs(vim.fs.find('package.json', {
		path = start,
		upward = true,
		type = 'file',
	})) do
		local package = vim.json.decode(table.concat(vim.fn.readfile(package_json), '\n'))
		if package.prettier ~= nil then return true end
	end

	return false
end

local function web_formatters(bufnr)
	if has_config(bufnr, { 'biome.json', 'biome.jsonc' }) then
		return { 'biome', stop_after_first = true }
	end

	if has_config(bufnr, {
		'.prettierrc',
		'.prettierrc.json',
		'.prettierrc.json5',
		'.prettierrc.yaml',
		'.prettierrc.yml',
		'.prettierrc.toml',
		'.prettierrc.js',
		'.prettierrc.cjs',
		'.prettierrc.mjs',
		'.prettierrc.ts',
		'prettier.config.js',
		'prettier.config.cjs',
		'prettier.config.mjs',
		'prettier.config.ts',
	}) or package_uses_prettier(bufnr) then
		return { 'prettierd', 'prettier', stop_after_first = true }
	end

	return { 'oxfmt', stop_after_first = true }
end

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

				javascript = web_formatters,
				javascriptreact = web_formatters,
				typescript = web_formatters,
				typescriptreact = web_formatters,
				css = web_formatters,
				html = web_formatters,
				json = { lsp_format = 'prefer', stop_after_first = true },
				jsonc = { lsp_format = 'prefer', stop_after_first = true },
				yaml = web_formatters,
				markdown = web_formatters,
				graphql = web_formatters,
				svelte = web_formatters,

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
