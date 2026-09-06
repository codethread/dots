local M = {}

local function multi_grep_command(query)
	local patterns = vim.iter(vim.split(query, '|', { plain = true })):map(vim.trim):totable()
	local search_pattern = patterns[#patterns]
	table.insert(patterns, 1, 'multi-grep')

	local command = table.concat(vim.tbl_map(vim.fn.shellescape, patterns), ' ')
	return command, search_pattern
end

local function live_grep_command(query, _, opts)
	local chunks = vim.split(query, '  ', { plain = true })
	local literal = query:sub(1, 1) == '`'
	local pattern_input = literal and chunks[1]:sub(2) or chunks[1]
	local pattern_parts = vim.split(vim.trim(pattern_input), '%s+', { trimempty = true })
	local pattern = table.concat(pattern_parts, literal and ' ' or '.*')
	local directories = vim.split(vim.trim(chunks[2] or ''), '%s+', { trimempty = true })
	local flags = vim.split(vim.trim(chunks[3] or ''), '%s+', { trimempty = true })
	local command = {
		'rg',
		'--vimgrep',
		'--smart-case',
		'--glob-case-insensitive',
	}

	if opts.hidden then table.insert(command, '--hidden') end
	if opts.follow then table.insert(command, '--follow') end
	if opts.no_ignore then table.insert(command, '--no-ignore') end
	if literal then table.insert(command, '--fixed-strings') end

	for _, directory in ipairs(directories) do
		table.insert(command, '--glob')
		if directory:sub(1, 1) == '!' then
			table.insert(command, '!**/' .. directory:sub(2) .. '/**')
		else
			table.insert(command, '**/' .. directory .. '/**')
		end
	end

	vim.list_extend(command, flags)
	table.insert(command, '--')
	table.insert(command, pattern)

	return table.concat(vim.tbl_map(vim.fn.shellescape, command), ' '), pattern
end

function M.unsaved(opts)
	opts = vim.tbl_deep_extend('force', {
		show_unlisted = true,
		show_unloaded = true,
		winopts = { title = 'Unsaved' },
		filter = function(bufnr) return vim.bo[bufnr].modified end,
	}, opts or {})

	require('fzf-lua').buffers(opts)
end

function M.oldfiles(opts)
	opts = opts or {}
	local cwd_only = opts.cwd_only ~= false
	local title = cwd_only and 'Oldfiles (cwd)' or 'Oldfiles'

	opts = vim.tbl_deep_extend('force', {
		cwd_only = cwd_only,
		header = '<ctrl-r> toggle cwd',
	}, opts)
	opts.winopts = vim.tbl_deep_extend('force', opts.winopts or {}, { title = title })
	opts.actions = vim.tbl_deep_extend('force', opts.actions or {}, {
		['ctrl-r'] = {
			header = 'toggle cwd',
			fn = function(_, action_opts)
				M.oldfiles(vim.tbl_deep_extend('force', {}, opts, {
					cwd_only = not cwd_only,
					query = action_opts.last_query,
				}))
			end,
		},
	})

	require('fzf-lua').oldfiles(opts)
end

function M.multi_grep(opts)
	opts = vim.tbl_deep_extend('force', {
		cwd = vim.fs.root(0, '.git'),
		winopts = { title = 'Multi Grep' },
		rg_glob = false,
		fn_transform_cmd = multi_grep_command,
	}, opts or {})

	require('fzf-lua').live_grep(opts)
end

function M.live_grep(opts)
	opts = vim.tbl_deep_extend('force', {
		cwd = vim.fs.root(0, '.git'),
		header = 'pattern  directories  flags; prefix pattern with ` for literal search',
		winopts = { title = 'Live Grep' },
		rg_glob = false,
		fn_transform_cmd = live_grep_command,
	}, opts or {})

	require('fzf-lua').live_grep(opts)
end

return M
