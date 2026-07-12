-- Custom Clojure highlight theme.
--
-- Design: a few anchor colours, and everything else links to one of them. To
-- retune the language, change an anchor (or move a group to a different one)
-- rather than editing dozens of `fg`s. `:Inspect` a token to see which group
-- paints it. Values are rose-pine palette names.
--
-- The palette:
--   plain   (text)  symbols, strings, numbers, keyword names
--   fn      (rose)  clojure.core builtins/macros, namespace aliases, fn usages
--   defname (iris)  a def-form's own name (bold in the dawn/light variant)
--   paren   (muted) ( ) [ ] { }
--   special (iris)  reader macros: # ~ ^
--   marker  (foam)  the `:`/`::` of a keyword literal
--   keyword         def-forms, `ns`, control flow — inherited from rose-pine (pine),
--                   NOT overridden here; add an override to change them.
--
-- Groups are `.clojure`-suffixed so they only touch Clojure buffers. clojure-lsp
-- semantic tokens win over treesitter, so the noisy `@lsp.type.*` types are
-- cleared to defer to treesitter; only the namespace alias is kept.

local anchor = {
	plain = '@variable.clojure',
	fn = '@function.builtin.clojure',
	paren = '@punctuation.bracket.clojure',
}

local function link(to) return { link = to } end

---@param opts? { light?: boolean }
return function(opts)
	opts = opts or {}
	-- Definition names are iris, bold in the dawn/light variant where the lower
	-- contrast wants the extra weight.
	local def_name = { fg = 'iris', bold = opts.light == true }

	return {
		-- Anchors (the source-of-truth colours).
		[anchor.plain] = { fg = 'text' },
		[anchor.fn] = { fg = 'rose' },
		[anchor.paren] = { fg = 'muted' },
		['@clojure.keyword.marker'] = { fg = 'foam' },
		-- The `/` + name of a namespaced symbol: a function (rose, upright). The alias
		-- itself stays italic via @lsp.type.type, so `s/def` reads italic-then-upright.
		['@clojure.qualified.name'] = link(anchor.fn),
		-- A qualified keyword's namespace is data, not a type: keep it plain.
		['@clojure.keyword.namespace'] = link(anchor.plain),

		-- Strings yellow; docstrings (a treesitter-only distinction) off-white grey.
		['@string.clojure'] = { fg = 'gold' },
		['@string.documentation.clojure'] = { fg = 'subtle' },

		-- Pull rose-pine's loud defaults back to plain.
		['@string.special.symbol.clojure'] = link(anchor.plain), -- keyword name / quoted sym
		['@string.escape.clojure'] = link(anchor.plain),
		['@string.regexp.clojure'] = link(anchor.plain),
		['@number.clojure'] = link(anchor.plain),
		['@boolean.clojure'] = link(anchor.plain),
		['@character.clojure'] = link(anchor.plain),
		['@constant.clojure'] = link(anchor.plain),
		['@constant.builtin.clojure'] = link(anchor.plain),
		['@constant.macro.clojure'] = link(anchor.plain),
		['@variable.builtin.clojure'] = link(anchor.plain),
		['@variable.parameter.clojure'] = link(anchor.plain),
		['@variable.member.clojure'] = link(anchor.plain),
		['@operator.clojure'] = link(anchor.plain),
		['@type.clojure'] = link(anchor.plain),
		['@module.clojure'] = link(anchor.plain),
		['@constructor.clojure'] = link(anchor.plain),

		-- The function accent: usages read as functions (rose) wherever they appear;
		-- a function's own definition name is iris (see the LSP typemod below).
		['@function.clojure'] = def_name, -- bare @function = the def'd name (no-LSP case)
		['@function.call.clojure'] = link(anchor.fn),
		['@function.method.clojure'] = link(anchor.fn),
		['@function.macro.clojure'] = link(anchor.fn), -- core macros: let, ->, do

		-- Punctuation: brackets grey, reader macros (`#`, `~`, `^`) distinct.
		['@punctuation.delimiter.clojure'] = link(anchor.paren),
		['@punctuation.special.clojure'] = { fg = 'iris' },

		-- clojure-lsp semantic tokens: functions rose everywhere (covers fns-as-args
		-- that treesitter leaves plain); keep the namespace alias; clear the rest so
		-- treesitter drives keyword colours and the marker split.
		['@lsp.type.type.clojure'] = { fg = 'rose', italic = true }, -- ns alias, e.g. `s/`
		['@lsp.type.function.clojure'] = { fg = 'rose' },
		['@lsp.typemod.function.definition.clojure'] = def_name, -- the name at (defn foo …)
		['@lsp.type.macro.clojure'] = {},
		['@lsp.type.keyword.clojure'] = {},
		['@lsp.type.variable.clojure'] = {},
		['@lsp.type.parameter.clojure'] = {},
		['@lsp.type.namespace.clojure'] = {},
		['@lsp.type.method.clojure'] = {},
		['@lsp.type.event.clojure'] = {},
	}
end
