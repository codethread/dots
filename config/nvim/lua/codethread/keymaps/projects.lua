-- Project based keymaps
local root = U.git_root()
local dotfiles = vim.env.DOTFILES or vim.fn.expand '~/dev/dots'
local p = function(path) return root == vim.fn.expand(path) end

---comment
---@param cmd string[]
---@param opts? { reload?: boolean, after?: function }
local function run(cmd, opts)
	opts = opts or {}
	return function()
		vim.notify(table.concat(cmd, ' '))
		vim.system(cmd, { text = true }, function(out)
			if out.code ~= 0 then
				dd(out)
			else
				if opts.reload then vim.schedule(vim.cmd.e) end
			end
		end)
	end
end

if root == dotfiles then
	Keys.list({ prefix = '<leader>p' }, {
		{ 'p', 'lint', function() print 'hey' end },
	})
elseif p '~/dev/projects/pomo' then
	print 'hello projec'
elseif p '~/dev/projects/git-nudge' then

	--[[stylua: ignore]] --format
	Keys.list({ prefix = '<leader>p' }, {
		{ 'l', 'lint', run({ 'pnpm', 'lint' }, { reload = true }) },
		{ 'g', 'gen', run { 'pnpm', 'gen' }, { after = function() vim.cmd.expand 'src/graphql/gql.ts' end }, },
	})
end
