-- Fixed project slots and discovery roots for Rex.
local M = {}
local home = assert(os.getenv("HOME"))
-- Edit numbered project slots here. These paths stay home-relative in config.
M.slots = {
	[0] = "~/dev/projects/notes",
	[1] = "~/dev/dots",
	[2] = "~/dev/projects/agents",
	[3] = "~/dev/projects/botlake",
	[4] = "~/dev/projects/botlake-ui",
	[5] = "~/dev/projects/botlake-ui",
	[8] = "~/dev/projects/nuphy_firmware/keyboards/nuphy/halo75v2/ansi",
	[9] = "~/dev/projects/qmk_firmware/keyboards/preonic/keymaps/codethread",
}

local search = {
	dirs = {
		"~/dev/dots",
		"~/work/me/workfiles",
		"~/.local/share/nvim/lazy/*",
		"~/.local/share/nvim/mason/packages/*",
	},
	vsc = { "~/dev", "~/work", "~/pb" },
}

function M.exec(argv, opts)
	-- The GUI server does not inherit the terminal's Homebrew/mise PATH.
	local command =
		{ "/bin/sh", "-c", '. "${XDG_CONFIG_HOME:-$HOME/.config}/env/base.sh" || exit; exec "$@"', "rex-env" }
	for _, arg in ipairs(argv) do
		command[#command + 1] = arg
	end
	local r = assert(rex.exec(command, opts))
	assert(r.ok, table.concat(argv, " ") .. ": " .. r.stderr)
	return r.stdout
end

function M.expand(path)
	return (path:gsub("^~/", function()
		return home .. "/"
	end))
end

function M.paths()
	-- Zsh expands configured directory globs; fd includes .git files for worktrees.
	local argv = {
		"zsh",
		"-f",
		"-c",
		[[
    set -e
    for pattern in "$@"; do
      for dir in ${~pattern}(N/); do printf '%s\n' "$dir"; done
    done
  ]],
		"rex-projects",
	}
	for _, path in ipairs(search.dirs) do
		argv[#argv + 1] = M.expand(path)
	end
	local found = M.exec(argv)
	for _, root in ipairs(search.vsc) do
		local path = M.expand(root)
		local exists = assert(rex.exec({ "test", "-d", path }))
		assert(exists.code == 0 or exists.code == 1, exists.stderr)
		if exists.ok then
			found = found
				.. M.exec({
					"fd",
					"-H",
					"--no-ignore",
					"^\\.git$",
					path,
					"--max-depth",
					"5",
					"-E",
					"node_modules",
					"-E",
					"target",
					"-E",
					".cargo",
					"-E",
					".next",
					"-E",
					"dist",
					"-E",
					"build",
					"-E",
					"coverage",
				}):gsub("/%.git/?\n", "\n")
		end
	end
	local paths, seen = {}, {}
	for path in found:gmatch("[^\n]+") do
		if not seen[path] then
			paths[#paths + 1], seen[path] = path, true
		end
	end
	table.sort(paths)
	return paths
end

-- Mutable project state belongs to the server executing these functions.
local state_dir = (os.getenv("XDG_STATE_HOME") or home .. "/.local/state") .. "/rex"
M.state_file = state_dir .. "/projects.json"

local function entry(path, name)
	assert(type(path) == "string" and path:sub(1, 1) == "/", "Expected an absolute server project path")
	assert(not path:find("[\r\n\t]"), "Project paths cannot contain tabs or newlines")
	name = name or assert(path:match("([^/]+)/?$")):gsub("%.", "_")
	assert(type(name) == "string" and name ~= "" and not name:find("[\r\n\t]"), "Invalid project name")
	return { name = name, path = path }
end

local function defaults()
	local entries = {}
	for index = 0, 9 do
		local path = M.slots[index]
		if path then
			local project = entry(M.expand(path))
			project.index = index
			entries[#entries + 1] = project
		end
	end
	return entries
end

local function validate_index(index)
	assert(
		type(index) == "number" and index == math.floor(index) and index >= 0 and index <= 9,
		"Project index must be 0–9"
	)
end

local function validate(state)
	assert(type(state) == "table" and state.version == 2, "Expected project state version 2 (explicit indexes)")
	assert(type(state.entries) == "table", "Project state needs an entries array")
	assert(type(state.sessions) == "table", "Project state needs a session-directory map")
	local indexed = {}
	for _, value in ipairs(state.entries) do
		assert(type(value) == "table" and type(value.name) == "string", "Expected a named project entry")
		entry(value.path, value.name)
		if value.index ~= nil then
			validate_index(value.index)
			if indexed[value.index] then
				error(
					"Duplicate project index "
						.. value.index
						.. " ("
						.. indexed[value.index]
						.. " and "
						.. value.name
						.. ")"
				)
			end
			indexed[value.index] = value.name
		end
	end
	for id, path in pairs(state.sessions) do
		assert(type(id) == "string" and id:match("^session:"), "Invalid saved session ID")
		entry(path)
	end
	return state
end

local function state_file(update, fn)
	M.exec({ "mkdir", "-p", state_dir })
	-- Rename protects the file; a host-side lock also protects read/modify/write
	-- from simultaneous actions from different clients. A busy lock fails visibly.
	local lock = M.state_file .. ".lock"
	local acquired = assert(rex.exec({ "/bin/mkdir", lock }))
	assert(acquired.ok, "Cannot lock project state: " .. lock .. "\n" .. acquired.stderr)
	local ok, result = pcall(function()
		local exists = assert(rex.exec({ "/bin/test", "-e", M.state_file }))
		assert(exists.code == 0 or exists.code == 1, exists.stderr)
		local state
		if exists.ok then
			local file = assert(io.open(M.state_file, "r"))
			local text = assert(file:read("*a"))
			assert(file:close())
			state = validate(assert(rex.json.decode(text)))
		else
			state = { version = 2, entries = defaults(), sessions = {} }
		end
		local value = fn(state)
		if update or not exists.ok then
			local text = assert(rex.json.encode(validate(state), { indent = true }))
			local temp = M.state_file .. ".tmp"
			local file = assert(io.open(temp, "w"))
			assert(file:write(text .. "\n"))
			assert(file:close())
			assert(os.rename(temp, M.state_file))
		end
		return value
	end)
	local released = assert(rex.exec({ "/bin/rmdir", lock }))
	assert(released.ok, "Cannot release project state lock: " .. released.stderr)
	assert(ok, result)
	return result
end

function M.state()
	return state_file(false, function(state)
		return state
	end)
end

function M.slot(index)
	validate_index(index)
	for _, saved in ipairs(M.state().entries) do
		if saved.index == index then
			return saved
		end
	end
	error("Slot " .. index .. " is empty; use Ctrl+A h " .. index .. " to assign")
end

function M.remember(id, path)
	return state_file(true, function(state)
		assert(
			not state.sessions[id] or state.sessions[id] == path,
			"Session already belongs to another project directory"
		)
		state.sessions[id] = path
	end)
end

function M.open(path)
	path = M.expand(path)
	local name = entry(path).name
	-- Serialize lookup/create too: unlike tmux, Rex permits duplicate labels.
	return state_file(true, function(state)
		local id
		for _, session in ipairs(assert(rex.call("session.list")).sessions) do
			if session.label == name then
				assert(not id, "Multiple sessions named " .. name)
				id = session.session_id
			end
		end
		if id then
			assert(
				not state.sessions[id] or state.sessions[id] == path,
				"Session already belongs to another project directory"
			)
		else
			local directory = assert(rex.exec({ "/bin/test", "-d", path }))
			assert(directory.ok, "Project directory is not available on the Rex server: " .. path)
			id = assert(rex.call("session.create", {
				label = name,
				initial_windows = {
					{
						window_label = "main",
						layout = rex.layout.block({
							flavor = "com.superlogical.terminal.shell",
							options = { cwd = path },
						}),
					},
				},
			})).session_id
		end
		state.sessions[id] = path
		return { session_id = id }
	end)
end

function M.current(ctx)
	local path = M.state().sessions[ctx.session_id]
	if not path then
		-- Rex has no tmux session_path field. Adopt a pre-existing/manual session's
		-- source directory once; sessionizer-created sessions are recorded at open.
		local process = assert(rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id }))
		path = assert(
			(process.foreground and process.foreground.cwd) or (process.child and process.child.cwd),
			"Cannot read this terminal's project directory"
		)
		M.remember(ctx.session_id, path)
	end
	local view = assert(rex.session.view({}))
	return entry(path, view.label)
end

function M.assign(ctx, index)
	validate_index(index)
	local project = M.current(ctx)
	project.index = index
	return state_file(true, function(state)
		for position, saved in ipairs(state.entries) do
			if saved.index == index then
				state.entries[position] = project
				return project
			end
		end
		state.entries[#state.entries + 1] = project
		return project
	end)
end

function M.add(ctx)
	local project = M.current(ctx)
	return state_file(true, function(state)
		for _, saved in ipairs(state.entries) do
			if saved.path == project.path or saved.name == project.name then
				return project
			end
		end
		state.entries[#state.entries + 1] = project
		return project
	end)
end

function M.edit_file()
	local exists = assert(rex.exec({ "/bin/test", "-e", M.state_file }))
	assert(exists.code == 0 or exists.code == 1, exists.stderr)
	if not exists.ok then
		M.state()
	end
	-- Editing is the explicit recovery route for malformed JSON too.
	return M.state_file
end

function M.seed()
	return state_file(true, function(state)
		state.entries = defaults()
		return { file = M.state_file }
	end)
end

return M
