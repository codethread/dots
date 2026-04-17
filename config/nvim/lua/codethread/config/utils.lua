local M = {}

---Get a deeply nested field from table `t`
---@param t table
---@param ... string keys to dig into table
---@return any | nil
---@deprecated builtin
function M.dig(t, ...)
	for _, k in ipairs { ... } do
		t = t[k]
		if not t then return nil end
	end
	return t
end

---@param client string
---@param on_attach fun(client, buffer)
function M.lsp_attach(client, on_attach)
	vim.api.nvim_create_autocmd('LspAttach', {
		callback = function(args)
			local buffer = args.buf
			local current_client = vim.lsp.get_client_by_id(args.data.client_id)
			if client == '*' or client == current_client.name then on_attach(current_client, buffer) end
		end,
	})
end

M.augroups = {}
M.augroups.lsp_formatting = vim.api.nvim_create_augroup('LspFormatting', {})

---@param tool_list string[] list of tools to install, e.g { tsserver, eslintd }
---@return table
function M.tools_lsp(tool_list)
	return {
		'williamboman/mason-lspconfig.nvim',
		opts = function(_, opts)
			local o = opts or {}
			o.ensure_installed = vim.list_extend(o.ensure_installed or {}, tool_list)
			return o
		end,
	}
end

---@param tool_list string[] list of tools to install, e.g { tsserver, eslintd }
---@return table
function M.tools_null(tool_list)
	return {
		'williamboman/mason-null-ls.nvim',
		opts = function(_, opts)
			local o = opts or {}
			o.ensure_installed = vim.list_extend(o.ensure_installed or {}, tool_list)
			return o
		end,
	}
end

function M.file_exits(path)
	local p = vim.fs.normalize(path)
	return vim.fn.isdirectory(p) == 1
end

---Get current visual selection
---@see M.get_visual_to_cursor
---@param opts? { trim?: boolean }
function M.get_visual_selection(opts)
	local pos = vim.api.nvim_win_get_cursor(0)
	opts = opts or { trim = false }
	-- Yank current visual selection into the 'v' register
	-- Note that this makes no effort to preserve this register
	vim.cmd 'noau silent normal! "vy"'
	vim.api.nvim_win_set_cursor(0, pos)
	local t = vim.split(vim.fn.getreg 'v', '\n')
	return opts.trim and vim.iter(t):map(vim.trim):totable() or t
end

---Get current visual selection up to cursor
---@see M.get_visual_selection
function M.get_visual_to_cursor()
	local _, ls, cs = unpack(vim.fn.getpos 'v')
	local _, le, ce = unpack(vim.fn.getpos '.')

	-- nvim_buf_get_text requires start and end args be in correct order
	ls, le = math.min(ls, le), math.max(ls, le)
	cs, ce = math.min(cs, ce), math.max(cs, ce)

	local s = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
	for _, value in ipairs(s) do
		dd(value)
	end
end

---@return number row, number column
function M.current_pos()
	local c = vim.api.nvim_win_get_cursor(0)
	return c[1], c[2]
end

---@param specss LazyPluginSpec[][]
---@return LazyPluginSpec[]
function M.flatten(specss)
	local collection = {}
	for _, plugins in ipairs(specss) do
		for _, plugin in ipairs(plugins) do
			table.insert(collection, plugin)
		end
	end
	return collection
end

M.ecma_ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }

M.LazyFile = { 'BufReadPost', 'BufNewFile', 'BufWritePre' }

---@param specs LazyPluginSpec[]
function M.F(specs) return specs end

function M.project(path, settings)
	if vim.fn.getcwd() == vim.fn.expand(path) then
		return settings
	else
		return {}
	end
end

---pattern match on home or work
---@generic A : any
---@param match { work?: A, home?: A }
---@return A
function M.machine(match)
	local user = os.getenv 'CT_USER'
	return match[user] or {}
end

---Get current file relative to cwd
---@return string
function M.get_current_file()
	local Path = require 'plenary.path'
	local full_path = vim.fn.expand '%:p'
	return Path:new(full_path):make_relative()
end

-----------------------------------------------------------------------------------
-- Keybindings / mappings
-----------------------------------------------------------------------------------
function M.command(desc, lhs, rhs, arg_count)
	vim.api.nvim_buf_create_user_command(arg_count or 0, lhs, rhs, { desc = desc })
end

local default_augroup = vim.api.nvim_create_augroup('codethread', { clear = true })
---@type table<string, number?> # map of descriptions to autocmds
local aus = {}

--- Options for autocmds
--- @class ct.au_opts
--- @field buffer? integer
--- @field group? integer|string
--- @field once? boolean
--- @field pattern? string|string[]

--- @param desc string docstring
--- @param events string[] Event(s) that will trigger the handler (`callback` or `command`).
--- @param fn fun(args: vim.api.keyset.create_autocmd.callback_args): boolean?
--- @param opts? ct.au_opts
function M.au(desc, events, fn, opts)
	-- TODO: write script to grab events from docs
	-- TODO: make this smarter, use patterns and events for smarter deletes if desc changes
	local old = aus[desc]
	if old then vim.api.nvim_del_autocmd(old) end
	opts = opts or {}
	local au = vim.api.nvim_create_autocmd(
		events,
		vim.tbl_deep_extend('force', {
			group = opts.group or default_augroup,
			desc = desc,
			callback = fn,
		}, opts)
	)
	aus[desc] = au
end

---Run a nushell command using `vim.system`
---@overload fun(nu_block: string, opts?: vim.SystemOpts): vim.SystemCompleted
---@overload fun(nu_block: string, opts: vim.SystemOpts, on_exit: fun(res: vim.SystemCompleted)): vim.SystemObj
function M.nush(nu_block, opts, on_exit)
	local cmd =
		{ 'nu', '--no-std-lib', '--no-history', '--error-style=plain', '-c', vim.trim(nu_block) }
	opts = vim.tbl_extend('force', { text = true }, opts or {})
	if on_exit then
		return vim.system(cmd, opts, on_exit)
	else
		return vim.system(cmd, opts):wait()
	end
end

-- function M.nush(nu_block) return "nush '" .. nu_block:gsub('\n', '; ') .. "'" end

---Recurse through a project till a marker is hit or return `nil`
---@param markers string | string[]
---@param opts? { silent?: boolean }
---@return string?
function M.find_lsp_root(markers, opts)
	opts = opts or {}
	---@cast markers string[]
	markers = type(markers) == 'string' and { markers } or markers
	local base = vim.fs.root(0, markers)
	if not base then
		if not opts.silent then
			vim.notify(
				string.format('markers "%s" not found', table.concat(markers, ', ')),
				vim.log.levels.WARN
			)
		end
		return nil
	end
	if #base <= #vim.uv.os_homedir() then
		if not opts.silent then
			vim.notify(
				string.format('found a marker but it was in the home_dir or less "%s"', base),
				vim.log.levels.WARN
			)
		end
		return nil
	end
	return base
end

---comment
---@param file string
function M.run_ftplugin(file)
	local file_path = vim.fs.joinpath('ftplugin', file)
	local runtime_files = vim.api.nvim_get_runtime_file(file_path, true)
	Try {
		function()
			assert(
				#runtime_files == 1,
				string.format(
					'expected one runtime file for %s but got "%s"',
					file,
					table.concat(runtime_files)
				)
			)
			dofile(runtime_files[1])
		end,
	}
end

function M.git_root() return vim.fs.root(0, '.git') end

return M
