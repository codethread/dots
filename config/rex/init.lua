local terminal = "com.superlogical.terminal"
local data = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
dofile(data .. "/nvim/lazy/smart-splits-backend-rex/rex/lua/smart-splits-rex/init.lua").setup({
	resize_amount = 3,
})

local function cwd(ctx)
	local process = assert(rex.block.call(terminal, "process", { block_id = ctx.block_id }))
	return assert(
		(process.foreground and process.foreground.cwd) or (process.child and process.child.cwd),
		"Cannot read this terminal's directory"
	)
end

local function shell(options)
	return rex.layout.block({ flavor = terminal .. ".shell", options = options })
end

local function action(name, title, run, args)
	rex.action({ name = name, title = title, category = "Dots", run = run, args = args or {} })
end

local function bind(key, name, args)
	rex.bind("ctrl+a>" .. key, name, args)
end

-- Run filesystem operations beside the terminal, even when config Lua is local
-- to an attached client connected to another server.
local function host_action(name, title, operation, args)
	action(name, title, function(ctx, values)
		return assert(rex.session.new_layer({
			bounds = { 0.1, 0.15, 0.8, 0.7 },
			focus = true,
			layout = shell({
				command = {
					"bash",
					"-c",
					'exec bash ~/.config/rex/session.sh "$@"',
					"rex-session",
					operation,
					assert(ctx.block_id),
					tostring(values.slot or values.value or ""),
				},
				shell = "none",
			}),
		}))
	end, args)
end

host_action("dots_project", "Open Project Session", "open", { value = "string" })
host_action("dots_projects", "Pick Project Session", "projects")
host_action("dots_slot", "Jump to Project Slot", "slot", { slot = "integer" })
host_action("dots_assign", "Assign Directory to Project Slot", "assign", { slot = "integer" })
host_action("dots_add", "Append Directory to Project Slots", "add")
host_action("dots_seed", "Reseed Project Slots from Tmux Configuration", "seed")
host_action("dots_slots", "Pick Project Slot", "slots")
host_action("dots_edit_slots", "Edit Project Slots", "edit")
host_action("dots_tabs", "Pick Tab", "tabs")

action("dots_new_tab", "New Tab in Current Directory", function(ctx)
	return assert(rex.session.new_window({ layout = shell({ cwd = cwd(ctx) }) }))
end)
action("dots_close_other_tabs", "Close Other Tabs", function()
	local view = assert(rex.session.view({}))
	for _, window in ipairs(view.windows) do
		if window.window_id ~= view.active_window_id then
			assert(rex.session.close_window({ window_id = window.window_id }))
		end
	end
end)

local function split(ctx, direction, ratio)
	return assert(rex.session.new_split({
		anchor_id = ctx.block_id,
		direction = direction,
		side = "after",
		ratio = ratio,
		focus = true,
		layout = shell({ cwd = cwd(ctx) }),
	}))
end

action("dots_split", "Split Pane in Current Directory", function(ctx, args)
	return split(ctx, args.direction, 0.5)
end, { direction = "string" })

action("dots_split_or_zoom", "Split Single Pane or Toggle Zoom", function(ctx)
	for _, window in ipairs(assert(rex.session.view({})).windows) do
		for _, layer in ipairs(window.layers) do
			for _, block in ipairs(layer.blocks) do
				if block.block_id == ctx.block_id then
					if layer.kind == "tiled" and #layer.blocks == 1 then
						return split(ctx, "horizontal", 0.6)
					end
					return assert(rex.session.zoom_block({ block_id = ctx.block_id }))
				end
			end
		end
	end
end)

bind("ctrl+a", "pane.send_key", { key = "ctrl+a" })
bind("r", "client.config.reload")
bind("ctrl+r", "client.config.reload")
bind("shift+r", "client.tab.rename")
bind("s", "session.switch")
bind("p", "session.switch")
bind("f", "dots_projects")
bind("shift+n", "session.new")
-- Rex currently exposes ordered navigation rather than last-used history.
bind("tab", "session.previous")
bind("shift+backspace", "session.close")
rex.mode("slots", { exclusive = true })
bind("h", "client.mode.enter", { name = "slots", once = true })
for slot = 0, 9 do
	bind(tostring(slot), "dots_slot", { slot = slot })
	rex.bind("slots/" .. slot, "dots_assign", { slot = slot })
end
rex.bind("slots/a", "dots_add")
rex.bind("slots/e", "dots_edit_slots")
rex.bind("slots/l", "dots_slots")
rex.bind("slots/r", "dots_seed")
rex.bind("slots/q", "client.mode.exit")
rex.bind("slots/ctrl+c", "client.mode.exit")
bind("n", "dots_new_tab")
bind("'", "dots_tabs")
bind("shift+tab", "client.tab.previous")
bind("backspace", "client.tab.close")
bind("o", "dots_close_other_tabs")
rex.bind("ctrl+alt+z", "client.tab.previous")
rex.bind("ctrl+alt+x", "client.tab.next")
rex.bind("ctrl+alt+left", "client.tab.move", { direction = "backward" })
rex.bind("ctrl+alt+right", "client.tab.move", { direction = "forward" })

bind("shift+\\", "dots_split", { direction = "horizontal" })
bind("-", "dots_split", { direction = "vertical" })
bind("space", "dots_split_or_zoom")
bind("x", "pane.close")
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
	rex.bind("ctrl+" .. key, "smart_splits_focus", { direction = direction, key = "ctrl+" .. key })
	rex.bind("alt+" .. key, "smart_splits_resize", { direction = direction, key = "alt+" .. key })
	bind("shift+" .. key, "pane.resize", { direction = direction, amount = 2 })
end
