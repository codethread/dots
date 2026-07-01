-- :module: Telescope fuzzy finder plugin configuration
if vim.g.vscode then return {} end

return {
	{
		'nvim-telescope/telescope.nvim',
		cmd = 'Telescope',
		dependencies = {
			{
				'nvim-telescope/telescope-ui-select.nvim',
				init = function()
					-- handle vim.ui.select being invoked and lazy triggering our input
					---@diagnostic disable-next-line: duplicate-set-field
					vim.ui.select = function(...)
						require 'telescope'
						vim.ui.select(...)
					end
				end,
			},
			{ 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
			{ 'nvim-telescope/telescope-live-grep-args.nvim' },
			{ 'catgoose/telescope-helpgrep.nvim' },
		},
		config = function(_, opts)
			opts = opts or {}
			local telescope = require 'telescope'
			local actions = require 'telescope.actions'
			local action_layout = require 'telescope.actions.layout'
			local custom = require 'plugins.telescope.pickers'

			local options = vim.tbl_deep_extend('force', opts, {
				defaults = {
					-- ui
					layout_strategy = 'flex',
					layout_config = {
						height = { padding = 1 },
						width = { padding = 2 },
						horizontal = {
							-- mirror = true,
							preview_cutoff = 160,
							preview_width = { 0.6, min = 80, max = 120 + 2 },
						},
						vertical = {
							width = { 0.99, max = 120 + 2 },
							mirror = true,
							preview_height = 0.4,
							preview_cutoff = 1,
						},
					},
					prompt_prefix = '   ',
					selection_caret = '  ',
					entry_prefix = '  ',
					initial_mode = 'insert',
					path_display = { 'truncate' },
					color_devicons = true,
					dynamic_preview_title = true,
					mappings = {
						i = {
							['<C-n>'] = actions.cycle_history_next,
							['<C-p>'] = actions.cycle_history_prev,

							['<C-j>'] = actions.move_selection_next,
							['<C-k>'] = actions.move_selection_previous,

							['<C-c>'] = actions.close,

							['<Down>'] = actions.move_selection_next,
							['<Up>'] = actions.move_selection_previous,

							['<CR>'] = actions.select_default,
							['<C-x>'] = actions.select_horizontal,
							['<C-v>'] = actions.select_vertical,
							['<C-t>'] = actions.select_tab,

							['<C-u>'] = actions.preview_scrolling_up,
							['<C-d>'] = actions.preview_scrolling_down,

							['<PageUp>'] = actions.results_scrolling_up,
							['<PageDown>'] = actions.results_scrolling_down,

							['<Tab>'] = actions.toggle_selection + actions.move_selection_worse,
							['<S-Tab>'] = actions.toggle_selection + actions.move_selection_better,
							['<C-q>'] = actions.send_to_qflist + actions.open_qflist,
							['<M-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
							['<C-l>'] = actions.complete_tag,
							['<C-_>'] = actions.which_key, -- keys from pressing <C-/>
							['<M-p>'] = action_layout.toggle_preview,
							['<C-Space>'] = actions.to_fuzzy_refine, -- this is awesome

							['<C-i>'] = require('telescope-live-grep-args.actions').quote_prompt {
								postfix = ' --iglob ',
							},
						},

						n = {
							['<esc>'] = actions.close,
							['<CR>'] = actions.select_default,
							['<C-x>'] = actions.select_horizontal,
							['<C-v>'] = actions.select_vertical,
							['<C-t>'] = actions.select_tab,

							['<Tab>'] = actions.toggle_selection + actions.move_selection_worse,
							['<S-Tab>'] = actions.toggle_selection + actions.move_selection_better,
							['<C-q>'] = actions.send_to_qflist + actions.open_qflist,
							['<M-q>'] = actions.send_selected_to_qflist + actions.open_qflist,

							['j'] = actions.move_selection_next,
							['k'] = actions.move_selection_previous,
							['H'] = actions.move_to_top,
							['M'] = actions.move_to_middle,
							['L'] = actions.move_to_bottom,

							['<Down>'] = actions.move_selection_next,
							['<Up>'] = actions.move_selection_previous,
							['gg'] = actions.move_to_top,
							['G'] = actions.move_to_bottom,

							['<C-u>'] = actions.preview_scrolling_up,
							['<C-d>'] = actions.preview_scrolling_down,

							['<PageUp>'] = actions.results_scrolling_up,
							['<PageDown>'] = actions.results_scrolling_down,

							['?'] = actions.which_key,
							['<M-p>'] = action_layout.toggle_preview,

							['D'] = actions.delete_buffer, -- only for buffers, see if better way todo
							['>'] = action_layout.cycle_layout_next,
							[']'] = actions.cycle_previewers_next,

							['<M-l>'] = action_layout.toggle_mirror,
						},
					},

					-- these are lua patterns
					file_ignore_patterns = U.flatten {
						U.project('~/dev/projects/qmk.nvim', { 'lua/qmk/lib/' }),
						U.project('~/dev/projects/skein-src', { 'devflow/archive/' }),
					},
					vimgrep_arguments = {
						'rg',
						'--color=never',
						'--no-heading',
						'--with-filename',
						'--line-number',
						'--column',
						'--smart-case',
						'--hidden',
					},
					cache_picker = {
						num_pickers = 2, -- store 2 in history for making nested pickers
					},
				},
				pickers = {
					find_files = {
						find_command = {
							'rg',
							'--files',
							'--follow', -- this might break so be caerful, adding to view symlinked ingored code like claude.md
							'--hidden', -- this might break so be caerful, adding to view symlinked ingored code like claude.md
						},
					},
					diagnostics = {
						path_display = 'hidden',
					},
					oldfiles = {
						layout_config = { horizontal = { mirror = false } },
						prompt_title = 'Oldfiles (cwd)',
						only_cwd = true,
						attach_mappings = custom.builtin_oldfiles_toggle_cwd,
					},
					help_tags = {
						attach_mappings = function(prompt_bufnr)
							actions.select_default:replace(custom.action_open_help_vert(prompt_bufnr))
							return true
						end,
					},
				},
				extensions = {
					helpgrep = {
						ignore_paths = {
							vim.fn.stdpath 'state' .. '/lazy/readme',
						},
						-- mappings = {
						--   i = {
						--     ["<CR>"] = actions.select_default,
						--     ["<C-v>"] = actions.select_vertical,
						--   },
						--   n = {
						--     ["<CR>"] = actions.select_default,
						--     ["<C-s>"] = actions.select_horizontal,
						--   }
						-- },
						-- default_grep = builtin.live_grep,
					},
					['ui-select'] = {
						require('telescope.themes').get_dropdown {
							-- even more opts
						},
					},
				},
			})

			telescope.setup(options)

			telescope.load_extension 'live_grep_args'
			telescope.load_extension 'fzf'
			telescope.load_extension 'helpgrep'
			telescope.load_extension 'ui-select'
		end,
	},
}
