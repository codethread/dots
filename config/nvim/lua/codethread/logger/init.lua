-- :module: Logging and notification system configuration
local M = {}

local log = require 'codethread.logger.plenarylog'

---List of loggers to use throughout config, can be controlled globally
---@type { [string]: ct.Loggers }
M.loggers = {}

---Logger for debugging my own config. Builds on plenary log but is controlled
---through `Log` ex command to change at runtime or startup
---Also supports env_var `DEBUG_CT_ ..config.plugin`, e.g `DEBUG_CT_POMO`
---@param opts ct.LogConfig
---@return ct.Logger
function M.new(opts)
	local config = log.create_config {
		plugin = opts.plugin,
		level = opts.level or os.getenv('DEBUG_CT_' .. opts.plugin:upper()) or 'error',
		use_console = opts.use_console or false,
		outfile = not opts.use_console and (vim.fn.stdpath 'cache' .. '/' .. opts.plugin .. '.log')
			or nil,
	}

	local logger = log.new(config)

	M.loggers[opts.plugin] = {
		logger = logger,
		config = config,
		file = config.outfile,
	}

	return logger
end

---Set the log level for a given logger GLOBALLY
---@param logger string
---@param level ct.LogLevels
function M.set(logger, level)
	vim.validate('logger', logger, 'string')
	vim.validate('level', level, function(l)
		local ok = vim.list_contains(log.levels, l)
		if ok then return ok end
		return ok, string.format('expected %s to be one of %s', l, table.concat(log.levels, ', '))
	end)

	local instance = M.loggers[logger]
	if not instance then
		vim.notify(
			string.format(
				'No logger with name %s, valid options: %s',
				logger,
				table.concat(vim.tbl_keys(M.loggers), ' | ')
			)
		)
	end

	local opts = vim.tbl_extend('force', instance.config, { level = level })
	M.new(opts)
end

---@class ct.Loggers
---@field logger ct.Logger instance of a logger
---@field config ct.LoggerLogInternalConfig config for reconstructing logger on level change
---@field file? string log file

---@class ct.LogConfig
---@field plugin string Name of the plugin. Prepended to log messages.
---@field use_console? boolean Will log to messages, else logs to `stdpath("cache")/plugin` [default: false]
---@field level? 'debug' | 'info' | 'error' level for logger [default: error]

---@param arg_lead string
---@param cmd_line string
---@param cursor_pos number
---@return string[]
local function completion_set(arg_lead, cmd_line, cursor_pos)
	local count = 0
	-- split on spaces to get the user typing in something Log <logger> <level>
	for _ in cmd_line:gmatch ' ' do
		count = count + 1
	end

	if count > 1 then -- show level completions
		return log.levels
	else -- show logger completions
		return vim.tbl_keys(M.loggers)
	end
end

vim.api.nvim_create_user_command('LogSet', function(opts)
	local logger = opts.fargs[1]
	local level = opts.fargs[2]
	M.set(logger, level)
end, {
	desc = 'Set the log level for a given logger GLOBALLY',
	nargs = '+',
	complete = completion_set,
})

vim.api.nvim_create_user_command('LogOpen', function(opts)
	local logger = opts.fargs[1]
	require('codethread.logger.notifications').pop(logger)
end, {
	desc = 'Open log file, includes notifications from messages',
	nargs = 1,
	complete = function() return vim.list_extend({ 'notifications' }, vim.tbl_keys(M.loggers)) end,
})

function M.select()
	local items = vim.list_extend({ 'notifications' }, vim.tbl_keys(M.loggers))
	vim.ui.select(items, {}, function(choice)
		if not choice then return end
		require('codethread.logger.notifications').pop(choice)
	end)
end

return M
