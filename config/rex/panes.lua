local M = {}
local terminal = "com.superlogical.terminal"

function M.layer(ctx)
	for _, window in ipairs(assert(rex.session.view({})).windows) do
		for _, layer in ipairs(window.layers) do
			for index, block in ipairs(layer.blocks) do
				if block.block_id == ctx.block_id then
					return layer, index
				end
			end
		end
	end
	error("The focused pane is not placed in a window")
end

function M.swap(ctx, args)
	local layer, index = M.layer(ctx)
	local target = args.offset == 0 and 1 or (index - 1 + args.offset) % #layer.blocks + 1
	if target == index then
		return
	end
	return assert(rex.session.swap_blocks({ block_id = ctx.block_id, other_block_id = layer.blocks[target].block_id }))
end

local function rect(node, block)
	if node.block_id == block then
		return node.rect
	end
	if node.split then
		return rect(node.split.before, block) or rect(node.split.after, block)
	end
end

local function main_ratio(mode, columns, rows)
	if mode == "fat" then
		if rows <= 35 then
			return 0.5
		end
		if rows <= 50 then
			return 0.55
		end
		return 0.6
	end
	if columns <= 120 then
		return 0.55
	end
	if columns <= 160 then
		return 0.6
	end
	if columns <= 220 then
		return 0.65
	end
	if columns <= 280 then
		return 0.7
	end
	return 0.75
end

function M.layout(ctx, args)
	local layer = M.layer(ctx)
	local blocks = layer.blocks
	if #blocks < 2 then
		return
	end
	local mode = args.mode
	if mode == "toggle" then
		mode = layer.layout.split.direction == "horizontal" and "fat" or "tall"
	end
	local main, secondary = blocks[1].block_id, blocks[2].block_id
	local size = assert(rex.block.call(terminal, "size", { block_id = main }))
	local bounds = assert(rect(layer.layout, main))
	local ratio = main_ratio(mode, size.columns / bounds[3], size.rows / bounds[4])
	local direction = mode == "tall" and "horizontal" or "vertical"
	assert(rex.session.move_block({
		block_id = secondary,
		anchor_block_id = main,
		direction = direction,
		side = "after",
		ratio = ratio,
	}))
	for i = 3, #blocks do
		assert(rex.session.move_block({
			block_id = blocks[i].block_id,
			anchor_block_id = blocks[i - 1].block_id,
			direction = mode == "tall" and "vertical" or "horizontal",
			side = "after",
			ratio = 1 / (#blocks - i + 2),
		}))
	end
	assert(rex.session.resize_pane({
		before_block_id = main,
		after_block_id = secondary,
		direction = direction,
		ratio = ratio,
	}))
	return assert(rex.session.focus_block({ block_id = ctx.block_id }))
end

return M
