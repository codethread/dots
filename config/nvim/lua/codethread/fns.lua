local M = {}

---Open the next file in the directory tree (alphabetically).
---Useful in the context of running a macro over files in a directory
function M.open_next_file()
	local found = false
	local iter = vim.iter(vim.fs.dir(vim.fn.expand '%:h'))

	local next = iter:find(function(name, type)
		local current = vim.fn.expand '%:t'
		if found and type == 'file' then
			found = false
			return true
		elseif type == 'file' and name == current then
			found = true
		end
	end)
	if not next then
		error('no more files', 0)
	else
		local to = vim.fn.expand '%:h' .. '/' .. next
		vim.cmd.e(to)
	end
end

---Save the current buffer, but also handles oil buffers
function M.save_buffer()
	local ft = vim.bo.filetype
	if ft == 'oil' then
		local ok, oil = pcall(require, 'oil')
		assert(ok, 'no oil!')
		oil.save(nil, function(err)
			if err then
				vim.notify(err, vim.log.levels.ERROR, { title = 'Oil' })
			else
				require('codethread.dotty').dotty_link()
				local path = string.gsub(vim.fn.expand '%', 'oil://', '')
				require('plugins.notes.backup').update_and_push('renames', path)
			end
		end)

		-- too annoying as it alters jump list
		-- elseif vim.tbl_contains({ 'typescript', 'typescriptreact', 'javascript' }, ft) then
		-- 	require('vtsls').commands.remove_unused_imports(
		-- 		vim.api.nvim_get_current_buf(),
		-- 		function() vim.cmd.w() end,
		-- 		function(e)
		-- 			dd(e)
		-- 			vim.cmd.w()
		-- 		end
		-- 	)
	else
		vim.cmd.w()
	end
end

function M.test_current_file()
	local ft = vim.bo.filetype
	if ft == 'lua' then
		vim.cmd 'w'
		-- require('plenary.test_harness').test_directory(vim.fn.expand '%:p')
		require('plenary.test_harness').test_directory(
			vim.fn.expand '%:p',
			-- if writing lua tests, I'll follow the same setup as https://github.com/m00qek/plugin-template.nvim
			{ minimal_init = 'test/spec.vim' }
		)
		-- also PlenaryTestFile
	elseif ft == 'javascript' then
		local jest = require 'jester'
		jest.run_last { path_to_jest = './node_modules/bin/jest' }
	elseif ft == 'go' then
		-- vim.Cmd.GoTestFunc()
		vim.cmd.GoTestSubCase()
	else
		print('no setup for filetype: ' .. ft)
	end
end

function M.store_to_clipboard(str)
	if type(str) ~= 'string' then
		vim.notify 'should be string!'
		return
	end
	local register = vim.fn.has 'mac' == 1 and '*' or '+'
	vim.fn.setreg(register, str)
	vim.notify 'saved to clipboard'
end

function M.debounce(ms, fn)
	local timer = vim.uv.new_timer()
	return function(...)
		local argv = { ... }
		timer:start(ms, 0, function()
			timer:stop()
			vim.schedule_wrap(fn)(unpack(argv))
		end)
	end
end

---Show listchars to see things like tabs/spaces and trailing lines
function M.toggle_listchars()
	local state = vim.b.ct_debug_spacing or false
	if state then
		vim.b.ct_debug_spacing = false
		vim.cmd 'set nolist'
		vim.api.nvim_set_hl(0, 'Whitespace', { fg = U.hl 'base' })
	else
		vim.b.ct_debug_spacing = true
		vim.cmd 'set list'
		vim.api.nvim_set_hl(0, 'Whitespace', { fg = U.hl 'leaf' })
	end
end

function M.toggle_linewrap()
	if vim.opt_local.wrap:get() then
		vim.opt_local.wrap = false
		vim.keymap.del('n', 'j')
		vim.keymap.del('n', 'k')
	else
		vim.opt_local.wrap = true
		vim.keymap.set('n', 'j', 'gj')
		vim.keymap.set('n', 'k', 'gk')
	end
end

function M.toggle_diagnostics()
	local state = vim.b.ct_diagnostics_off or true
	if state then
		vim.diagnostic.hide()
		vim.b.ct_diagnostics_off = true
	else
		vim.diagnostic.show()
		vim.b.ct_diagnostics_off = false
	end
end

function M.toggle_file_history()
	local is_diff = vim.startswith(vim.fn.expand '%', 'diffview://')
	if is_diff then
		vim.cmd [[DiffviewClose]]
	else
		vim.cmd [[DiffviewFileHistory % --no-merges]]
	end
end

function M.worktree_open_alt()
	U.nush(
		[[git worktree list | parse '{p} {sha} {branch}' | str trim | get p | to text]],
		{},
		vim.schedule_wrap(function(out)
			local wks = vim.split(out.stdout, '\n')
			local str = require 'lib.str'
			local full_path = vim.fn.expand '%:p'
			local buffer_path = vim.fn.expand '%'
			assert(buffer_path ~= full_path, 'paths should not be equal') -- sometimes this happens and not sure why
			local wktrs = vim
				.iter(wks)
				:filter(function(wk) return not str(full_path):includes(wk) end)
				:totable()
			vim.ui.select(
				wktrs,
				{},
				function(choice) vim.cmd.vsplit(vim.fs.joinpath(choice, buffer_path)) end
			)
		end)
	)
end

function M.reload_snippets()
	require('luasnip.loaders.from_vscode').load {
		paths = {
			'~/.config/nvim/snippets_vscode',
			'~/.local/share/nvim/lazy/friendly-snippets',
		},
	}
end

function M.git_reset_buffer()
	require('gitsigns').reset_buffer()
	vim.cmd [[noa w]]
end

function M.toggle_quickfix()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(vim.api.nvim_get_current_tabpage())) do
		if vim.fn.getwinvar(win, '&syntax') == 'qf' then
			vim.cmd.cclose()
			return
		end
	end
	vim.cmd.copen()
end

---take raw ripgrep --vimgrp output and convert to quickfix items
---@param stdout string
---@return vim.quickfix.entry[]?
function M.ripgrep_to_quickfix(stdout)
	local root = vim.fn.getcwd()
	local s = vim.trim(stdout)
	if not s or s == '' then return nil end
	return vim
		.iter(vim.split(s, '\n'))
		:map(function(item)
			local file, line, col, text = unpack(vim.split(item, ':'))
			return {
				text = text,
				col = tonumber(col),
				end_col = #text,
				filename = file,
				lnum = tonumber(line),
				user_data = {
					uri = 'file://' .. vim.fs.joinpath(root, file), -- for use with LSP results
				},
			} --[[@as vim.quickfix.entry]]
		end)
		:totable()
end

---append items to quickfix, dedupes. This will be slow on a large list
---@param entries vim.quickfix.entry[]
function M.append_to_quickfix(entries)
	---@type vim.quickfix.entry[]
	local existing = vim.fn.getqflist()
	local lsp_result = vim.tbl_get(entries[1], 'user_data', 'uri') and true or false

	---@type vim.quickfix.entry[]
	local append = {}

	for _, e in ipairs(entries) do
		local should_add = true
		for _, ex in ipairs(existing) do
			if
				ex.lnum == e.lnum --
				-- and ex.col == e.col -- tends to be different by source
				and ex.end_col == e.end_col -- currently using as use case works, but may need to expand, or make the ripgrep_to_quickfix take a col adjustment fn
				and (
					lsp_result -- lsp results don't store filename, instead nest it as uri
						and ex.user_data.uri == e.user_data.uri
					or (ex.filename == e.filename)
				)
				-- and ex.text == e.text
			then
				should_add = false
				break
			end
		end
		if should_add then table.insert(append, e) end
	end
	vim.fn.setqflist({}, 'a', { items = append })
end

function M.yank_current_file()
	local root = vim.fs.root(0, '.git')
	local cur = vim.fn.expand '%:p'
	if not root or not cur then return end
	local str = vim.fs.relpath(root, cur, {})
	M.store_to_clipboard(str)
	return str
end

function M.yank_absolute_path()
	local path = vim.fn.expand '%:p'
	if not path or path == '' then return end
	M.store_to_clipboard(path)
	return path
end

function M.yank_home_relative_path()
	local path = vim.fn.expand '%:p'
	if not path or path == '' then return end
	local home = vim.fn.expand '~'
	local str = path:gsub('^' .. vim.pesc(home), '~')
	M.store_to_clipboard(str)
	return str
end

function M.save_register_to_clipboard()
	-- Get it as a list of lines
	-- local lines = vim.fn.getreg('"', 1, 1)
	-- Get the register type as well (characterwise, linewise, blockwise)
	local type, content = vim.fn.getregtype '"', vim.fn.getreg '"'
	if type ~= 'v' then vim.notify 'hmm' end
	M.store_to_clipboard(content)
end

function M.yank_gitlab_url()
	local root = vim.fs.root(0, '.git')
	local cur = vim.fn.expand '%:p'
	if not root or not cur then return end
	
	local rel_path = vim.fs.relpath(root, cur, {})
	
	-- Get git remote URL
	local remote_result = vim.system({ 'git', 'remote', 'get-url', 'origin' }, { cwd = root }):wait()
	if remote_result.code ~= 0 then
		vim.notify('Failed to get git remote', vim.log.levels.ERROR)
		return
	end
	
	local remote_url = vim.trim(remote_result.stdout)
	
	-- Parse GitLab URL from git remote
	-- Supports both SSH (git@host:path/repo.git) and HTTPS (https://host/path/repo.git)
	local gitlab_host, repo_path
	
	-- Try SSH format first: git@host:path/repo.git
	gitlab_host, repo_path = remote_url:match('^git@([^:]+):(.+)%.git$')
	
	-- Try HTTPS format if SSH didn't match: https://host/path/repo.git
	if not gitlab_host then
		gitlab_host, repo_path = remote_url:match('^https?://([^/]+)/(.+)%.git$')
	end
	
	if not gitlab_host or not repo_path then
		vim.notify('Could not parse git remote URL: ' .. remote_url, vim.log.levels.ERROR)
		return
	end
	
	-- Get current branch
	local branch_result = vim.system({ 'git', 'branch', '--show-current' }, { cwd = root }):wait()
	if branch_result.code ~= 0 then
		vim.notify('Failed to get current branch', vim.log.levels.ERROR)
		return
	end
	
	local branch = vim.trim(branch_result.stdout)
	
	-- Construct GitLab URL
	local gitlab_url = string.format(
		'https://%s/%s/-/blob/%s/%s',
		gitlab_host,
		repo_path,
		branch,
		rel_path
	)
	
	M.store_to_clipboard(gitlab_url)
	return gitlab_url
end

return M
