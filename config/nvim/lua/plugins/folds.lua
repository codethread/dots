if vim.g.vscode then return {} end

return {
	{
		'kevinhwang91/nvim-ufo',
		dependencies = { 'kevinhwang91/promise-async', 'nvim-treesitter/nvim-treesitter' },
		event = U.LazyFile,
		init = function()
			vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
			vim.o.foldlevelstart = 99
			vim.o.foldenable = true
			vim.o.foldnestmax = 4 -- TRIAL: no more than 4 levels of nesting

			-- hide foldcolumn, can be enabled with foldcolumn = 1. This is a list in the left gutter, it's not useful for me
			vim.o.foldcolumn = '0'
			-- vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]] -- add nice fold icons
		end,
		---@module 'ufo'
		---@type UfoConfig
		opts = {
			-- NOTE: careful here, if using lsp provider then folds will be
			-- applied to any unfolded areas (even if already folded) beacuse
			-- only 'closed' folds are persisted, so it's impossible to _not_
			-- fold an area, i.e it won't persist "keep this open please"
			close_fold_kinds_for_ft = {
				default = {
					'imports',
					'marker',
					-- 'comment',
					--
					-- NOTE: region is defined by lsp itself, so just trial and error to see if this is nice.
					-- Annoying because it overrides persisted folds
					--
					-- 'region',
				},
			},
			---@return UfoProviderEnum[] | ''
			provider_selector = function(_, filetype)
				---@type table<string, UfoProviderEnum[] | ''> empty '' disables
				local ftMap = {
					clojure = { 'indent' },
					vim = { 'indent' },
					typescriptreact = { 'lsp' },
					typescript = { 'lsp' },
					rust = { 'lsp' },
					lua = { 'lsp' },
					git = '',
				}

				return ftMap[filetype] or { 'treesitter', 'indent' }
			end,
			fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
				local newVirtText = {}
				local suffix = ('  %d '):format(endLnum - lnum)
				local sufWidth = vim.fn.strdisplaywidth(suffix)
				local targetWidth = width - sufWidth
				local curWidth = 0
				for _, chunk in ipairs(virtText) do
					local chunkText = chunk[1]
					local chunkWidth = vim.fn.strdisplaywidth(chunkText)
					if targetWidth > curWidth + chunkWidth then
						table.insert(newVirtText, chunk)
					else
						chunkText = truncate(chunkText, targetWidth - curWidth)
						local hlGroup = chunk[2]
						table.insert(newVirtText, { chunkText, hlGroup })
						chunkWidth = vim.fn.strdisplaywidth(chunkText)
						-- str width returned from truncate() may less than 2nd argument, need padding
						if curWidth + chunkWidth < targetWidth then
							suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
						end
						break
					end
					curWidth = curWidth + chunkWidth
				end
				table.insert(newVirtText, { suffix, 'MoreMsg' })
				return newVirtText
			end,
		},
	},
}
