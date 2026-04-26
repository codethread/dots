--- The dotty module exposes wrappers and autocmds around my `dotty` cli tool
--- for managing dotfiles (see `dotty --help`).
local M = {}

local log = require('codethread.logger.init').new { plugin = 'dotty' }

local in_dotfiles = false

---notify at info level
---@param msg string
local function dotty_info(msg)
	log.info('info msg:', msg)
	vim.schedule(
		function()
			vim.notify(msg, vim.log.levels.INFO, {
				title = 'Dotty',
				hide_from_history = true,
			})
		end
	)
end

---Run dotty link
---@return nil
function M.dotty_link()
	if not in_dotfiles then return nil end
	log.info 'link running'

	U.nush([[use ct/dotty; dotty link | dotty format | to json -r]], {}, function(res)
		log.info 'link complete'
		log.debug('res:', res)
		if res.code ~= 0 then
			log.error(res.stderr)
		else
			log.debug(res.stdout)
			---@type { changes: boolean, diff: string }
			local changes = vim.json.decode(res.stdout)
			if changes.changes then dotty_info(changes.diff) end
		end
	end)
end

local function setup_autocmds()
	log.info 'setting up autocmds'
	vim.api.nvim_create_user_command('Dotty', function() M.dotty_link() end, {})

	vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufFilePost', 'VimLeavePre' }, {
		desc = 'Run dotty when saving and deleting buffers',
		pattern = vim.fn.getcwd() .. '/*',
		group = vim.api.nvim_create_augroup('Dotty', { clear = true }),
		callback = function(opts)
			log.info 'autocmd run'
			log.debug('autocmd', opts)
			if
				opts.file == nil
				or opts.match == nil
				or vim.startswith(opts.match:gsub(vim.fn.getcwd() .. '/', ''), 'Neogit')
			then
				log.debug 'autocmd early return'
				return
			end

			M.dotty_link()
		end,
	})
end

function M.init()
	if vim.fn.executable 'nu' == 1 then
		log.info 'nu available'
		local root = vim.fs.root(0, '.git')
		if not root then
			log.info 'not in git project'
			return
		end

		U.nush([[use ct/dotty; dotty is-cwd ]] .. root .. [[ --exit]], {}, function(res)
			log.debug('is-cwd res:', res)
			if res.code == 0 then
				log.info 'in dotfiles'
				in_dotfiles = true
				vim.schedule(setup_autocmds)
			end
		end)
	else
		log.warn 'nu not present in PATH for dotty'
	end
end

--test
-- require('plenary.reload').reload_module 'codethread.dotty'
-- require('plenary.reload').reload_module 'codethread.log'
-- require('codethread.dotty').init()
-- log.info '------------restart'

return M
