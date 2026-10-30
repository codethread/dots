local projects = require("projects")
local config = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/rex"
local terminal = "com.superlogical.terminal"

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
	local path = args.value
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
	local path = projects.slots()[projects.slot_index(args.slot)]
	assert(path ~= "", "Empty slot: use Ctrl+A h " .. args.slot .. " to assign it")
	return assert(rex.invoke("dots_project", { value = path }))
end, { slot = "integer" })

action("dots_assign", "Assign Directory to Project Slot", function(ctx, args)
	local slots = projects.slots()
	slots[projects.slot_index(args.slot)] = cwd(ctx)
	projects.save(slots)
end, { slot = "integer" })

action("dots_add", "Append Directory to Project Slots", function(ctx)
	local slots, path = projects.slots(), cwd(ctx)
	for _, existing in ipairs(slots) do
		if existing == path then
			return
		end
	end
	slots[#slots + 1] = path
	projects.save(slots)
end)

action("dots_seed", "Reseed Project Slots from Tmux Configuration", function()
	projects.seed()
end)
action("dots_slots", "Pick Project Slot", function(ctx)
	local rows = {}
	for i, path in ipairs(projects.slots()) do
		if path ~= "" then
			rows[#rows + 1] = path .. "\t" .. (i <= 10 and i % 10 or i) .. "  " .. path
		end
	end
	return picker(ctx, rows, "dots_project", "Slot: ")
end)
action("dots_edit_slots", "Edit Project Slots", function()
	projects.slots()
	return assert(rex.session.new_layer({
		bounds = { 0.1, 0.1, 0.8, 0.8 },
		focus = true,
		layout = shell({
			command = { "env", "NVIM_APPNAME=minimal-nvim", os.getenv("EDITOR") or "nvim", projects.state },
		}),
	}))
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
	bind("h>" .. slot, "dots_assign", { slot = slot })
end
bind("h>a", "dots_add")
bind("h>e", "dots_edit_slots")
bind("h>l", "dots_slots")
bind("h>r", "dots_seed")
bind("n", "dots_new_tab")
bind("'", "dots_tabs")
bind("shift+tab", "client.tab.previous")
bind("backspace", "client.tab.close")
bind("o", "dots_close_other_tabs")
rex.bind("ctrl+alt+z", "client.tab.previous")
rex.bind("ctrl+alt+x", "client.tab.next")
rex.bind("ctrl+alt+left", "client.tab.move", { direction = "backward" })
rex.bind("ctrl+alt+right", "client.tab.move", { direction = "forward" })
