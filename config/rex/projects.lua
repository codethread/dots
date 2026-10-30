-- Project discovery and mutable slots, ported from tmux-session.
local M = {}
local home = assert(os.getenv("HOME"))
local config = (os.getenv("XDG_CONFIG_HOME") or home .. "/.config")
M.state = (os.getenv("XDG_CACHE_HOME") or home .. "/.local/cache") .. "/rex-slots"

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

local function read(path)
	local f = assert(io.open(path))
	local text = f:read("*a")
	f:close()
	return text
end

local function expand(path)
	path = path:gsub("^~", function()
		return home
	end)
	local dots = os.getenv("DOTFILES") or home .. "/dev/dots"
	return (path:gsub("%${DOTFILES}", function()
		return dots
	end):gsub("%$DOTFILES", function()
		return dots
	end))
end

local function settings()
	local data = assert(rex.json.decode(M.exec({ "fx", "--toml", "JSON.stringify(x)" }, {
		stdin = read(config .. "/tmux/sessions.toml"),
	})))
	local hostname = M.exec({ "hostname" }):gsub("%s+$", "")
	local environment = {}
	for key, value in M.exec({ "env", "-0" }):gmatch("([^=%z]+)=([^%z]*)%z") do
		environment[key] = value
	end
	for _, rule in ipairs(data.auto_profile.rules) do
		local matched = false
		if rule.hostname_regex then
			local r = assert(rex.exec({ "grep", "-Eq", rule.hostname_regex }, { stdin = hostname .. "\n" }))
			assert(r.code == 0 or r.code == 1, r.stderr)
			matched = r.code == 0
		end
		for key, value in pairs(rule.env or {}) do
			matched = matched or environment[key] == value
		end
		if matched then
			return data, assert(data.profiles[rule.profile])
		end
	end
	return data, data
end

function M.seed()
	local data, profile = settings()
	local slots = {}
	for line = 1, 10 do
		local project = profile.keys["P" .. line % 10]
		local path = project and (profile.projects[project] or data.projects[project])
		slots[line] = path and expand(path) or ""
	end
	M.save(slots)
	return slots
end

function M.save(slots)
	M.exec({ "mkdir", "-p", M.state:match("^(.*)/") })
	local f = assert(io.open(M.state .. ".tmp", "w"))
	assert(f:write(table.concat(slots, "\n") .. "\n"))
	assert(f:close())
	assert(os.rename(M.state .. ".tmp", M.state))
end

function M.slots()
	local exists = assert(rex.exec({ "test", "-e", M.state }))
	assert(exists.code == 0 or exists.code == 1, exists.stderr)
	if not exists.ok then
		return M.seed()
	end
	local f = assert(io.open(M.state))
	local slots = {}
	for line in f:lines() do
		slots[#slots + 1] = line
	end
	f:close()
	for i = #slots + 1, 10 do
		slots[i] = ""
	end
	return slots
end

function M.slot_index(key)
	assert(key >= 0 and key <= 9, "Slot must be 0–9")
	return key == 0 and 10 or key
end

function M.paths()
	local data, profile = settings()
	local search = profile.search or data.search
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
		argv[#argv + 1] = expand(path)
	end
	local found = M.exec(argv)
	for _, root in ipairs(search.vsc) do
		local path = expand(root)
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

return M
