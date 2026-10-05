local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local sorters = require 'telescope.sorters'
local make_entry = require 'telescope.make_entry'
-- this is the user's conf
local conf = require('telescope.config').values

local M = {}

---Live grep with ripgrep shortcuts
---
---Sections are chunked by double space '  ', chunks are then split by single
---space ' '
--- - chunk 1: grep pattern
--- - chunk 2: globs
--- - chunk 3: flags
---
---Grep patterns:
---	- chunk starting with backtick ` will be treated as literal `-F`, e.g ``foo bar` => `"foo bar" -F`
--- - split inputs are chained i.e `foo bar` => `foo.*bar`
--- - quoted inputs are left i.e `'foo bar'` => `foo bar`
---
---Globs are automatically created from simple inputs
---	- `apps` => `{**/apps,**/apps/**}` (a path component at any depth, or anything below it)
---	- `apps foo` => `{**/apps,**/apps/**}` `{**/foo,**/foo/**}`
---	- `!` negates glob, `!apps` => `!{**/apps,**/apps/**}`
---
---	Flags are passed to rg verbatim, e.g. `-Tmd` (exclude markdown by type)
---	(TODO: short expansions: i => -i, h => --hidden)
---@param opts any
M.live_grepper = function(opts)
	local action_state = require 'telescope.actions.state'

	opts = opts or {}
	opts.cwd = opts.cwd or vim.fs.root(0, '.git')
	opts.dynamic_preview_title = opts.dynamic_preview_title or true

	local parts = function(input)
		return (not input or vim.trim(input) == '') and {} or vim.split(input, ' ')
	end

	local cmd = {}

	pickers
		.new(opts, {
			prompt_title = 'Live Grep (*)',
			finder = finders.new_async_job {
				entry_maker = make_entry.gen_from_vimgrep(opts),
				command_generator = function(prompt)
					if not prompt or vim.trim(prompt) == '' then return nil end

					local chunks = vim.split(prompt, '  ')

					local is_literal = string.sub(prompt, 1, 1) == '`'
					local _grep = parts(is_literal and string.sub(chunks[1], 2) or chunks[1])
					local _dirs = parts(chunks[2])
					local _flags = parts(chunks[3])

					local grep = table.concat(_grep, is_literal and ' ' or '.*')
					local dirs = vim
						.iter(_dirs)
						:map(function(dir)
							if vim.startswith(dir, '!') then
								local glob = string.sub(dir, 2)
								return { '-g', string.format('!{**/%s,**/%s/**}', glob, glob) }
							end
							return { '-g', string.format('{**/%s,**/%s/**}', dir, dir) }
						end)
						:flatten(1)
						:totable()

					dirs = vim.tbl_isempty(dirs) and nil or dirs

					cmd = {
						'rg',
						'--vimgrep',
						'--smart-case',
						'--glob-case-insensitive',
						-- TODO: -e/--regexp for handling flags
						grep,
					}

					if is_literal then table.insert(cmd, '-F') end

					if not vim.tbl_isempty(dirs) then
						for _, glob in ipairs(dirs) do
							table.insert(cmd, glob)
						end
					end

					for _, flag in ipairs(_flags) do
						table.insert(cmd, flag)
					end

					do
						local prompt_bufnr = vim.api.nvim_get_current_buf()
						local current_picker = action_state.get_current_picker(prompt_bufnr)
						local title_parts = {
							(is_literal and 'Fixed grep: ' or 'Grep: ') .. grep,
						}
						if not vim.tbl_isempty(dirs) then
							table.insert(title_parts, string.format('Globs: %s', table.concat(dirs, ' ')))
						end
						if not vim.tbl_isempty(_flags) then
							table.insert(title_parts, string.format('Flags: %s', table.concat(_flags, ' ')))
						end
						current_picker.prompt_border:change_title(table.concat(title_parts, '| '))
					end

					return cmd
				end,
			},
			previewer = conf.grep_previewer(opts), -- defaults to above
			sorter = sorters.highlighter_only(opts), -- TODO: need to adjust the highlight to only use the `grep` bit
		})
		:find()
end

return M
