return {
	{
		'j-hui/fidget.nvim',
		opts = {
			progress = {
				ignore = {},
				display = { done_icon = '✓' },
			},
			notification = {
				window = {
					winblend = 0,
					border = 'rounded',
				},
			},
		},
	},

	{ 'b0o/SchemaStore.nvim', lazy = true },

	{
		'folke/lazydev.nvim',
		dependencies = {
			{ 'Bilal2453/luvit-meta', lazy = true },
			'neovim/nvim-lspconfig',
		},
		ft = 'lua', -- only load on lua files
		opts = {
			---@module 'lazydev'
			---@type lazydev.Library.spec[]
			library = {
				{ path = 'luvit-meta/library', words = { 'vim%.uv' } },
				'snacks.nvim',
				'lazy.nvim',
				'nvim-dap-ui',
			},
			enabled = function(root_dir)
				-- disable when a .luarc.json file is found
				if vim.uv.fs_stat(root_dir .. '/.luarc.json') then return false end
				return true
			end,
		},
	},

	{
		-- when looking for lsp capabilities for supports_method use spec (example is a pinned version, use latest):
		-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#languageFeatures
		'neovim/nvim-lspconfig',
		event = { 'BufReadPre', 'BufNewFile' },
		dependencies = {
			'j-hui/fidget.nvim',
			'williamboman/mason.nvim',
			{ 'williamboman/mason-lspconfig.nvim' },
			'hrsh7th/cmp-nvim-lsp',
			{ 'folke/neoconf.nvim', cmd = 'Neoconf', opts = {} }, -- adds lspconfig type
		},
		---@class PluginLspOpts
		opts = function(_, opts)
			local nvim_lsp = require 'lspconfig'
			local root = nvim_lsp.util.root_pattern
			return vim.tbl_deep_extend('force', {
				-- LSP Server Settings
				---@diagnostic disable: missing-fields
				---@type lspconfig.options
				servers = {
					jsonls = {
						on_new_config = function(new_config)
							new_config.settings.json.schemas = new_config.settings.json.schemas or {}
							vim.list_extend(
								new_config.settings.json.schemas,
								require('schemastore').json.schemas()
							)
						end,
						settings = {
							json = {
								format = {
									enable = true,
								},
								validate = { enable = true },
							},
						},
					},
					nushell = {
						mason = false,
						cmd = {
							'nu',
							'--lsp',
							'--env-config=' .. vim.fn.expand '~/.config/nushell/env.nu',
							'--config=' .. vim.fn.expand '~/.config/nushell/config.nu',
							-- TODO: add work stuff
							'--include-path=' .. vim.fn.expand '~/.config/nushell/scripts',
						},
					},
					-- clangd = {
					-- 	filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
					-- },
					lua_ls = {
						settings = {
							Lua = {
								hint = { enable = true },
								workspace = {
									checkThirdParty = false,
								},
								completion = {
									callSnippet = 'Replace',
								},
								diagnostics = {
									globals = {
										'vim',
										'K',
										'U',
										'Cmd',
										'Lua',
										'Term',
										'async',
										'await',
										'utf8',
									},
								},
							},
						},
					},
					tailwindcss = {
						-- root_dir = root 'tailwind.config.js',
						root_dir = root 'package.json',
						settings = {
							-- TODO: turn this off based on project, probably needs to look for the tailwind config
							tailwindCSS = {
								enable = false,
								experimental = {
									classRegex = {
										-- {
										-- 	'tv\\((([^()]*|\\([^()]*\\))*)\\)',
										-- 	'["\'`]([^"\'`]*).*?["\'`]',
										-- },
										{ 'cva\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
										{ 'cx\\(([^)]*)\\)', "(?:'|\"|`)([^']*)(?:'|\"|`)" },
										{ 'cn\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
										-- { '([a-zA-Z0-9\\-:]+)' },
									},
								},
							},
						},
					},
					eslint = {
						settings = {
							run = 'onSave',
						},
					},
					denols = {
						root_dir = root('deno.json', 'deno.jsonc'),
						settings = {
							deno = {
								enable = false,
							},
						},
					},
					biome = {},
					vtsls = {
						-- nvim-lspconfig provides excellent defaults in lsp/vtsls.lua
						-- We only override settings here, letting it handle cmd, filetypes, and root_dir
						settings = {
							vtsls = {
								autoUseWorkspaceTsdk = true,
								experimental = {
									completion = {
										enableServerSideFuzzyMatch = true,
									},
								},
							},
							typescript = {
								preferences = {
									importModuleSpecifier = 'non-relative',
									preferTypeOnlyAutoImports = true,
									includePackageJsonAutoImports = 'on',
								},
								tsserver = {
									maxTsServerMemory = 8192,
								},
							},
						},
					},
					clojure_lsp = {
						-- Repo root wins over any nested deps.edn. Clojure monorepos give each
						-- sub-project its own deps.edn, and clojure-lsp resolves one classpath
						-- per root — rooting at a sub-project drops every sibling and dependency
						-- off the classpath, killing go-to-definition across the repo. Nested
						-- tables are priority tiers; the second keeps non-git checkouts working.
						root_markers = {
							{ '.git' },
							{ 'deps.edn', 'project.clj', 'build.boot', 'shadow-cljs.edn', 'bb.edn' },
						},
					},
					zls = {},
				},
				-- you can do any additional lsp server setup here
				-- return true if you don't want this server to be setup with lspconfig
				---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
				setup = {},
			}, opts)
		end,
		config = function(_, opts)
			-- Setup global LSP configuration (nvim 0.11 native API)
			local capabilities = vim.tbl_deep_extend(
				'force',
				{},
				vim.lsp.protocol.make_client_capabilities(),
				require('cmp_nvim_lsp').default_capabilities()
			)

			-- Global LSP settings for all servers
			vim.lsp.config('*', {
				capabilities = capabilities,
			})

			-- Custom on_attach behaviors using LspAttach
			U.lsp_attach('*', function(client, bufnr)
				-- NOTE: uncomment to see server capabilities
				-- vim.print(client.server_capabilities)

				-- Override K for hover with UFO fold peek integration
				-- (nvim 0.11 sets K by default, but we want UFO integration)
				vim.keymap.set('n', 'K', function()
					if not require('ufo').peekFoldedLinesUnderCursor() then vim.lsp.buf.hover() end
				end, { buffer = bufnr, desc = 'hover' })
				vim.keymap.set(
					'n',
					'gd',
					function() vim.lsp.buf.definition { reuse_win = true } end,
					{ buffer = bufnr, desc = 'goto def' }
				)

				-- Custom definition handler for lua_ls with filtering
				if client.name == 'lua_ls' then
					local reuse_win = true
					local on_list = require('plugins.lsp.definition').on_list_fact {
						reuse_win = reuse_win,
						filter = function(item)
							--- WIP:
							--- - in lua class defs might be better refersed (extensions are more interesting)

							-- remove function assignments, e.g local foo = function() end
							local s = item.text:gsub('%s', ' ')
							local start = s:find 'function%s*%('
							return start ~= item.col
						end,
					}

					-- Override gd for lua_ls with custom filtering
					vim.keymap.set(
						'n',
						'gd',
						function() vim.lsp.buf.definition { on_list = on_list, reuse_win = reuse_win } end,
						{ buffer = bufnr, desc = 'definition (filtered)' }
					)
				end

				-- Highlight references on cursor hold
				if client.server_capabilities.documentHighlightProvider then
					vim.api.nvim_create_augroup('lsp_document_highlight', { clear = true })
					vim.api.nvim_clear_autocmds { buffer = bufnr, group = 'lsp_document_highlight' }
					vim.api.nvim_create_autocmd('CursorHold', {
						callback = vim.lsp.buf.document_highlight,
						buffer = bufnr,
						group = 'lsp_document_highlight',
						desc = 'Document Highlight',
					})
					vim.api.nvim_create_autocmd('CursorMoved', {
						callback = vim.lsp.buf.clear_references,
						buffer = bufnr,
						group = 'lsp_document_highlight',
						desc = 'Clear All the References',
					})
				end

				-- Disable inlay hints by default
				vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
			end)

			local servers = opts.servers

			-- Configure each server using vim.lsp.config() (nvim 0.11)
			local function configure_server(server, server_opts)
				-- Deep copy to avoid mutations
				local config = vim.tbl_deep_extend('force', {
					capabilities = vim.deepcopy(capabilities),
				}, server_opts or {})

				-- Remove mason field as it's not part of LSP config
				local mason = config.mason
				config.mason = nil

				-- Call custom setup hook if exists
				if opts.setup[server] then
					if opts.setup[server](server, config) then return false end
				end

				-- Configure the server using nvim 0.11 native API
				vim.lsp.config(server, config)
				return true
			end

			-- Enable servers using vim.lsp.enable() (nvim 0.11)
			local function enable_server(server) vim.lsp.enable(server) end

			-- Get all servers available through mason-lspconfig
			local mlsp = require 'mason-lspconfig'
			local all_mslp_servers =
				vim.tbl_keys(require('mason-lspconfig.mappings').get_mason_map().lspconfig_to_package)

			local ensure_installed = {} ---@type string[]
			local servers_to_enable = {} ---@type string[]

			-- Process all servers
			for server, server_opts in pairs(servers) do
				if server_opts then
					server_opts = server_opts == true and {} or server_opts

					-- Configure server
					local should_enable = configure_server(server, server_opts)

					if should_enable then
						-- Track for enabling later
						table.insert(servers_to_enable, server)

						-- Handle mason installation
						if server_opts.mason == false or not vim.tbl_contains(all_mslp_servers, server) then
							-- Manual server (not managed by mason)
						else
							-- Add to mason ensure_installed
							ensure_installed[#ensure_installed + 1] = server
						end
					end
				end
			end

			-- Setup mason-lspconfig
			mlsp.setup { ensure_installed = ensure_installed }

			-- Enable all configured servers
			for _, server in ipairs(servers_to_enable) do
				enable_server(server)
			end

			-- Configure diagnostics (nvim 0.11)
			vim.diagnostic.config {
				virtual_text = {
					severity = vim.diagnostic.severity.ERROR,
					source = 'if_many',
				},
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = 'rounded',
					source = true,
					header = '',
					prefix = '',
				},
			}

		end,
	},
}
