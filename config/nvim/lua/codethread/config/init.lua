do -- annoying
	if table.pack then
		vim.notify 'table.pack is present, not need to polyfill'
	else
		table.pack = table.pack or function(...) return { n = select('#', ...), ... } end
	end
	if table.unpack then
		vim.notify 'table.unpack is present, not need to polyfill'
	else
		table.unpack = table.unpack or unpack
	end
end

require 'codethread.config.options'
require 'codethread.config.utils'
require 'codethread.config.globals'
require 'codethread.config.autocommands'
require 'codethread.pi-scrollback'
