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

return M
