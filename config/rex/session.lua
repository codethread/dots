-- Invoked by session.sh on the session host, never by a client's config VM.
local projects = require("projects")
local block = assert(rex.args.block)

local function directory()
	local process = assert(rex.block.call("com.superlogical.terminal", "process", { block_id = block }))
	return assert(
		(process.foreground and process.foreground.cwd) or (process.child and process.child.cwd),
		"Cannot read this terminal's directory"
	)
end

local function slot_index()
	local slot = assert(tonumber(rex.args.value), "Slot must be 0–9")
	assert(slot == math.floor(slot), "Slot must be an integer")
	return projects.slot_index(slot)
end

local function open(path)
	local name = assert(path:match("([^/]+)/?$")):gsub("%.", "_")
	local id
	for _, session in ipairs(assert(rex.call("session.list")).sessions) do
		if session.label == name then
			assert(not id, "Multiple sessions named " .. name)
			id = session.session_id
		end
	end
	if not id then
		local directory_exists = assert(rex.exec({ "test", "-d", path }))
		assert(directory_exists.ok, "Project directory is not available on this session host: " .. path)
		id = assert(rex.call("session.create", {
			label = name,
			initial_windows = {
				{
					window_label = "main",
					layout = rex.layout.block({ flavor = "com.superlogical.terminal.shell", options = { cwd = path } }),
				},
			},
		})).session_id
	end
	local owner = assert(
		assert(rex.session.describe_block({ block_id = block })).block.owner,
		"The source terminal has no owning client"
	)
	assert(rex.call("client.perform", {
		client_id = owner,
		session_id = rex.session_id,
		block_id = block,
		action = "session.select",
		args = { session_id = id },
	}))
	return { session_id = id }
end

local actions = {
	open = function()
		return open(assert(rex.args.value))
	end,
	slot = function()
		local path = projects.slots()[slot_index()]
		assert(path ~= "", "Empty slot: use Ctrl+A h then a number to assign it")
		return open(path)
	end,
	assign = function()
		local slots = projects.slots()
		slots[slot_index()] = directory()
		projects.save(slots)
	end,
	add = function()
		local slots, path = projects.slots(), directory()
		for _, existing in ipairs(slots) do
			if existing == path then
				return
			end
		end
		slots[#slots + 1] = path
		projects.save(slots)
	end,
	seed = function()
		projects.seed()
	end,
	ensure = function()
		projects.slots()
	end,
	projects = function()
		local rows = {}
		for _, path in ipairs(projects.paths()) do
			rows[#rows + 1] = path .. "\t" .. path
		end
		return { values = rows }
	end,
	slots = function()
		local rows = {}
		for i, path in ipairs(projects.slots()) do
			if path ~= "" then
				rows[#rows + 1] = path .. "\t" .. (i <= 10 and i % 10 or i) .. "  " .. path
			end
		end
		return { values = rows }
	end,
	tabs = function()
		local rows = {}
		for i, window in ipairs(assert(rex.session.view({})).windows) do
			rows[#rows + 1] = window.window_id .. "\t" .. i .. "  " .. window.label
		end
		return { values = rows }
	end,
	focus_tab = function()
		return assert(rex.session.focus_window({ window_id = rex.args.value }))
	end,
}

return assert(actions[rex.args.action], "Unknown session operation")()
