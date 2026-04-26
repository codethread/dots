-- :module: WezTerm session management and restoration
local wezterm = require 'wezterm' --[[@as Wezterm]]
local utils = require 'ct.utils'

local M = {}
local dotfiles = os.getenv 'DOTFILES' or dotfiles

local projects = utils.machine 'work'
		and {
			{
				0,
				utils.home 'dev/projects/qmk_firmware/keyboards/preonic/keymaps/codethread',
				'preonic',
			},
			{ 1, dotfiles },

			{ 2, utils.home 'work/deals-light-ui' },
			{ 3, utils.home 'work/fe-review' },
			{ 4, utils.home 'work/services/flexi-points-app' },
			{ 5, utils.home 'work/fe-native' },
			{ 6, utils.home 'dev/projects/git-tools' },
			{ 7, utils.home 'work/libraries/inspect-my-package' },
			{ 8, utils.home 'workfiles' },
			{ 9, utils.home 'work/services/protobuf' },
		}
	or {
		{
			0,
			utils.home 'dev/projects/qmk_firmware/keyboards/preonic/keymaps/codethread',
			'preonic',
		},
		{ 1, dotfiles },

		-- { 3, utils.home 'dev/projects/tstl-result' },
		-- { 4, utils.home 'dev/projects/tstl-fn' },
		{ 3, utils.home 'dev/projects/pomo' },
		-- { 5, utils.home 'dev/projects/git-tools' },

		{ 8, utils.home 'dev/projects/qmk.nvim' },
		{ 9, utils.home 'dev/projects/nuphy_firmware/keyboards/nuphy/halo75v2/ansi', 'nuphy' },
	}

---@class Sessionizer
---@field config any Override settings
---@field show fun(): nil
---@field show_active fun(): nil
---@field switch_to_most_recent fun(): nil
---@field apply_to_config fun(config: Config, default_bindings?: boolean): nil

function M.sessionizer()
	return wezterm.plugin.require 'https://github.com/mikkasendke/sessionizer.wezterm' --[[@as Sessionizer]]
end

---@param args {name: string, spawn?: { cwd?: string, args?: string[] } }
function M.switch_workspace(args)
	return wezterm.action_callback(function(win, pane)
		local sessions = wezterm.GLOBAL.sessions or { current = 'a', a = '', b = '' }

		if sessions.current == 'a' then
			sessions.current = 'b'
			sessions.b = args.name
		else
			sessions.current = 'a'
			sessions.a = args.name
		end
		wezterm.GLOBAL.sessions = sessions

		win:perform_action(wezterm.action.SwitchToWorkspace(args), pane)
	end)
end

function M.switch_last_workspace()
	return wezterm.action_callback(function(win, pane)
		local sessions = wezterm.GLOBAL.sessions or { current = 'a', a = '', b = '' }

		local name
		if sessions.current == 'a' then
			sessions.current = 'b'
			name = sessions.b
		else
			sessions.current = 'a'
			name = sessions.a
		end
		wezterm.GLOBAL.sessions = sessions

		win:perform_action(wezterm.action.SwitchToWorkspace { name = name }, pane)
	end)
end

---comment
---@param config Config
function M.apply_to_config(config)
	if not config.keys then config.keys = {} end
	for _, project in ipairs(projects) do
		local name = project[3] or utils.getFilename(project[2])
		table.insert(config.keys, {
			key = tostring(project[1]),
			mods = 'LEADER',
			action = M.switch_workspace {
				name = name,
				spawn = { cwd = project[2] },
			},
		})
	end

	local sessionizer = M.sessionizer()

	sessionizer.apply_to_config(
		config,
		true -- disable default bindings
	)
	sessionizer.config = {
		paths = {
			utils.home 'dev',
			utils.home 'work',
			utils.home '.local/share/nvim/lazy',
			utils.home '.local/share/nvim/mason/packages',
		},
		command_options = {
			fd_path = utils.bin 'fd',
			max_depth = 3,
		},
	}
end

return M
