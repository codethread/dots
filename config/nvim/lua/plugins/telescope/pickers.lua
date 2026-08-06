require 'telescope'
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local channel = require('plenary.async.control').channel
local conf = require('telescope.config').values
local finders = require 'telescope.finders'
local make_entry = require 'telescope.make_entry'
local pickers = require 'telescope.pickers'
local previewers = require 'telescope.previewers'
local sorters = require 'telescope.sorters'
local builtin = require 'telescope.builtin'

local M = {}
function M.unsaved(opts)
	opts = opts or {}
	local results = {}
	-- local diff = vim.cmd [[w !git diff --no-index -- % -]]

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local is_modified = vim.api.nvim_buf_get_option(buf, 'modified')

		if is_modified then
			local file = vim.api.nvim_buf_get_name(buf)

			table.insert(results, file)
		end
	end

	-- TODO: grab the diff using lua and push it into a buffer
	--
	-- local my_preview = previewers.new_termopen_previewer {
	-- 	get_command = function(entry, status)
	-- 		vim.print(entry)
	-- 		return { 'git', 'diff', '--no-index', '--', entry.path, '-', '<<<', 'hello code' }
	-- 	end,
	-- }

	pickers
		.new(opts, {
			prompt_title = 'unsaved',
			finder = finders.new_table {
				results = results,
				entry_maker = opts.entry_maker or make_entry.gen_from_file(opts),
			},
			sorter = conf.file_sorter(opts),
			-- TODO: could do something with the diff as preview
			previewer = conf.file_previewer(opts),
			-- previewer = my_preview,
		})
		:find()
end

local function get_workspace_symbols_requester(bufnr)
	local cwd = vim.fn.getcwd()
	local cancel = function() end

	return function(prompt)
		local tx, rx = channel.oneshot()
		cancel()
		_, cancel = vim.lsp.buf_request(bufnr, 'workspace/symbol', { query = prompt }, tx)

		-- Handle 0.5 / 0.5.1 handler situation
		local err, res = rx()
		assert(not err, err)

		local locations = vim.lsp.util.symbols_to_items(res or {}, bufnr) or {}

		return vim.tbl_filter(function(item) return vim.startswith(item.filename, cwd) end, locations)
	end
end

--- This isn't really any good
function M.workspace_symbols(opts)
	if not opts.bufnr then opts.bufnr = vim.api.nvim_get_current_buf() end

	pickers
		.new(opts, {
			prompt_title = 'LSP Dynamic Workspace Symbols',
			finder = finders.new_dynamic {
				entry_maker = make_entry.gen_from_lsp_symbols(opts),
				fn = get_workspace_symbols_requester(opts.bufnr),
			},
			previewer = conf.qflist_previewer(opts),
			sorter = sorters.highlighter_only(opts),
			attach_mappings = function(_, map)
				map('i', '<c-space>', actions.to_fuzzy_refine)
				return true
			end,
		})
		:find()
end

local function load_help_plugin(filename)
	local plugin_dir = vim.fs.dirname(vim.fs.dirname(filename))

	for _, plugin in pairs(require('lazy.core.config').plugins) do
		if plugin.dir == plugin_dir and not plugin._.loaded then
			require('lazy').load { plugins = { plugin } }
			return
		end
	end
end

function M.action_open_help_vert(prompt_bufnr)
	return function()
		local utils = require 'telescope.utils'
		local selection = action_state.get_selected_entry()
		if selection == nil then
			utils.__warn_no_selection 'builtin.help_tags'
			return
		end
		actions.close(prompt_bufnr)

		if selection.filename then load_help_plugin(selection.filename) end

		vim.cmd {
			cmd = 'help',
			args = { selection.value },
			mods = { vertical = true },
		}
	end
end

---Invoke an `fn` on the just created picker. This is likely a hack, but useful to specifiy starting prompt
---@param fn fun(picker: Picker)
function M.picker_action(fn)
	vim.schedule(function()
		local pp_b = vim.api.nvim_win_get_buf(0)
		local picker = action_state.get_current_picker(pp_b)
		fn(picker)
	end)
end

---@alias NvimSetKeymap fun( mode: string|string[] , lhs: string ,rhs: string|function, opts?: vim.keymap.set.Opts): nil

---Pass to attach_mappings and this will toggle oldfiles. Prompt text is
---preserved
---TODO: there's an abstraction in here somewhere
---@param map NvimSetKeymap
function M.builtin_oldfiles_toggle_cwd(_, map)
	local function set_prompt_text(prompt)
		if prompt and prompt ~= '' then
			M.picker_action(function(picker) picker:set_prompt(prompt) end)
		end
	end

	local function toggle_cwd(_prompt_bufnr)
		local prompt = action_state.get_current_picker(_prompt_bufnr):_get_prompt()
		actions.close(_prompt_bufnr)
		builtin.oldfiles {
			prompt_title = 'Oldfiles',
			only_cwd = false,
			attach_mappings = function(_p, _map)
				_map({ 'i', 'n' }, '<C-r>', function()
					local _prompt = action_state.get_current_picker(_p):_get_prompt()
					actions.close(_p)
					builtin.oldfiles()
					set_prompt_text(_prompt)
				end, { desc = 'Toggle cwd (on)' })

				return true
			end,
		}
		set_prompt_text(prompt)
	end

	map({ 'i', 'n' }, '<C-r>', toggle_cwd, { desc = 'Toggle cwd (off)' })

	return true
end

function M.npm_modules() end

vim.api.nvim_create_user_command('NPM', function() M.npm_modules() end, {})

--- Apply multiple greps in series, separated by `|`
--- e.g foo | bar will find all files with `foo` and then only those files will be searched for `foo`
--- @param opts any
--- TODO: handle flags
M.multi_grep = function(opts)
	opts = opts or {}
	opts.cwd = opts.cwd or vim.fs.root(0, '.git')
	opts.dynamic_preview_title = opts.dynamic_preview_title or true

	pickers
		.new(opts, {
			prompt_title = 'Multi Grep',
			finder = finders.new_async_job {
				entry_maker = make_entry.gen_from_vimgrep(opts),
				command_generator = function(prompt)
					if not prompt or vim.trim(prompt) == '' then return nil end
					local chunks = vim.iter(vim.split(prompt, '|')):map(vim.trim):totable()
					table.insert(chunks, 1, 'multi-grep')
					vim.print(chunks)
					return chunks
				end,
			},
			previewer = conf.grep_previewer(opts), -- defaults to above
			sorter = sorters.highlighter_only(opts), -- TODO: need to adjust the highlight to only use the `grep` bit
		})
		:find()
end

return M
