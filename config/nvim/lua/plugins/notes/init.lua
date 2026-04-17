if true then return {} end

local constants = require 'plugins.notes.constants'

vim.filetype.add {
	extension = {
		dataview = 'mysql',
		dataviewjs = 'javascript',
	},
}

return {

	{
		'epwalsh/obsidian.nvim',
		lazy = true,
		enabled = false, -- taking a step back from the world
		cond = constants.has_notes,
		event = {
			'BufReadPre ' .. constants.pattern,
			'BufNewFile ' .. constants.pattern,
		},
		dependencies = { 'nvim-lua/plenary.nvim' },
		cmd = { 'ObsidianWorkspace', 'ObsidianToday', 'ObsidianQuickSwitch' },
		init = function()
			-- set.conceallevel = 0 -- So that I can see `` in markdown files
			vim.opt.conceallevel = 2 -- while trying obsidian
			--[[stylua: ignore]] --format
			Keys.localleader_ft('markdown', {
	{ 'j', 'Table ⬇', function() require('plugins.notes.fns').table_swap_down() end  },
	{ 'k', 'Table ⬆', function() require('plugins.notes.fns').table_swap_up() end    },
	{ 'h', 'Table ⇽', function() require('plugins.notes.fns').table_swap_left() end  },
	{ 'l', 'Table ⇾', function() require('plugins.notes.fns').table_swap_right() end },
			})
		end,
		opts = function()
			local theme = require 'codethread.theme'
			return {
				workspaces = {
					U.machine {
						work = {
							name = 'work',
							path = constants.cwd,
						},
						home = {
							name = 'personal',
							path = constants.cwd,
						},
					},
				},

				notes_subdir = 'inbox',

				daily_notes = {
					folder = 'journal',
					template = 'daily.md',
				},

				new_notes_location = 'notes_subdir',
				-- new_notes_location = 'current_dir', --inline with PARA

				completion = {
					min_chars = 1,
				},

				-- open notes split if there isn't already a split
				open_notes_in = 'vsplit',

				follow_url_func = function(url) vim.fn.jobstart { 'open', url } end,

				templates = {
					subdir = 'templates',
					date_format = '%Y-%m-%d',
					time_format = '%H:%M',
					substitutions = {
						-- TODO ObsidianTomorrow will have wrong date, should use a hacky autcmd to just replace everything
						friendly_date = function() return os.date '%B %-d, %Y' end,
					},
				},

				-- wiki_link_func = function(opts)
				-- 	return require('plugins.notes.fns').wiki_link_func(opts)
				-- end,

				-- this prevents new files having silly names
				note_id_func = function(title) return title end,

				disable_frontmatter = true,

				callbacks = {
					post_setup = function() require('plugins.notes.backup').init() end,

					-- Runs right before writing the buffer for a note.
					---@param _ obsidian.Client
					---@param note obsidian.Note
					pre_write_note = function(_, note)
						local fname = note:fname()
						require('plugins.notes.fns').check_name_clash { fname }
					end,
				},

				picker = {
					mappings = { new = '<C-n>' },
				},
				ui = {
					hl_groups = {
						-- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
						ObsidianTodo = { bold = true, fg = theme.notes.todo_fg },
						ObsidianDone = { bold = true, fg = theme.notes.done_fg },
						ObsidianRightArrow = { bold = true, fg = theme.notes.right_arrow_fg },
						ObsidianTilde = { bold = true, fg = theme.notes.tilde_fg },
						ObsidianBullet = { bold = true, fg = theme.notes.bullet_fg },
						ObsidianRefText = { underline = true, fg = theme.notes.ref_text_fg },
						ObsidianExtLinkIcon = { fg = theme.notes.ext_link_icon_fg },
						ObsidianTag = { italic = true, fg = theme.notes.tag_fg },
						ObsidianBlockID = { italic = true, fg = theme.notes.block_id_fg },

						-- NOTE: shouldn't need all the others, but they don't get merged
						ObsidianHighlightText = {
							bg = theme.notes.highlight_bg,
							fg = theme.notes.highlight_fg,
						},
					},
				},
			}
		end,
	},
}
