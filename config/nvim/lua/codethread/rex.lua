-- Rex's app actions need an explicit client when multiple apps are connected.
local backend = require 'smart-splits-backend-rex'
local cli = require 'smart-splits-backend-rex.rex'
local move = backend.move
local resize = backend.resize

return vim.tbl_extend('force', backend, {
	move = function(direction, opts)
		local result = assert(
			cli.run {
				'do',
				'-e',
				[[
for _, window in ipairs(assert(rex.session.view {}).windows) do
  if window.zoomed_block_id == rex.block_id then return { zoomed = true } end
end
return { zoomed = false }
]],
			},
			'Cannot query Rex zoom state'
		)
		assert(result.code == 0, result.stderr)
		-- Decline the handoff so smart-splits keeps navigation inside Neovim.
		if vim.json.decode(result.stdout).zoomed then return false end
		return move(direction, opts)
	end,
	resize = function(direction, opts)
		local result = assert(
			cli.run {
				'do',
				'-e',
				'return assert(rex.session.describe_block { block_id = rex.block_id }).block.owner',
			},
			'Cannot query Rex pane owner'
		)
		assert(result.code == 0, result.stderr)
		vim.env.REX_CLIENT = assert(vim.json.decode(result.stdout), 'Rex pane has no owning client')
		return resize(direction, opts)
	end,
})
