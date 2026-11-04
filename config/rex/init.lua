local projects = require("projects")
local panes = require("panes")
require("theme")
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

-- A home-server callback may target a session on another server. Forward the
-- entire operation, not just its Rex calls: io/exec must run on the session host.
local function host_action(name, title, run, args)
	action("dots_host_" .. name, title .. " (Host)", run, args)
	action("dots_" .. name, title, function(ctx, values)
		if not ctx.server then
			return run(ctx, values)
		end
		local reply = assert(rex.call("client.action", {
			action = "dots_host_" .. name,
			session_id = ctx.session_id,
			block_id = ctx.block_id,
			args = values,
		}))
		for _, queued in ipairs(reply.client_actions or {}) do
			rex.client.queue(queued.action, queued.args)
		end
		return reply.result
	end, args)
end

local function picker(ctx, rows, name, prompt)
	if #rows == 0 then
		return
	end
	local source = assert(rex.session.describe_block({ block_id = ctx.block_id })).block
	local path = projects.exec({ "mktemp", "/tmp/rex-picker.XXXXXX" }):gsub("%s+$", "")
	local f = assert(io.open(path, "w"))
	assert(f:write(table.concat(rows, "\n") .. "\n"))
	assert(f:close())
	local layer, err = rex.session.new_layer({
		window_id = assert(source.window_id),
		bounds = { 0.1, 0.15, 0.8, 0.7 },
		focus = true,
		layout = shell({
			command = {
				"/bin/bash",
				config .. "/picker.sh",
				path,
				assert(ctx.client_id),
				assert(ctx.session_id),
				assert(ctx.block_id),
				name,
				prompt,
			},
			shell = "none",
		}),
	})
	if not layer then
		assert(os.remove(path))
		error(err)
	end
	return layer
end

host_action("project", "Open Project Session", function(ctx, args)
	assert(ctx.client_id, "A Rex app client is required to select a project session")
	local opened = projects.open(args.value)
	-- Creating a session does not display it; select it on the invoking app.
	rex.client.queue("session.select", opened)
	return opened
end, { value = "string" })

host_action("projects", "Pick Project Session", function(ctx)
	local rows = {}
	for _, path in ipairs(projects.paths()) do
		rows[#rows + 1] = path .. "\t" .. path
	end
	return picker(ctx, rows, "dots_project", "Project: ")
end)

host_action("slot", "Jump to Project Slot", function(_, args)
	local saved = projects.slot(args.slot)
	return assert(rex.invoke("dots_project", { value = saved.path }))
end, {
	type = "object",
	required = { "slot" },
	additionalProperties = false,
	properties = { slot = { type = "integer", minimum = 0, maximum = 9 } },
})

host_action("slots", "Pick Saved Project", function(ctx)
	local rows, saved_projects = {}, projects.state().entries
	table.sort(saved_projects, function(a, b)
		local ai, bi = a.index == 0 and 10 or a.index or 11, b.index == 0 and 10 or b.index or 11
		if ai ~= bi then
			return ai < bi
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.path < b.path
	end)
	for _, saved in ipairs(saved_projects) do
		local index = saved.index == nil and "-" or tostring(saved.index)
		rows[#rows + 1] = saved.path .. "\t" .. index .. "  " .. saved.name .. "  " .. saved.path
	end
	return picker(ctx, rows, "dots_project", "Slot: ")
end)

host_action("assign", "Assign Current Project to Slot", function(ctx, args)
	return projects.assign(ctx, args.slot)
end, { slot = "integer" })
host_action("add", "Append Current Project", function(ctx)
	return projects.add(ctx)
end)
host_action("seed", "Reset Project Slots to Defaults", function()
	return projects.seed()
end)
host_action("edit_slots", "Edit Project Slots on Session Host", function(ctx)
	local path = projects.edit_file()
	local source = assert(rex.session.describe_block({ block_id = ctx.block_id })).block
	return assert(rex.session.new_layer({
		window_id = assert(source.window_id),
		bounds = { 0.1, 0.1, 0.8, 0.8 },
		focus = true,
		layout = shell({
			command = { "env", "NVIM_APPNAME=minimal-nvim", os.getenv("EDITOR") or "nvim", path },
		}),
	}))
end)

action("dots_new_tab", "New Tab in Current Directory", function(ctx)
	return assert(rex.session.new_window({ layout = shell({ cwd = cwd(ctx) }) }))
end)
action("dots_focus_tab", "Focus Picked Tab", function(_, args)
	return assert(rex.session.focus_window({ window_id = args.value }))
end, { value = "string" })
host_action("tabs", "Pick Tab", function(ctx)
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
host_action("panes", "Pick Pane to Swap", function(ctx)
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
	local source = assert(rex.session.describe_block({ block_id = ctx.block_id })).block
	return assert(rex.session.new_window({
		window_label = "history",
		focus = false,
		layout = shell({
			command = {
				"bash",
				"-c",
				[[set -euo pipefail
rex -C "$2" do -e '
local pane = assert(rex.session.describe_block({ block_id = rex.block_id })).block
rex.client.queue("session.select", { session_id = rex.session_id, window_id = pane.window_id })
'
rex capture -b "$1" --trim --unwrap |
  nvim -u NONE -R -c 'set clipboard=unnamedplus' -c 'nnoremap q <Cmd>qa!<CR>' -c 'normal! G' -
rex focus -s "$REX_SESSION" "$1"
rex -C "$2" do session.select session_id="$REX_SESSION" window_id="$3"]],
				"rex-history",
				ctx.block_id,
				assert(ctx.client_id),
				assert(source.window_id),
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
rex.mode("projects", { exclusive = true })
bind("h", "client.mode.enter", { name = "projects", once = true })
for slot = 0, 9 do
	rex.bind("projects/" .. slot, "dots_assign", { slot = slot })
end
rex.bind("projects/a", "dots_add")
rex.bind("projects/e", "dots_edit_slots")
rex.bind("projects/l", "dots_slots")
rex.bind("projects/r", "dots_seed")
for _, key in ipairs({ "q", "escape", "ctrl+c" }) do
	rex.bind("projects/" .. key, "client.mode.exit")
end
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
