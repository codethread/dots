local projects = require("projects")
local panes = require("panes")
local config = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/rex"
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

local function picker(ctx, rows, name, prompt)
	local path = projects.exec({ "mktemp", "/tmp/rex-picker.XXXXXX" }):gsub("%s+$", "")
	local f = assert(io.open(path, "w"))
	assert(f:write(table.concat(rows, "\n") .. "\n"))
	assert(f:close())
	return assert(rex.session.new_layer({
		bounds = { 0.1, 0.15, 0.8, 0.7 },
		focus = true,
		layout = shell({
			command = { "bash", config .. "/picker.sh", path, assert(ctx.client_id), name, prompt },
			shell = "none",
		}),
	}))
end

action("dots_project", "Open Project Session", function(_, args)
	local path = projects.expand(args.value)
	local name = assert(path:match("([^/]+)/?$")):gsub("%.", "_")
	local id
	for _, session in ipairs(assert(rex.call("session.list")).sessions) do
		if session.label == name then
			assert(not id, "Multiple sessions named " .. name)
			id = session.session_id
		end
	end
	if not id then
		projects.exec({ "test", "-d", path })
		id = assert(rex.call(
			"session.create",
			{ label = name, initial_windows = {
				{ window_label = "main", layout = shell({ cwd = path }) },
			} }
		)).session_id
	end
	rex.client.queue("session.select", { session_id = id })
	return { session_id = id }
end, { value = "string" })

action("dots_projects", "Pick Project Session", function(ctx)
	local rows = {}
	for _, path in ipairs(projects.paths()) do
		rows[#rows + 1] = path .. "\t" .. path
	end
	return picker(ctx, rows, "dots_project", "Project: ")
end)

action("dots_slot", "Jump to Project Slot", function(_, args)
	local path = projects.slots[args.slot]
	assert(path, "Slot " .. args.slot .. " is not configured in rex/projects.lua")
	return assert(rex.invoke("dots_project", { value = path }))
end, { slot = "integer" })

action("dots_slots", "Pick Project Slot", function(ctx)
	local rows = {}
	for i = 1, 10 do
		local slot = i % 10
		local path = projects.slots[slot]
		if path then
			rows[#rows + 1] = path .. "\t" .. slot .. "  " .. path
		end
	end
	return picker(ctx, rows, "dots_project", "Slot: ")
end)

action("dots_new_tab", "New Tab in Current Directory", function(ctx)
	return assert(rex.session.new_window({ layout = shell({ cwd = cwd(ctx) }) }))
end)
action("dots_focus_tab", "Focus Picked Tab", function(_, args)
	return assert(rex.session.focus_window({ window_id = args.value }))
end, { value = "string" })
action("dots_tabs", "Pick Tab", function(ctx)
	local rows = {}
	for i, window in ipairs(assert(rex.session.view({})).windows) do
		rows[#rows + 1] = window.window_id .. "\t" .. i .. "  " .. window.label
	end
	return picker(ctx, rows, "dots_focus_tab", "Tab: ")
end)
action("dots_close_other_tabs", "Close Other Tabs", function()
	local view = assert(rex.session.view({}))
	for _, window in ipairs(view.windows) do
		if window.window_id ~= view.active_window_id then
			assert(rex.session.close_window({ window_id = window.window_id }))
		end
	end
end)

action("dots_swap_pane", "Swap Pane", panes.swap, {
	type = "object",
	required = { "offset" },
	additionalProperties = false,
	properties = { offset = { type = "integer", enum = { -1, 0, 1 } } },
})
action("dots_layout", "Arrange Main Pane Layout", panes.layout, {
	type = "object",
	required = { "mode" },
	additionalProperties = false,
	properties = { mode = { type = "string", enum = { "tall", "fat", "toggle" } } },
})
action("dots_swap_selected", "Swap with Picked Pane", function(_, args)
	local source, target = args.value:match("^(%S+) (%S+)$")
	assert(source and target, "Expected two pane IDs")
	assert(rex.session.swap_blocks({ block_id = source, other_block_id = target }))
	return assert(rex.session.focus_block({ block_id = source }))
end, { value = "string" })
action("dots_panes", "Pick Pane to Swap", function(ctx)
	local rows = {}
	for i, window in ipairs(assert(rex.session.view({})).windows) do
		for _, layer in ipairs(window.layers) do
			for j, block in ipairs(layer.blocks) do
				if block.block_id ~= ctx.block_id then
					rows[#rows + 1] = string.format(
						"%s %s\t%d.%d  %s  %s",
						ctx.block_id,
						block.block_id,
						i,
						j,
						window.label,
						block.label
					)
				end
			end
		end
	end
	if #rows == 0 then
		return
	end
	return picker(ctx, rows, "dots_swap_selected", "Swap pane: ")
end)
action("dots_history", "Open Scrollback in Neovim", function(ctx)
	return assert(rex.session.new_window({
		window_label = "history",
		layout = shell({
			command = {
				"bash",
				"-c",
				[[set -o pipefail
rex capture -b "$1" --trim --unwrap |
  nvim -u NONE -R -c 'set clipboard=unnamedplus' -c 'nnoremap q <Cmd>qa!<CR>' -c 'normal! G' -]],
				"rex-history",
				ctx.block_id,
			},
		}),
	}))
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
for slot = 0, 9 do
	bind(tostring(slot), "dots_slot", { slot = slot })
end
bind("h>l", "dots_slots")
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
bind("shift+]", "dots_swap_pane", { offset = 1 })
bind("shift+[", "dots_swap_pane", { offset = -1 })
bind("m", "dots_swap_pane", { offset = 0 })
bind("j", "dots_panes")
bind("b", "pane.move_to_new_tab")
bind("shift+b", "pane.move_to_tab")
bind("=", "dots_layout", { mode = "tall" })
bind("enter", "dots_layout", { mode = "toggle" })
bind("shift+=", "pane.balance")
bind("[", "dots_history")
bind("shift+o", "dots_history")
bind("shift+s", "dots_history")
bind("shift+/", "client.palette.toggle")
bind("/", "client.find.open")
bind("pageup", "client.prompt.previous")
bind("pagedown", "client.prompt.next")
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
	rex.bind("ctrl+" .. key, "smart_splits_focus", { direction = direction, key = "ctrl+" .. key })
	rex.bind("alt+" .. key, "smart_splits_resize", { direction = direction, key = "alt+" .. key })
	bind("shift+" .. key, "pane.resize", { direction = direction, amount = 2 })
end
