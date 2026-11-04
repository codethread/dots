local projects = require("projects")

-- Receive an explicit caller state. --host applies locally and never forwards,
-- so a remote request cannot toggle twice or loop back to its originating client.
rex.action({
	name = "dots_theme",
	title = "Apply Caller Theme on Host",
	category = "Dots",
	args = {
		type = "object",
		required = { "mode", "family" },
		additionalProperties = false,
		properties = {
			mode = { type = "string", enum = { "light", "dark" } },
			family = { type = "string", enum = { "tokyonight", "rose-pine" } },
		},
	},
	run = function(_, args)
		-- This Rex build exposes the schema but raw client.action does not enforce it.
		assert(args.mode == "light" or args.mode == "dark", "Expected explicit light/dark mode, not toggle")
		assert(args.family == "tokyonight" or args.family == "rose-pine", "Expected explicit theme family")
		return assert(rex.json.decode(projects.exec({ "theme", "--host", args.mode, "--family", args.family })))
	end,
})
